#include <obs.h>
#include <iostream>
#include <cassert>

int main() {
    std::cout << "[TEST] Testing OBS Plugin Loading..." << std::endl;

    if (!obs_startup("en-US", nullptr, nullptr)) {
        std::cerr << "Failed to startup OBS core" << std::endl;
        return 1;
    }

    obs_module_t *module = nullptr;
    const char *plugin_bin = "/Users/nishantpatel/Library/Application Support/obs-studio/plugins/obs-privacy-capture.plugin/Contents/MacOS/obs-privacy-capture";
    const char *data_path = "/Users/nishantpatel/Library/Application Support/obs-studio/plugins/obs-privacy-capture.plugin/Contents/Resources";

    int result = obs_open_module(&module, plugin_bin, data_path);
    std::cout << "  obs_open_module result: " << result << std::endl;
    assert(result == MODULE_SUCCESS);
    assert(module != nullptr);

    bool loaded = obs_init_module(module);
    std::cout << "  obs_init_module: " << (loaded ? "SUCCESS" : "FAILED") << std::endl;
    assert(loaded == true);

    // Verify source registration
    const char *source_id = "privacy_capture";
    const char *display_name = obs_source_get_display_name(source_id);
    std::cout << "  Registered source '" << source_id << "' -> display name: '"
              << (display_name ? display_name : "NULL") << "'" << std::endl;
    assert(display_name != nullptr);

    // Test creating a dummy instance of privacy_capture
    obs_data_t *settings = obs_data_create();
    obs_source_t *source = obs_source_create(source_id, "Test Privacy Capture", settings, nullptr);
    assert(source != nullptr);
    std::cout << "  Successfully created source instance in OBS core: " << obs_source_get_name(source) << std::endl;

    obs_properties_t *props = obs_source_properties(source);
    assert(props != nullptr);
    std::cout << "  Successfully retrieved source properties dialog definition" << std::endl;
    obs_properties_destroy(props);

    obs_source_release(source);
    obs_data_release(settings);

    obs_shutdown();
    std::cout << "OBS Plugin Loading Test Passed Successfully!" << std::endl;
    return 0;
}
