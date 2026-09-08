#import <Foundation/Foundation.h>
#include <cassert>
#include <iostream>
#include "application_manager.hpp"

int main() {
    @autoreleasepool {
        std::cout << "[TEST] Running Application Manager Tests..." << std::endl;

        ApplicationManager appManager;
        bool refreshed = appManager.refreshContent(3.0);
        std::cout << "  Refreshed content: " << (refreshed ? "YES" : "NO") << std::endl;
        assert(refreshed == true);

        auto apps = appManager.getRunningApplications();
        std::cout << "  Found " << apps.size() << " running applications." << std::endl;
        assert(!apps.empty());

        bool foundTerminal = false;
        bool foundFinder = false;
        for (const auto &app : apps) {
            if (app.bundle_id == "com.apple.Terminal") foundTerminal = true;
            if (app.bundle_id == "com.apple.finder") foundFinder = true;
        }

        std::cout << "  Found Finder: " << (foundFinder ? "YES" : "NO") << std::endl;
        assert(foundFinder == true);
        assert(appManager.isAppRunning("com.apple.finder") == true);
        assert(appManager.isAppRunning("com.totally.fake.bundle.id.that.does.not.exist") == false);

        std::cout << "All Application Manager Tests Passed!" << std::endl;
    }
    return 0;
}
