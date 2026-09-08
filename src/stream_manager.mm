#import "stream_manager.hpp"

@implementation StreamManagerObjC {
    dispatch_queue_t _captureQueue;
    SCStreamConfiguration *_config;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _captureQueue = dispatch_queue_create("com.antigravity.privacy_capture.stream",
                                              DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self stopSync:1.0];
}

- (BOOL)startWithFilter:(SCContentFilter *)filter
             showCursor:(BOOL)showCursor
              targetFPS:(uint32_t)targetFPS
         completionSync:(NSTimeInterval)timeoutSeconds {
    if (!filter) return NO;
    if (self.isCapturing) {
        [self stopSync:2.0];
    }

    _config = [[SCStreamConfiguration alloc] init];
    _config.queueDepth = 8;
    _config.showsCursor = showCursor;
    _config.colorSpaceName = kCGColorSpaceDisplayP3;
    _config.backgroundColor = CGColorGetConstantColor(kCGColorClear);

    uint32_t fps = (targetFPS > 0 && targetFPS <= 240) ? targetFPS : 60;
    _config.minimumFrameInterval = CMTimeMake(1, fps);

    // Set pixel format to 10-bit RGB ('l10r') as used in standard OBS ScreenCaptureKit capture
    FourCharCode l10r_type = ('l' << 24) | ('1' << 16) | ('0' << 8) | 'r';
    _config.pixelFormat = l10r_type;

    NSError *initError = nil;
    self.stream = [[SCStream alloc] initWithFilter:filter configuration:_config delegate:self];

    NSError *outputError = nil;
    BOOL added = [self.stream addStreamOutput:self
                                         type:SCStreamOutputTypeScreen
                           sampleHandlerQueue:_captureQueue
                                        error:&outputError];
    if (!added || outputError) {
        NSLog(@"[PrivacyCapture] Failed to add stream output: %@", outputError);
        self.stream = nil;
        return NO;
    }

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block BOOL started = NO;
    [self.stream startCaptureWithCompletionHandler:^(NSError * _Nullable error) {
        if (!error) {
            started = YES;
            self.isCapturing = YES;
        } else {
            NSLog(@"[PrivacyCapture] startCapture failed: %@", error);
            self.stream = nil;
            self.isCapturing = NO;
        }
        dispatch_semaphore_signal(sem);
    }];

    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutSeconds * NSEC_PER_SEC)));
    return started;
}

- (void)stopSync:(NSTimeInterval)timeoutSeconds {
    if (!self.stream || !self.isCapturing) {
        self.stream = nil;
        self.isCapturing = NO;
        return;
    }

    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    [self.stream stopCaptureWithCompletionHandler:^(NSError * _Nullable error) {
        dispatch_semaphore_signal(sem);
    }];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutSeconds * NSEC_PER_SEC)));
    self.stream = nil;
    self.isCapturing = NO;
}

- (void)updateFilter:(SCContentFilter *)filter
      completionAsync:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion {
    if (!self.stream || !self.isCapturing || !filter) {
        if (completion) completion(NO, nil);
        return;
    }

    [self.stream updateContentFilter:filter completionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[PrivacyCapture] updateContentFilter error: %@", error);
        }
        if (completion) {
            completion(error == nil, error);
        }
    }];
}

- (void)updateShowCursor:(BOOL)showCursor {
    if (!self.stream || !_config) return;
    _config.showsCursor = showCursor;
    [self.stream updateConfiguration:_config completionHandler:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"[PrivacyCapture] updateConfiguration for cursor error: %@", error);
        }
    }];
}

#pragma mark - SCStreamOutput & SCStreamDelegate

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(SCStreamOutputType)type {
    if (type == SCStreamOutputTypeScreen) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (imageBuffer) {
            IOSurfaceRef surface = CVPixelBufferGetIOSurface(imageBuffer);
            if (surface) {
                uint32_t w = (uint32_t)CVPixelBufferGetWidth(imageBuffer);
                uint32_t h = (uint32_t)CVPixelBufferGetHeight(imageBuffer);
                self.currentWidth = w;
                self.currentHeight = h;

                if (self.frameCallback) {
                    self.frameCallback(surface, w, h);
                }
            }
        }
    }
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    NSLog(@"[PrivacyCapture] Stream stopped with error: %@", error);
    self.isCapturing = NO;
    if (self.errorCallback) {
        self.errorCallback(error);
    }
}

@end

StreamManager::StreamManager() {
    StreamManagerObjC *objc = [[StreamManagerObjC alloc] init];
    m_impl = (__bridge_retained void *)objc;
}

StreamManager::~StreamManager() {
    if (m_impl) {
        StreamManagerObjC *objc = (__bridge_transfer StreamManagerObjC *)m_impl;
        [objc stopSync:1.0];
        objc = nil;
        m_impl = nullptr;
    }
}

void StreamManager::setFrameCallback(FrameCallback callback) {
    if (!m_impl) return;
    StreamManagerObjC *objc = (__bridge StreamManagerObjC *)m_impl;
    objc.frameCallback = callback;
}

void StreamManager::setErrorCallback(ErrorCallback callback) {
    if (!m_impl) return;
    StreamManagerObjC *objc = (__bridge StreamManagerObjC *)m_impl;
    objc.errorCallback = callback;
}

bool StreamManager::start(void *scContentFilter, bool showCursor, uint32_t targetFPS, double timeoutSeconds) {
    if (!m_impl || !scContentFilter) return false;
    StreamManagerObjC *objc = (__bridge StreamManagerObjC *)m_impl;
    SCContentFilter *filter = (__bridge SCContentFilter *)scContentFilter;
    return [objc startWithFilter:filter showCursor:showCursor targetFPS:targetFPS completionSync:timeoutSeconds] == YES;
}

void StreamManager::stop(double timeoutSeconds) {
    if (!m_impl) return;
    StreamManagerObjC *objc = (__bridge StreamManagerObjC *)m_impl;
    [objc stopSync:timeoutSeconds];
}

bool StreamManager::updateFilter(void *scContentFilter) {
    if (!m_impl || !scContentFilter) return false;
    StreamManagerObjC *objc = (__bridge StreamManagerObjC *)m_impl;
    SCContentFilter *filter = (__bridge SCContentFilter *)scContentFilter;
    [objc updateFilter:filter completionAsync:nil];
    return true;
}

void StreamManager::updateShowCursor(bool showCursor) {
    if (!m_impl) return;
    StreamManagerObjC *objc = (__bridge StreamManagerObjC *)m_impl;
    [objc updateShowCursor:showCursor];
}

bool StreamManager::isCapturing() const {
    if (!m_impl) return false;
    StreamManagerObjC *objc = (__bridge StreamManagerObjC *)m_impl;
    return objc.isCapturing == YES;
}

void StreamManager::getDimensions(uint32_t &width, uint32_t &height) const {
    if (!m_impl) {
        width = 0;
        height = 0;
        return;
    }
    StreamManagerObjC *objc = (__bridge StreamManagerObjC *)m_impl;
    width = objc.currentWidth;
    height = objc.currentHeight;
}

void *StreamManager::getObjCInstance() const {
    return m_impl;
}
