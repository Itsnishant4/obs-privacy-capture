#pragma once

#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#include <string>
#include <vector>
#include <memory>

struct AppInfo {
    std::string bundle_id;
    std::string application_name;
    pid_t process_id = 0;
};

#ifdef __OBJC__
@interface ApplicationManagerObjC : NSObject

@property (nonatomic, strong, nullable) SCShareableContent *shareableContent;

- (void)refreshShareableContentSync:(NSTimeInterval)timeoutSeconds;
- (void)refreshShareableContentAsync:(void (^ _Nullable)(BOOL success))completion;
- (NSArray<SCRunningApplication *> *)resolveRunningApplicationsForBundleIDs:(const std::vector<std::string> &)bundleIDs;
- (std::vector<AppInfo>)getRunningApplicationsList;
- (BOOL)isAppRunning:(const std::string &)bundleID;

@end
#endif

class ApplicationManager {
public:
    ApplicationManager();
    ~ApplicationManager();

    bool refreshContent(double timeoutSeconds = 2.0);
    void refreshContentAsync();
    
    std::vector<AppInfo> getRunningApplications();
    bool isAppRunning(const std::string &bundle_id);

    // Opaque pointer to Objective-C implementation
    void *getObjCInstance() const;

private:
    void *m_impl = nullptr;
};
