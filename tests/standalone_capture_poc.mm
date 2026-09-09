#import <Foundation/Foundation.h>
#include <iostream>
#include <cassert>
#include <chrono>
#include <thread>
#include "capture_engine.hpp"

int main() {
    @autoreleasepool {
        std::cout << "[TEST] Running Standalone Capture Engine POC..." << std::endl;

        CaptureEngine engine;
        assert(engine.initialize());

        PrivacyCaptureSettings settings;
        settings.display_uuid = ""; // Primary display
        settings.show_cursor = true;
        settings.auto_refresh = true;
        settings.add_excluded_app("com.apple.Terminal", "Terminal");
        settings.add_excluded_app("com.google.Chrome", "Google Chrome");

        std::cout << "  Starting capture with excluded apps: Terminal, Chrome..." << std::endl;
        bool started = engine.start(settings, 60);
        if (!started) {
            std::cerr << "  Failed to start capture: " << engine.getStatusMessage() << std::endl;
            return 1;
        }

        std::cout << "  Status: " << engine.getStatusMessage() << std::endl;

        // Poll for frames
        IOSurfaceRef surface = nullptr;
        int attempts = 0;
        while (!surface && attempts < 40) {
            std::this_thread::sleep_for(std::chrono::milliseconds(100));
            surface = engine.acquireCurrentSurface();
            attempts++;
        }

        if (!surface) {
            std::cerr << "  Failed to receive frames within timeout!" << std::endl;
            return 1;
        }

        uint32_t width = engine.getWidth();
        uint32_t height = engine.getHeight();
        std::cout << "  ✓ Received frame! Dimensions: " << width << "x" << height << std::endl;
        assert(width > 0 && height > 0);

        IOSurfaceDecrementUseCount(surface);
        CFRelease(surface);

        // Test dynamic exclusion update
        std::cout << "  Testing dynamic update: adding Finder to exclusions..." << std::endl;
        settings.add_excluded_app("com.apple.finder", "Finder");
        bool updated = engine.updateSettings(settings);
        assert(updated == true);
        std::cout << "  Status after dynamic update: " << engine.getStatusMessage() << std::endl;

        // Receive another frame to ensure stream is still healthy
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        surface = engine.acquireCurrentSurface();
        assert(surface != nullptr);
        IOSurfaceDecrementUseCount(surface);
        CFRelease(surface);
        std::cout << "  ✓ Stream remained healthy and continued delivering frames after dynamic filter update!" << std::endl;

        // Test dynamic switch to Include Workspace Mode (Whitelist)
        std::cout << "  Testing switch to CaptureModeInclude (Workspace Whitelist)..." << std::endl;
        settings.filter_mode = CaptureModeInclude;
        updated = engine.updateSettings(settings);
        assert(updated == true);
        std::cout << "  Status after switch to Include mode: " << engine.getStatusMessage() << std::endl;

        std::this_thread::sleep_for(std::chrono::milliseconds(200));
        surface = engine.acquireCurrentSurface();
        assert(surface != nullptr);
        IOSurfaceDecrementUseCount(surface);
        CFRelease(surface);
        std::cout << "  ✓ Received frame in Include Workspace Mode!" << std::endl;

        engine.stop();
        std::cout << "  Capture engine stopped cleanly." << std::endl;
        std::cout << "Standalone Capture Engine POC Passed Successfully!" << std::endl;
    }
    return 0;
}
