#import "privacy_capture.hpp"
#import "capture_engine.hpp"
#import "application_manager.hpp"
#import "settings.hpp"
#import <AppKit/AppKit.h>
#include <util/bmem.h>

struct privacy_capture_source {
    obs_source_t *source;
    CaptureEngine *engine;
    gs_effect_t *effect;
    gs_texture_t *tex;
    IOSurfaceRef prev_surface;
    PrivacyCaptureSettings settings;
    obs_hotkey_id hotkey_exclude_active;
    obs_hotkey_id hotkey_toggle_active;
    obs_hotkey_id hotkey_clear_exclusions;
};

static const char *privacy_capture_get_name(void *unused) {
    (void)unused;
    return obs_module_text("PrivacyCapture.Name");
}

static void hotkey_exclude_active(void *data, obs_hotkey_id id, obs_hotkey_t *hotkey, bool pressed) {
    (void)id;
    (void)hotkey;
    if (!pressed) return;

    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    if (!s || !s->engine) return;

    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (!front || !front.bundleIdentifier) return;

    NSString *main_bid = [[NSBundle mainBundle] bundleIdentifier];
    if (main_bid && [front.bundleIdentifier isEqualToString:main_bid]) {
        blog(LOG_INFO, "[PrivacyCapture] Frontmost application is OBS Studio itself. Ignoring hotkey.");
        return;
    }

    std::string bid = [front.bundleIdentifier UTF8String];
    std::string name = front.localizedName ? [front.localizedName UTF8String] : bid;

    bool added = s->settings.add_excluded_app(bid, name);
    if (added) {
        blog(LOG_INFO, "[PrivacyCapture] Universal Hotkey Exclude: Added '%s' (%s) to exclusions", name.c_str(), bid.c_str());
        NSBeep();
    }

    obs_data_t *settings = obs_source_get_settings(s->source);
    if (settings) {
        privacy_capture_settings_save(s->settings, settings);
        obs_data_release(settings);
    }

    s->engine->updateSettings(s->settings);
}

static void hotkey_toggle_active(void *data, obs_hotkey_id id, obs_hotkey_t *hotkey, bool pressed) {
    (void)id;
    (void)hotkey;
    if (!pressed) return;

    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    if (!s || !s->engine) return;

    NSRunningApplication *front = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (!front || !front.bundleIdentifier) return;

    NSString *main_bid = [[NSBundle mainBundle] bundleIdentifier];
    if (main_bid && [front.bundleIdentifier isEqualToString:main_bid]) {
        blog(LOG_INFO, "[PrivacyCapture] Frontmost application is OBS Studio itself. Ignoring hotkey.");
        return;
    }

    std::string bid = [front.bundleIdentifier UTF8String];
    std::string name = front.localizedName ? [front.localizedName UTF8String] : bid;

    if (s->settings.is_app_excluded(bid)) {
        s->settings.remove_excluded_app(bid);
        blog(LOG_INFO, "[PrivacyCapture] Universal Hotkey Toggle: Un-excluded '%s' (%s)", name.c_str(), bid.c_str());
    } else {
        s->settings.add_excluded_app(bid, name);
        blog(LOG_INFO, "[PrivacyCapture] Universal Hotkey Toggle: Excluded '%s' (%s)", name.c_str(), bid.c_str());
        NSBeep();
    }

    obs_data_t *settings = obs_source_get_settings(s->source);
    if (settings) {
        privacy_capture_settings_save(s->settings, settings);
        obs_data_release(settings);
    }

    s->engine->updateSettings(s->settings);
}

static void hotkey_clear_exclusions(void *data, obs_hotkey_id id, obs_hotkey_t *hotkey, bool pressed) {
    (void)id;
    (void)hotkey;
    if (!pressed) return;

    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    if (!s || !s->engine) return;

    s->settings.clear_excluded_apps();
    blog(LOG_INFO, "[PrivacyCapture] Universal Hotkey Clear: Cleared all exclusions");
    NSBeep();

    obs_data_t *settings = obs_source_get_settings(s->source);
    if (settings) {
        privacy_capture_settings_save(s->settings, settings);
        obs_data_release(settings);
    }

    s->engine->updateSettings(s->settings);
}

