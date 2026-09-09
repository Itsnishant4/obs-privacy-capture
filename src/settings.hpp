#pragma once

#include <string>
#include <vector>
#include <cstdint>
#include <obs-data.h>

enum CaptureFilterMode {
    CaptureModeExclude = 0, // Exclude selected apps (blacklist)
    CaptureModeInclude = 1  // Include ONLY selected apps (whitelist / workspace)
};

struct ExcludedApplication {
    std::string bundle_id;
    std::string display_name;
    bool enabled = true;
};

struct PrivacyCaptureSettings {
    std::string display_uuid;
    uint32_t display_id = 0;
    bool show_cursor = true;
    bool auto_refresh = true;
    CaptureFilterMode filter_mode = CaptureModeExclude;
    std::vector<ExcludedApplication> excluded_apps;

    std::vector<std::string> get_active_bundle_ids() const;
    bool is_app_excluded(const std::string &bundle_id) const;
    bool add_excluded_app(const std::string &bundle_id, const std::string &name = "");
    bool remove_excluded_app(const std::string &bundle_id);
    void clear_excluded_apps();
};

void privacy_capture_settings_set_defaults(obs_data_t *settings);
PrivacyCaptureSettings privacy_capture_settings_load(obs_data_t *settings);
void privacy_capture_settings_save(const PrivacyCaptureSettings &config, obs_data_t *settings);
