#include <cassert>
#include <iostream>
#include "settings.hpp"
#include <obs.h>

int main() {
    std::cout << "[TEST] Running Settings Tests..." << std::endl;

    // Test 1: Defaults
    PrivacyCaptureSettings config;
    assert(config.show_cursor == true);
    assert(config.auto_refresh == true);
    assert(config.excluded_apps.empty());
    assert(config.get_active_bundle_ids().empty());
    std::cout << "  ✓ Defaults verified" << std::endl;

    // Test 2: Add and check excluded apps
    assert(config.add_excluded_app("com.hnc.Discord", "Discord") == true);
    assert(config.add_excluded_app("com.apple.Terminal", "Terminal") == true);
    assert(config.add_excluded_app("com.hnc.Discord", "Discord Duplicate") == false); // already exists
    assert(config.is_app_excluded("com.hnc.Discord") == true);
    assert(config.is_app_excluded("com.apple.Terminal") == true);
    assert(config.is_app_excluded("com.google.Chrome") == false);

    auto active_ids = config.get_active_bundle_ids();
    assert(active_ids.size() == 2);
    assert(active_ids[0] == "com.hnc.Discord");
    assert(active_ids[1] == "com.apple.Terminal");
    std::cout << "  ✓ Add and check exclusions verified" << std::endl;

    // Test 3: Remove excluded app
    assert(config.remove_excluded_app("com.apple.Terminal") == true);
    assert(config.is_app_excluded("com.apple.Terminal") == false);
    assert(config.get_active_bundle_ids().size() == 1);
    assert(config.remove_excluded_app("non.existent.app") == false);
    std::cout << "  ✓ Remove exclusion verified" << std::endl;

    // Test 4: Serialization to obs_data_t and deserialization
    obs_data_t *data = obs_data_create();
    config.display_uuid = "12345-67890";
    config.show_cursor = false;
    config.auto_refresh = true;
    config.add_excluded_app("com.google.Chrome", "Google Chrome");
    config.add_excluded_app("com.microsoft.VSCode", "VS Code");

    privacy_capture_settings_save(config, data);

    PrivacyCaptureSettings loaded = privacy_capture_settings_load(data);
    assert(loaded.display_uuid == "12345-67890");
    assert(loaded.show_cursor == false);
    assert(loaded.auto_refresh == true);
    assert(loaded.is_app_excluded("com.hnc.Discord") == true);
    assert(loaded.is_app_excluded("com.google.Chrome") == true);
    assert(loaded.is_app_excluded("com.microsoft.VSCode") == true);
    assert(loaded.is_app_excluded("com.apple.Terminal") == false);
    assert(loaded.get_active_bundle_ids().size() == 3);

    obs_data_release(data);
    std::cout << "  ✓ Serialization and deserialization verified" << std::endl;

    std::cout << "All Settings Tests Passed!" << std::endl;
    return 0;
}
