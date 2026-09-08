#import "application_manager.hpp"

@implementation ApplicationManagerObjC {
    NSLock *_lock;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)refreshShareableContentSync:(NSTimeInterval)timeoutSeconds {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [SCShareableContent getShareableContentExcludingDesktopWindows:YES
                                              onScreenWindowsOnly:NO
                                                completionHandler:^(SCShareableContent *content, NSError *error) {
        if (!error && content) {
            [self->_lock lock];
            self.shareableContent = content;
            [self->_lock unlock];
        }
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutSeconds * NSEC_PER_SEC)));
}

- (void)refreshShareableContentAsync:(void (^ _Nullable)(BOOL success))completion {
    [SCShareableContent getShareableContentExcludingDesktopWindows:YES
                                              onScreenWindowsOnly:NO
                                                completionHandler:^(SCShareableContent *content, NSError *error) {
        BOOL ok = (error == nil && content != nil);
        if (ok) {
            [self->_lock lock];
            self.shareableContent = content;
            [self->_lock unlock];
        }
        if (completion) {
            completion(ok);
        }
    }];
}

- (NSArray<SCRunningApplication *> *)resolveRunningApplicationsForBundleIDs:(const std::vector<std::string> &)bundleIDs {
    [self->_lock lock];
    SCShareableContent *content = self.shareableContent;
    [self->_lock unlock];

    if (!content) return @[];

    NSMutableArray<SCRunningApplication *> *result = [NSMutableArray array];
    for (const auto &bid_str : bundleIDs) {
        NSString *target_bid = [NSString stringWithUTF8String:bid_str.c_str()];
        for (SCRunningApplication *app in content.applications) {
            if ([app.bundleIdentifier isEqualToString:target_bid]) {
                [result addObject:app];
                break;
            }
        }
    }
    return result;
}

- (std::vector<AppInfo>)getRunningApplicationsList {
    [self->_lock lock];
    SCShareableContent *content = self.shareableContent;
    [self->_lock unlock];

    std::vector<AppInfo> apps;
    if (!content) return apps;

    NSMutableArray<SCRunningApplication *> *sorted = [NSMutableArray arrayWithArray:content.applications];
    [sorted sortUsingComparator:^NSComparisonResult(SCRunningApplication *a, SCRunningApplication *b) {
        return [a.applicationName compare:b.applicationName options:NSCaseInsensitiveSearch];
    }];

    for (SCRunningApplication *app in sorted) {
        if (app.applicationName.length > 0 && app.bundleIdentifier.length > 0) {
            AppInfo info;
            info.bundle_id = [app.bundleIdentifier UTF8String];
            info.application_name = [app.applicationName UTF8String];
            info.process_id = app.processID;
            apps.push_back(info);
        }
    }
    return apps;
}

- (BOOL)isAppRunning:(const std::string &)bundleID {
    [self->_lock lock];
    SCShareableContent *content = self.shareableContent;
    [self->_lock unlock];

    if (!content) return NO;

    NSString *target = [NSString stringWithUTF8String:bundleID.c_str()];
    for (SCRunningApplication *app in content.applications) {
        if ([app.bundleIdentifier isEqualToString:target]) {
            return YES;
        }
    }
    return NO;
}

@end

ApplicationManager::ApplicationManager() {
    ApplicationManagerObjC *objc = [[ApplicationManagerObjC alloc] init];
    m_impl = (__bridge_retained void *)objc;
}

ApplicationManager::~ApplicationManager() {
    if (m_impl) {
        ApplicationManagerObjC *objc = (__bridge_transfer ApplicationManagerObjC *)m_impl;
        objc = nil;
        m_impl = nullptr;
    }
}

bool ApplicationManager::refreshContent(double timeoutSeconds) {
    if (!m_impl) return false;
    ApplicationManagerObjC *objc = (__bridge ApplicationManagerObjC *)m_impl;
    [objc refreshShareableContentSync:timeoutSeconds];
    return (objc.shareableContent != nil);
}

void ApplicationManager::refreshContentAsync() {
    if (!m_impl) return;
    ApplicationManagerObjC *objc = (__bridge ApplicationManagerObjC *)m_impl;
    [objc refreshShareableContentAsync:nil];
}

std::vector<AppInfo> ApplicationManager::getRunningApplications() {
    if (!m_impl) return {};
    ApplicationManagerObjC *objc = (__bridge ApplicationManagerObjC *)m_impl;
    return [objc getRunningApplicationsList];
}

bool ApplicationManager::isAppRunning(const std::string &bundle_id) {
    if (!m_impl) return false;
    ApplicationManagerObjC *objc = (__bridge ApplicationManagerObjC *)m_impl;
    return [objc isAppRunning:bundle_id] == YES;
}

void *ApplicationManager::getObjCInstance() const {
    return m_impl;
}