static void privacy_capture_destroy(void *data) {
    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    if (!s) return;

    if (s->hotkey_exclude_active) {
        obs_hotkey_unregister(s->hotkey_exclude_active);
        s->hotkey_exclude_active = OBS_INVALID_HOTKEY_ID;
    }
    if (s->hotkey_toggle_active) {
        obs_hotkey_unregister(s->hotkey_toggle_active);
        s->hotkey_toggle_active = OBS_INVALID_HOTKEY_ID;
    }
    if (s->hotkey_clear_exclusions) {
        obs_hotkey_unregister(s->hotkey_clear_exclusions);
        s->hotkey_clear_exclusions = OBS_INVALID_HOTKEY_ID;
    }

    if (s->engine) {
        s->engine->stop();
        delete s->engine;
        s->engine = nullptr;
    }

    obs_enter_graphics();
    if (s->tex) {
        gs_texture_destroy(s->tex);
        s->tex = nullptr;
    }
    obs_leave_graphics();

    if (s->prev_surface) {
        IOSurfaceDecrementUseCount(s->prev_surface);
        CFRelease(s->prev_surface);
        s->prev_surface = NULL;
    }

    bfree(s);
}

static void *privacy_capture_create(obs_data_t *settings, obs_source_t *source) {
    struct privacy_capture_source *s = (struct privacy_capture_source *)bzalloc(sizeof(struct privacy_capture_source));
    s->source = source;
    s->settings = privacy_capture_settings_load(settings);
    s->engine = new CaptureEngine();

    obs_enter_graphics();
    if (gs_get_device_type() == GS_DEVICE_OPENGL) {
        s->effect = obs_get_base_effect(OBS_EFFECT_DEFAULT_RECT);
    } else {
        s->effect = obs_get_base_effect(OBS_EFFECT_DEFAULT);
    }
    obs_leave_graphics();

    uint32_t target_fps = 60;
    struct obs_video_info ovi;
    if (obs_get_video_info(&ovi) && ovi.fps_den > 0) {
        target_fps = (uint32_t)(ovi.fps_num / ovi.fps_den);
    }

    s->engine->start(s->settings, target_fps);

    // Register Universal Hotkeys with OBS source
    s->hotkey_exclude_active = obs_hotkey_register_source(
        source,
        "PrivacyCapture.Hotkey.ExcludeActive",
        obs_module_text("PrivacyCapture.Hotkey.ExcludeActive"),
        hotkey_exclude_active,
        s);

    s->hotkey_toggle_active = obs_hotkey_register_source(
        source,
        "PrivacyCapture.Hotkey.ToggleActive",
        obs_module_text("PrivacyCapture.Hotkey.ToggleActive"),
        hotkey_toggle_active,
        s);

    s->hotkey_clear_exclusions = obs_hotkey_register_source(
        source,
        "PrivacyCapture.Hotkey.ClearExclusions",
        obs_module_text("PrivacyCapture.Hotkey.ClearExclusions"),
        hotkey_clear_exclusions,
        s);

    return s;
}

static uint32_t privacy_capture_get_width(void *data) {
    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    return s && s->engine ? s->engine->getWidth() : 0;
}

static uint32_t privacy_capture_get_height(void *data) {
    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    return s && s->engine ? s->engine->getHeight() : 0;
}

static void privacy_capture_get_defaults(obs_data_t *settings) {
    privacy_capture_settings_set_defaults(settings);
}

