#import "capture_engine.hpp"
#import "application_manager.hpp"
#import "filter_manager.hpp"
#import "stream_manager.hpp"
#import <AppKit/AppKit.h>
#include <sstream>

@interface CaptureEngineObjC : NSObject

@property (nonatomic, strong) ApplicationManagerObjC *appManager;
@property (nonatomic, strong) FilterManagerObjC *filterManager;
@property (nonatomic, strong) StreamManagerObjC *streamManager;

@property (nonatomic, assign) CaptureStatusCode statusCode;
@property (nonatomic, copy) NSString *statusMessage;
@property (nonatomic, assign) uint32_t width;
@property (nonatomic, assign) uint32_t height;

- (BOOL)startWithSettings:(const PrivacyCaptureSettings &)settings targetFPS:(uint32_t)targetFPS;
- (void)stop;
- (BOOL)updateSettings:(const PrivacyCaptureSettings &)newSettings;
- (BOOL)checkAndRefreshExclusions;
- (IOSurfaceRef)acquireCurrentSurface;
- (std::vector<AppInfo>)getAvailableApplications;

@end

@implementation CaptureEngineObjC {
    NSLock *_surfaceLock;
    IOSurfaceRef _currentSurface;
    IOSurfaceRef _prevSurface;

    PrivacyCaptureSettings _settings;
    std::set<pid_t> _prevExcludedPIDs;
    id _launchObserver;
    id _terminateObserver;
    dispatch_source_t _periodicTimer;
    dispatch_queue_t _engineQueue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _surfaceLock = [[NSLock alloc] init];
        _currentSurface = NULL;
        _prevSurface = NULL;
        _statusCode = CaptureStatusReady;
        _statusMessage = @"● Ready";
        _engineQueue = dispatch_queue_create("com.antigravity.privacy_capture.engine", DISPATCH_QUEUE_SERIAL);

        self.appManager = [[ApplicationManagerObjC alloc] init];
        self.filterManager = [[FilterManagerObjC alloc] init];
        self.streamManager = [[StreamManagerObjC alloc] init];

        __weak typeof(self) weakSelf = self;
        self.streamManager.frameCallback = ^(IOSurfaceRef surface, uint32_t w, uint32_t h) {
            [weakSelf handleNewFrame:surface width:w height:h];
        };

        self.streamManager.errorCallback = ^(NSError *error) {
            [weakSelf handleStreamError:error];
        };

        [self setupWorkspaceObservers];
    }
    return self;
}

- (void)dealloc {
    [self stop];
    [self removeWorkspaceObservers];
    [self cleanSurfaces];
}

- (void)setupWorkspaceObservers {
    NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace] notificationCenter];
    __weak typeof(self) weakSelf = self;

    _launchObserver = [nc addObserverForName:NSWorkspaceDidLaunchApplicationNotification
                                      object:nil
                                       queue:[NSOperationQueue mainQueue]
                                  usingBlock:^(NSNotification *note) {
        NSRunningApplication *app = note.userInfo[NSWorkspaceApplicationKey];
        if (app && app.bundleIdentifier) {
            [weakSelf onApplicationLifecycleChanged:app.bundleIdentifier isLaunch:YES];
        }
    }];

    _terminateObserver = [nc addObserverForName:NSWorkspaceDidTerminateApplicationNotification
                                         object:nil
                                          queue:[NSOperationQueue mainQueue]
                                     usingBlock:^(NSNotification *note) {
        NSRunningApplication *app = note.userInfo[NSWorkspaceApplicationKey];
        if (app && app.bundleIdentifier) {
            [weakSelf onApplicationLifecycleChanged:app.bundleIdentifier isLaunch:NO];
        }
    }];
}

- (void)removeWorkspaceObservers {
    NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace] notificationCenter];
    if (_launchObserver) {
        [nc removeObserver:_launchObserver];
        _launchObserver = nil;
    }
    if (_terminateObserver) {
        [nc removeObserver:_terminateObserver];
        _terminateObserver = nil;
    }
}

- (void)startPeriodicTimer {
    if (_periodicTimer) return;
    _periodicTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _engineQueue);
    dispatch_source_set_timer(_periodicTimer, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                              3 * NSEC_PER_SEC, 500 * NSEC_PER_MSEC);

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_periodicTimer, ^{
        [weakSelf checkAndRefreshExclusions];
    });
    dispatch_resume(_periodicTimer);
}

- (void)stopPeriodicTimer {
    if (_periodicTimer) {
        dispatch_source_cancel(_periodicTimer);
        _periodicTimer = nil;
    }
}

- (void)onApplicationLifecycleChanged:(NSString *)bundleID isLaunch:(BOOL)isLaunch {
    if (!_settings.auto_refresh) return;

    std::string bid = [bundleID UTF8String];
    if (_settings.is_app_excluded(bid)) {
        dispatch_async(_engineQueue, ^{
            [self checkAndRefreshExclusions];
        });
    }
}

