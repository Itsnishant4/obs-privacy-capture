#include "settings.hpp"
#include <algorithm>
#include <sstream>

std::vector<std::string> PrivacyCaptureSettings::get_active_bundle_ids() const {
    std::vector<std::string> ids;
    for (const auto &app : excluded_apps) {
        if (app.enabled && !app.bundle_id.empty()) {
            ids.push_back(app.bundle_id);
        }
    }
    return ids;
}

bool PrivacyCaptureSettings::is_app_excluded(const std::string &bundle_id) const {
    if (bundle_id.empty()) return false;
    for (const auto &app : excluded_apps) {
        if (app.enabled && app.bundle_id == bundle_id) {
            return true;
        }
    }
    return false;
}

bool PrivacyCaptureSettings::add_excluded_app(const std::string &bundle_id, const std::string &name) {
    if (bundle_id.empty()) return false;
    for (auto &app : excluded_apps) {
        if (app.bundle_id == bundle_id) {
            app.enabled = true;
            if (!name.empty()) {
                app.display_name = name;
            }
            return false; // Already existed, re-enabled
        }
    }
    ExcludedApplication new_app;
    new_app.bundle_id = bundle_id;
    new_app.display_name = name.empty() ? bundle_id : name;
    new_app.enabled = true;
    excluded_apps.push_back(new_app);
    return true;
}

bool PrivacyCaptureSettings::remove_excluded_app(const std::string &bundle_id) {
    auto it = std::remove_if(excluded_apps.begin(), excluded_apps.end(),
                             [&](const ExcludedApplication &app) {
                                 return app.bundle_id == bundle_id;
                             });
    if (it != excluded_apps.end()) {
        excluded_apps.erase(it, excluded_apps.end());
        return true;
    }
    return false;
}

void PrivacyCaptureSettings::clear_excluded_apps() {
    excluded_apps.clear();
}

void privacy_capture_settings_set_defaults(obs_data_t *settings) {
    obs_data_set_default_string(settings, "display_uuid", "");
    obs_data_set_default_bool(settings, "show_cursor", true);
    obs_data_set_default_bool(settings, "auto_refresh", true);
    obs_data_set_default_string(settings, "selected_app_to_add", "");
}

PrivacyCaptureSettings privacy_capture_settings_load(obs_data_t *settings) {
    PrivacyCaptureSettings config;
    if (!settings) return config;

    const char *uuid = obs_data_get_string(settings, "display_uuid");
    config.display_uuid = uuid ? uuid : "";

    config.show_cursor = obs_data_get_bool(settings, "show_cursor");
    config.auto_refresh = obs_data_get_bool(settings, "auto_refresh");

    // Load excluded applications list from obs_data_array
    obs_data_array_t *array = obs_data_get_array(settings, "excluded_apps");
    if (array) {
        size_t count = obs_data_array_count(array);
        for (size_t i = 0; i < count; i++) {
            obs_data_t *item = obs_data_array_item(array, i);
            if (item) {
                const char *val = obs_data_get_string(item, "value");
                if (val && *val) {
                    std::string bundle_id = val;
                    // Trim whitespace
                    bundle_id.erase(0, bundle_id.find_first_not_of(" \t\r\n"));
                    bundle_id.erase(bundle_id.find_last_not_of(" \t\r\n") + 1);

                    if (!bundle_id.empty()) {
                        config.add_excluded_app(bundle_id);
                    }
                }
                obs_data_release(item);
            }
        }
        obs_data_array_release(array);
    }

    return config;
}

void privacy_capture_settings_save(const PrivacyCaptureSettings &config, obs_data_t *settings) {
    if (!settings) return;

    obs_data_set_string(settings, "display_uuid", config.display_uuid.c_str());
    obs_data_set_bool(settings, "show_cursor", config.show_cursor);
    obs_data_set_bool(settings, "auto_refresh", config.auto_refresh);

    obs_data_array_t *array = obs_data_array_create();
    for (const auto &app : config.excluded_apps) {
        if (!app.bundle_id.empty()) {
            obs_data_t *item = obs_data_create();
            obs_data_set_string(item, "value", app.bundle_id.c_str());
            obs_data_set_bool(item, "hidden", !app.enabled);
            obs_data_array_push_back(array, item);
            obs_data_release(item);
        }
    }
    obs_data_set_array(settings, "excluded_apps", array);
    obs_data_array_release(array);
}
