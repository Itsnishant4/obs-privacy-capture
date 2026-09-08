#pragma once

#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <IOSurface/IOSurface.h>
#include <functional>
#include <cstdint>

typedef std::function<void(IOSurfaceRef _Nonnull surface, uint32_t width, uint32_t height)> FrameCallback;
typedef std::function<void(NSError * _Nullable error)> ErrorCallback;

#ifdef __OBJC__
@interface StreamManagerObjC : NSObject <SCStreamOutput, SCStreamDelegate>

@property (nonatomic, strong, nullable) SCStream *stream;
@property (nonatomic, assign) FrameCallback frameCallback;
@property (nonatomic, assign) ErrorCallback errorCallback;
@property (nonatomic, assign) BOOL isCapturing;
@property (nonatomic, assign) uint32_t currentWidth;
@property (nonatomic, assign) uint32_t currentHeight;

- (BOOL)startWithFilter:(SCContentFilter *)filter
             showCursor:(BOOL)showCursor
              targetFPS:(uint32_t)targetFPS
         completionSync:(NSTimeInterval)timeoutSeconds;

- (void)stopSync:(NSTimeInterval)timeoutSeconds;

- (void)updateFilter:(SCContentFilter *)filter
      completionAsync:(void (^ _Nullable)(BOOL success, NSError * _Nullable error))completion;

- (void)updateShowCursor:(BOOL)showCursor;

@end
#endif

class StreamManager {
public:
    StreamManager();
    ~StreamManager();

    void setFrameCallback(FrameCallback callback);
    void setErrorCallback(ErrorCallback callback);

    bool start(void *scContentFilter, bool showCursor, uint32_t targetFPS, double timeoutSeconds = 5.0);
    void stop(double timeoutSeconds = 3.0);
    bool updateFilter(void *scContentFilter);
    void updateShowCursor(bool showCursor);

    bool isCapturing() const;
    void getDimensions(uint32_t &width, uint32_t &height) const;

    void *getObjCInstance() const;

private:
    void *m_impl = nullptr;
};