- (void)handleNewFrame:(IOSurfaceRef)surface width:(uint32_t)w height:(uint32_t)h {
    [_surfaceLock lock];
    if (_currentSurface) {
        IOSurfaceDecrementUseCount(_currentSurface);
        CFRelease(_currentSurface);
    }
    _currentSurface = surface;
    CFRetain(_currentSurface);
    IOSurfaceIncrementUseCount(_currentSurface);
    self.width = w;
    self.height = h;
    [_surfaceLock unlock];
}

- (void)handleStreamError:(NSError *)error {
    NSLog(@"[PrivacyCapture] Stream error: %@", error);
    self.statusCode = CaptureStatusError;
    self.statusMessage = [NSString stringWithFormat:@"⚠ Capture error: %@", error.localizedDescription];
}

- (void)cleanSurfaces {
    [_surfaceLock lock];
    if (_currentSurface) {
        IOSurfaceDecrementUseCount(_currentSurface);
        CFRelease(_currentSurface);
        _currentSurface = NULL;
    }
    if (_prevSurface) {
        IOSurfaceDecrementUseCount(_prevSurface);
        CFRelease(_prevSurface);
        _prevSurface = NULL;
    }
    [_surfaceLock unlock];
}

- (IOSurfaceRef)acquireCurrentSurface {
    [_surfaceLock lock];
    IOSurfaceRef surf = _currentSurface;
    if (surf) {
        CFRetain(surf);
        IOSurfaceIncrementUseCount(surf);
    }
    [_surfaceLock unlock];
    return surf;
}

- (BOOL)startWithSettings:(const PrivacyCaptureSettings &)settings targetFPS:(uint32_t)targetFPS {
    _settings = settings;

    // 1. Refresh shareable content
    [self.appManager refreshShareableContentSync:2.0];
    SCShareableContent *content = self.appManager.shareableContent;
    if (!content) {
        self.statusCode = CaptureStatusPermissionRequired;
        self.statusMessage = @"⚠ Screen Recording permission required";
        return NO;
    }

    // 2. Resolve display
    SCDisplay *display = [self.filterManager findDisplayInContent:content
                                                     displayUUID:settings.display_uuid
                                                       displayID:settings.display_id];
    if (!display) {
        self.statusCode = CaptureStatusDisplayUnavailable;
        self.statusMessage = @"⚠ Target display unavailable";
        return NO;
    }

    // 3. Resolve running excluded apps
    NSArray<SCRunningApplication *> *runningExcluded =
        [self.appManager resolveRunningApplicationsForBundleIDs:settings.get_active_bundle_ids()];

    _prevExcludedPIDs.clear();
    for (SCRunningApplication *app in runningExcluded) {
        _prevExcludedPIDs.insert(app.processID);
    }

    // 4. Create content filter
    SCContentFilter *filter = [self.filterManager createFilterForDisplay:display
                                                            applications:runningExcluded];
    if (!filter) {
        self.statusCode = CaptureStatusError;
        self.statusMessage = @"⚠ Failed to create capture filter";
        return NO;
    }

    // 5. Start stream
    BOOL ok = [self.streamManager startWithFilter:filter
                                      showCursor:settings.show_cursor
                                       targetFPS:targetFPS
                                  completionSync:4.0];
    if (ok) {
        self.statusCode = CaptureStatusCapturing;
        [self updateStatusStringWithRunningApps:runningExcluded];
        if (settings.auto_refresh) {
            [self startPeriodicTimer];
        }
    } else {
        self.statusCode = CaptureStatusError;
        self.statusMessage = @"⚠ Failed to start ScreenCaptureKit stream";
    }
    return ok;
}

- (void)stop {
    [self stopPeriodicTimer];
    [self.streamManager stopSync:1.5];
    [self cleanSurfaces];
    self.statusCode = CaptureStatusReady;
    self.statusMessage = @"● Stopped";
}

- (BOOL)updateSettings:(const PrivacyCaptureSettings &)newSettings {
    bool displayChanged = (_settings.display_uuid != newSettings.display_uuid ||
                           _settings.display_id != newSettings.display_id);
    bool cursorChanged = (_settings.show_cursor != newSettings.show_cursor);
    bool exclusionsChanged = (_settings.get_active_bundle_ids() != newSettings.get_active_bundle_ids());
    bool autoRefreshChanged = (_settings.auto_refresh != newSettings.auto_refresh);

    _settings = newSettings;

    if (autoRefreshChanged) {
        if (_settings.auto_refresh) {
            [self startPeriodicTimer];
        } else {
            [self stopPeriodicTimer];
        }
    }

    if (cursorChanged) {
        [self.streamManager updateShowCursor:_settings.show_cursor];
    }

    if (displayChanged) {
        // Display change requires rebuilding the stream
        return [self startWithSettings:_settings targetFPS:60];
    }

    if (exclusionsChanged) {
        return [self checkAndRefreshExclusions];
    }

    return YES;
}

