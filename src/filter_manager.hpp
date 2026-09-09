#pragma once

#import <Foundation/Foundation.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#include "settings.hpp"
#include <string>
#include <vector>
#include <set>

#ifdef __OBJC__
@interface FilterManagerObjC : NSObject

- (SCDisplay * _Nullable)findDisplayInContent:(SCShareableContent *)content
                                 displayUUID:(const std::string &)displayUUID
                                   displayID:(uint32_t)displayID;

- (SCContentFilter * _Nullable)createFilterForDisplay:(SCDisplay *)display
                                         applications:(NSArray<SCRunningApplication *> *)apps
                                           filterMode:(CaptureFilterMode)mode;

- (SCContentFilter * _Nullable)createFilterForDisplay:(SCDisplay *)display
                                         applications:(NSArray<SCRunningApplication *> *)apps;

- (BOOL)hasExclusionSetChangedWithPreviousPIDs:(const std::set<pid_t> &)prevPIDs
                               currentExcluded:(NSArray<SCRunningApplication *> *)currentApps;

@end
#endif

class FilterManager {
public:
    FilterManager();
    ~FilterManager();

    void *getObjCInstance() const;

private:
    void *m_impl = nullptr;
};
