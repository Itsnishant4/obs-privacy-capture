#include <obs-module.h>
#include "privacy_capture.hpp"

OBS_DECLARE_MODULE()
OBS_MODULE_USE_DEFAULT_LOCALE("obs-privacy-capture", "en-US")

MODULE_EXPORT const char *obs_module_description(void) {
    return "Privacy Capture plugin for macOS OBS Studio using ScreenCaptureKit application exclusion filtering.";
}

MODULE_EXPORT const char *obs_module_name(void) {
    return "Privacy Capture";
}

bool obs_module_load(void) {
    blog(LOG_INFO, "[PrivacyCapture] Loading Privacy Capture module...");
    obs_register_source(&privacy_capture_source_info);
    blog(LOG_INFO, "[PrivacyCapture] Privacy Capture source successfully registered.");
    return true;
}

void obs_module_unload(void) {
    blog(LOG_INFO, "[PrivacyCapture] Unloading Privacy Capture module.");
}