- (BOOL)checkAndRefreshExclusions {
    [self.appManager refreshShareableContentSync:1.5];
    SCShareableContent *content = self.appManager.shareableContent;
    if (!content) return NO;

    SCDisplay *display = [self.filterManager findDisplayInContent:content
                                                     displayUUID:_settings.display_uuid
                                                       displayID:_settings.display_id];
    if (!display) return NO;

    NSArray<SCRunningApplication *> *runningExcluded =
        [self.appManager resolveRunningApplicationsForBundleIDs:_settings.get_active_bundle_ids()];

    BOOL setChanged = [self.filterManager hasExclusionSetChangedWithPreviousPIDs:_prevExcludedPIDs
                                                                 currentExcluded:runningExcluded];
    if (setChanged || !self.streamManager.isCapturing) {
        _prevExcludedPIDs.clear();
        for (SCRunningApplication *app in runningExcluded) {
            _prevExcludedPIDs.insert(app.processID);
        }

        SCContentFilter *newFilter = [self.filterManager createFilterForDisplay:display
                                                                   applications:runningExcluded];
        if (newFilter) {
            [self.streamManager updateFilter:newFilter completionAsync:nil];
        }
    }

    [self updateStatusStringWithRunningApps:runningExcluded];
    return YES;
}

- (void)updateStatusStringWithRunningApps:(NSArray<SCRunningApplication *> *)runningApps {
    size_t totalConfigured = _settings.get_active_bundle_ids().size();
    size_t runningCount = runningApps.count;

    if (totalConfigured == 0) {
        self.statusMessage = @"● Privacy filter active (no apps currently excluded)";
    } else {
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        for (SCRunningApplication *app in runningApps) {
            if (app.applicationName.length > 0) {
                [names addObject:app.applicationName];
            }
        }
        NSString *namesStr = [names componentsJoinedByString:@", "];
        if (names.count > 0) {
            self.statusMessage = [NSString stringWithFormat:@"● Active: %zu configured, %zu running (%@)",
                                  totalConfigured, runningCount, namesStr];
        } else {
            self.statusMessage = [NSString stringWithFormat:@"● Active: %zu configured (0 currently running)",
                                  totalConfigured];
        }
    }
}

- (std::vector<AppInfo>)getAvailableApplications {
    return [self.appManager getRunningApplicationsList];
}

@end

CaptureEngine::CaptureEngine() {
    CaptureEngineObjC *objc = [[CaptureEngineObjC alloc] init];
    m_impl = (__bridge_retained void *)objc;
}

CaptureEngine::~CaptureEngine() {
    if (m_impl) {
        CaptureEngineObjC *objc = (__bridge_transfer CaptureEngineObjC *)m_impl;
        [objc stop];
        objc = nil;
        m_impl = nullptr;
    }
}

bool CaptureEngine::initialize() {
    return (m_impl != nullptr);
}

bool CaptureEngine::start(const PrivacyCaptureSettings &settings, uint32_t targetFPS) {
    if (!m_impl) return false;
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return [objc startWithSettings:settings targetFPS:targetFPS] == YES;
}

void CaptureEngine::stop() {
    if (!m_impl) return;
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    [objc stop];
}

bool CaptureEngine::updateSettings(const PrivacyCaptureSettings &newSettings) {
    if (!m_impl) return false;
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return [objc updateSettings:newSettings] == YES;
}

bool CaptureEngine::checkAndRefreshExclusions() {
    if (!m_impl) return false;
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return [objc checkAndRefreshExclusions] == YES;
}

IOSurfaceRef CaptureEngine::acquireCurrentSurface() {
    if (!m_impl) return NULL;
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return [objc acquireCurrentSurface];
}

uint32_t CaptureEngine::getWidth() const {
    if (!m_impl) return 0;
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return objc.width;
}

uint32_t CaptureEngine::getHeight() const {
    if (!m_impl) return 0;
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return objc.height;
}

CaptureStatusCode CaptureEngine::getStatusCode() const {
    if (!m_impl) return CaptureStatusError;
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return objc.statusCode;
}

std::string CaptureEngine::getStatusMessage() const {
    if (!m_impl) return "Unavailable";
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return objc.statusMessage ? [objc.statusMessage UTF8String] : "";
}

std::vector<AppInfo> CaptureEngine::getAvailableApplications() {
    if (!m_impl) return {};
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return [objc getAvailableApplications];
}

bool CaptureEngine::isCapturing() const {
    if (!m_impl) return false;
    CaptureEngineObjC *objc = (__bridge CaptureEngineObjC *)m_impl;
    return objc.streamManager.isCapturing == YES;
}
