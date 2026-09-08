#pragma once

#import <Foundation/Foundation.h>
#import <IOSurface/IOSurface.h>
#include "settings.hpp"
#include "application_manager.hpp"
#include <string>
#include <vector>
#include <set>
#include <mutex>

enum CaptureStatusCode {
    CaptureStatusReady = 0,
    CaptureStatusCapturing = 1,
    CaptureStatusPermissionRequired = 2,
    CaptureStatusDisplayUnavailable = 3,
    CaptureStatusError = 4
};

class CaptureEngine {
public:
    CaptureEngine();
    ~CaptureEngine();

    bool initialize();
    bool start(const PrivacyCaptureSettings &settings, uint32_t targetFPS = 60);
    void stop();

    bool updateSettings(const PrivacyCaptureSettings &newSettings);
    bool checkAndRefreshExclusions();

    // Acquires newly captured surface (consumer should release when finished)
    IOSurfaceRef acquireCurrentSurface();

    uint32_t getWidth() const;
    uint32_t getHeight() const;
    CaptureStatusCode getStatusCode() const;
    std::string getStatusMessage() const;

    std::vector<AppInfo> getAvailableApplications();
    bool isCapturing() const;

private:
    void *m_impl = nullptr;
};
