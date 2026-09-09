#import "filter_manager.hpp"

@implementation FilterManagerObjC

- (SCDisplay * _Nullable)findDisplayInContent:(SCShareableContent *)content
                                 displayUUID:(const std::string &)displayUUID
                                   displayID:(uint32_t)displayID {
    if (!content || content.displays.count == 0) return nil;

    // 1. Try matching by UUID if provided
    if (!displayUUID.empty()) {
        NSString *targetUUID = [NSString stringWithUTF8String:displayUUID.c_str()];
        for (SCDisplay *d in content.displays) {
            CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(d.displayID);
            if (uuid) {
                CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
                if (uuidStr) {
                    BOOL match = [(__bridge NSString *)uuidStr isEqualToString:targetUUID];
                    CFRelease(uuidStr);
                    CFRelease(uuid);
                    if (match) return d;
                } else {
                    CFRelease(uuid);
                }
            }
        }
    }

    // 2. Try matching by displayID
    if (displayID > 0) {
        for (SCDisplay *d in content.displays) {
            if (d.displayID == displayID) {
                return d;
            }
        }
    }

    // 3. Fallback to primary/first display
    return content.displays.firstObject;
}

- (SCContentFilter * _Nullable)createFilterForDisplay:(SCDisplay *)display
                                         applications:(NSArray<SCRunningApplication *> *)apps
                                           filterMode:(CaptureFilterMode)mode {
    if (!display) return nil;
    NSArray<SCRunningApplication *> *targetApps = apps ? apps : @[];
    NSArray<SCWindow *> *excepting = @[];

    if (mode == CaptureModeInclude) {
        return [[SCContentFilter alloc] initWithDisplay:display
                                  includingApplications:targetApps
                                       exceptingWindows:excepting];
    } else {
        return [[SCContentFilter alloc] initWithDisplay:display
                                  excludingApplications:targetApps
                                       exceptingWindows:excepting];
    }
}

- (SCContentFilter * _Nullable)createFilterForDisplay:(SCDisplay *)display
                                         applications:(NSArray<SCRunningApplication *> *)apps {
    return [self createFilterForDisplay:display applications:apps filterMode:CaptureModeExclude];
}

- (BOOL)hasExclusionSetChangedWithPreviousPIDs:(const std::set<pid_t> &)prevPIDs
                               currentExcluded:(NSArray<SCRunningApplication *> *)currentApps {
    std::set<pid_t> currentPIDs;
    for (SCRunningApplication *app in currentApps) {
        currentPIDs.insert(app.processID);
    }
    return currentPIDs != prevPIDs;
}

@end

FilterManager::FilterManager() {
    FilterManagerObjC *objc = [[FilterManagerObjC alloc] init];
    m_impl = (__bridge_retained void *)objc;
}

FilterManager::~FilterManager() {
    if (m_impl) {
        FilterManagerObjC *objc = (__bridge_transfer FilterManagerObjC *)m_impl;
        objc = nil;
        m_impl = nullptr;
    }
}

void *FilterManager::getObjCInstance() const {
    return m_impl;
}