static bool on_add_application_clicked(obs_properties_t *props, obs_property_t *p, void *data) {
    (void)props;
    (void)p;
    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    if (!s) return false;

    obs_data_t *settings = obs_source_get_settings(s->source);
    if (!settings) return false;

    const char *selected_bid = obs_data_get_string(settings, "selected_app_to_add");
    if (selected_bid && *selected_bid) {
        s->settings.add_excluded_app(selected_bid);
        privacy_capture_settings_save(s->settings, settings);
        if (s->engine) {
            s->engine->updateSettings(s->settings);
        }
    }
    obs_data_release(settings);
    return true; // Reloads properties
}

static bool on_refresh_clicked(obs_properties_t *props, obs_property_t *p, void *data) {
    (void)props;
    (void)p;
    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    if (!s || !s->engine) return false;

    s->engine->checkAndRefreshExclusions();
    return true; // Reloads properties
}

static obs_properties_t *privacy_capture_get_properties(void *data) {
    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    obs_properties_t *props = obs_properties_create();

    // 1. Display Selector
    obs_property_t *display_list = obs_properties_add_list(props, "display_uuid",
                                                           obs_module_text("PrivacyCapture.Display"),
                                                           OBS_COMBO_TYPE_LIST,
                                                           OBS_COMBO_FORMAT_STRING);
    obs_property_list_add_string(display_list, obs_module_text("PrivacyCapture.Display.Primary"), "");

    for (NSScreen *screen in NSScreen.screens) {
        NSNumber *num = screen.deviceDescription[@"NSScreenNumber"];
        CGDirectDisplayID did = (CGDirectDisplayID)num.intValue;
        CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(did);
        if (uuid) {
            CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
            if (uuidStr) {
                char label[256];
                snprintf(label, sizeof(label), "%s (%ux%u)",
                         screen.localizedName.UTF8String,
                         (uint32_t)screen.frame.size.width,
                         (uint32_t)screen.frame.size.height);
                obs_property_list_add_string(display_list, label, [(__bridge NSString *)uuidStr UTF8String]);
                CFRelease(uuidStr);
            }
            CFRelease(uuid);
        }
    }

    // 2. Mode Selector: Exclude Mode (Blacklist) vs Include Workspace Mode (Whitelist)
    obs_property_t *mode_list = obs_properties_add_list(props, "filter_mode",
                                                         obs_module_text("PrivacyCapture.FilterMode"),
                                                         OBS_COMBO_TYPE_LIST,
                                                         OBS_COMBO_FORMAT_INT);
    obs_property_list_add_int(mode_list, obs_module_text("PrivacyCapture.FilterMode.Exclude"), CaptureModeExclude);
    obs_property_list_add_int(mode_list, obs_module_text("PrivacyCapture.FilterMode.Include"), CaptureModeInclude);

    // 3. Capture Cursor
    obs_properties_add_bool(props, "show_cursor", obs_module_text("PrivacyCapture.ShowCursor"));

    // 4. Auto Refresh / Dynamic Detection
    obs_properties_add_bool(props, "auto_refresh", obs_module_text("PrivacyCapture.AutoRefresh"));

    // 5. Quick-Add Application Picker
    obs_property_t *available_apps_list = obs_properties_add_list(props, "selected_app_to_add",
                                                                  obs_module_text("PrivacyCapture.SelectApp"),
                                                                  OBS_COMBO_TYPE_LIST,
                                                                  OBS_COMBO_FORMAT_STRING);
    obs_property_list_add_string(available_apps_list, obs_module_text("PrivacyCapture.SelectApp.Placeholder"), "");

    if (s && s->engine) {
        std::vector<AppInfo> apps = s->engine->getAvailableApplications();
        for (const auto &app : apps) {
            char item_name[256];
            snprintf(item_name, sizeof(item_name), "%s (%s)",
                     app.application_name.c_str(), app.bundle_id.c_str());
            obs_property_list_add_string(available_apps_list, item_name, app.bundle_id.c_str());
        }
    }

    // 6. Add Selected App Button
    obs_properties_add_button2(props, "add_app_btn",
                               obs_module_text("PrivacyCapture.AddSelectedApp"),
                               on_add_application_clicked, s);

    // 7. Filtered Applications List (Editable List of bundle IDs)
    obs_properties_add_editable_list(props, "excluded_apps",
                                     obs_module_text("PrivacyCapture.FilterList"),
                                     OBS_EDITABLE_LIST_TYPE_STRINGS, NULL, NULL);

    // 7. Refresh Button
    obs_properties_add_button2(props, "refresh_btn",
                               obs_module_text("PrivacyCapture.Refresh"),
                               on_refresh_clicked, s);

    // 8. Status Display (Read-Only Text)
    std::string status_msg = s && s->engine ? s->engine->getStatusMessage() : "● Ready";
    obs_property_t *status_prop = obs_properties_add_text(props, "status_info",
                                                          obs_module_text("PrivacyCapture.Status"),
                                                          OBS_TEXT_DEFAULT);
    obs_property_set_enabled(status_prop, false);
    if (s && s->source) {
        obs_data_t *settings = obs_source_get_settings(s->source);
        if (settings) {
            obs_data_set_string(settings, "status_info", status_msg.c_str());
            obs_data_release(settings);
        }
    }

    return props;
}

static void privacy_capture_update(void *data, obs_data_t *settings) {
    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    if (!s || !s->engine) return;

    s->settings = privacy_capture_settings_load(settings);
    s->engine->updateSettings(s->settings);
}

static void privacy_capture_video_tick(void *data, float seconds) {
    (void)seconds;
    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    if (!s || !s->engine) return;

    if (!obs_source_showing(s->source)) return;

    IOSurfaceRef surf = s->engine->acquireCurrentSurface();
    if (!surf) return;

    if (surf != s->prev_surface) {
        obs_enter_graphics();
        if (s->tex) {
            gs_texture_rebind_iosurface(s->tex, surf);
        } else {
            s->tex = gs_texture_create_from_iosurface(surf);
        }
        obs_leave_graphics();

        if (s->prev_surface) {
            IOSurfaceDecrementUseCount(s->prev_surface);
            CFRelease(s->prev_surface);
        }
        s->prev_surface = surf;
    } else {
        IOSurfaceDecrementUseCount(surf);
        CFRelease(surf);
    }
}

static void privacy_capture_video_render(void *data, gs_effect_t *effect) {
    (void)effect;
    struct privacy_capture_source *s = (struct privacy_capture_source *)data;
    if (!s || !s->tex || !s->effect) return;

    const bool previous = gs_framebuffer_srgb_enabled();
    gs_enable_framebuffer_srgb(true);

    gs_eparam_t *param = gs_effect_get_param_by_name(s->effect, "image");
    gs_effect_set_texture(param, s->tex);

    while (gs_effect_loop(s->effect, "DrawD65P3")) {
        gs_draw_sprite(s->tex, 0, 0, 0);
    }

    gs_enable_framebuffer_srgb(previous);
}

struct obs_source_info privacy_capture_source_info = {
    .id = "privacy_capture",
    .type = OBS_SOURCE_TYPE_INPUT,
    .output_flags = OBS_SOURCE_VIDEO | OBS_SOURCE_CUSTOM_DRAW | OBS_SOURCE_DO_NOT_DUPLICATE,
    .get_name = privacy_capture_get_name,
    .create = privacy_capture_create,
    .destroy = privacy_capture_destroy,
    .get_width = privacy_capture_get_width,
    .get_height = privacy_capture_get_height,
    .get_defaults = privacy_capture_get_defaults,
    .get_properties = privacy_capture_get_properties,
    .update = privacy_capture_update,
    .video_tick = privacy_capture_video_tick,
    .video_render = privacy_capture_video_render,
    .icon_type = OBS_ICON_TYPE_DESKTOP_CAPTURE,
};
