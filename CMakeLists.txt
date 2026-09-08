cmake_minimum_required(VERSION 3.20)
project(obs-privacy-capture VERSION 1.0.0 LANGUAGES C CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OBJCXX_STANDARD 17)
set(CMAKE_OBJCXX_STANDARD_REQUIRED ON)

add_compile_options(
    -Wall
    -Wextra
    -Wno-unused-parameter
    -fobjc-arc
)

find_path(SIMDE_INCLUDE_DIR "simde/simde-common.h"
    PATHS /opt/homebrew/include /usr/local/include
)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/deps/libobs
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${SIMDE_INCLUDE_DIR}
)

set(OBS_FRAMEWORKS_DIR "/Applications/OBS.app/Contents/Frameworks")

find_library(LIBOBS_FRAMEWORK libobs
    PATHS ${OBS_FRAMEWORKS_DIR}
    REQUIRED
)

find_library(SCREENCAPTUREKIT_FRAMEWORK ScreenCaptureKit REQUIRED)
find_library(COREMEDIA_FRAMEWORK CoreMedia REQUIRED)
find_library(COREVIDEO_FRAMEWORK CoreVideo REQUIRED)
find_library(IOSURFACE_FRAMEWORK IOSurface REQUIRED)
find_library(APPKIT_FRAMEWORK AppKit REQUIRED)
find_library(COCOA_FRAMEWORK Cocoa REQUIRED)

set(PLUGIN_SOURCES
    src/plugin-main.cpp
    src/privacy_capture.mm
    src/capture_engine.mm
    src/application_manager.mm
    src/filter_manager.mm
    src/stream_manager.mm
    src/settings.cpp
)

add_library(obs-privacy-capture MODULE ${PLUGIN_SOURCES})

target_link_libraries(obs-privacy-capture
    PRIVATE
        ${LIBOBS_FRAMEWORK}
        ${SCREENCAPTUREKIT_FRAMEWORK}
        ${COREMEDIA_FRAMEWORK}
        ${COREVIDEO_FRAMEWORK}
        ${IOSURFACE_FRAMEWORK}
        ${APPKIT_FRAMEWORK}
        ${COCOA_FRAMEWORK}
)

set_target_properties(obs-privacy-capture PROPERTIES
    BUNDLE TRUE
    BUNDLE_EXTENSION "plugin"
    OUTPUT_NAME "obs-privacy-capture"
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/macos/Info.plist"
    MACOSX_BUNDLE_BUNDLE_NAME "obs-privacy-capture"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.antigravity.obs-privacy-capture"
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "@executable_path/../Frameworks"
)

# Bundle resources
add_custom_command(TARGET obs-privacy-capture POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "$<TARGET_BUNDLE_DIR:obs-privacy-capture>/Contents/Resources/locale"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            "${CMAKE_CURRENT_SOURCE_DIR}/data/locale"
            "$<TARGET_BUNDLE_DIR:obs-privacy-capture>/Contents/Resources/locale"
    COMMENT "Copying localization resources to plugin bundle"
)

# Test Targets
enable_testing()

add_executable(settings_tests
    tests/settings_tests.cpp
    src/settings.cpp
)
target_link_libraries(settings_tests PRIVATE ${LIBOBS_FRAMEWORK})
set_target_properties(settings_tests PROPERTIES
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "${OBS_FRAMEWORKS_DIR}"
)
add_test(NAME settings_tests COMMAND settings_tests)

add_executable(application_manager_tests
    tests/application_manager_tests.mm
    src/application_manager.mm
)
target_link_libraries(application_manager_tests
    PRIVATE
        ${SCREENCAPTUREKIT_FRAMEWORK}
        ${COCOA_FRAMEWORK}
)
add_test(NAME application_manager_tests COMMAND application_manager_tests)

add_executable(standalone_capture_poc
    tests/standalone_capture_poc.mm
    src/capture_engine.mm
    src/application_manager.mm
    src/filter_manager.mm
    src/stream_manager.mm
    src/settings.cpp
)
target_link_libraries(standalone_capture_poc
    PRIVATE
        ${LIBOBS_FRAMEWORK}
        ${SCREENCAPTUREKIT_FRAMEWORK}
        ${COREMEDIA_FRAMEWORK}
        ${COREVIDEO_FRAMEWORK}
        ${IOSURFACE_FRAMEWORK}
        ${APPKIT_FRAMEWORK}
        ${COCOA_FRAMEWORK}
)
set_target_properties(standalone_capture_poc PROPERTIES
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "${OBS_FRAMEWORKS_DIR}"
)
add_test(NAME standalone_capture_poc COMMAND standalone_capture_poc)

# Installation rule
set(USER_OBS_PLUGIN_DIR "$ENV{HOME}/Library/Application Support/obs-studio/plugins")
install(TARGETS obs-privacy-capture
    BUNDLE DESTINATION "${USER_OBS_PLUGIN_DIR}"
    LIBRARY DESTINATION "${USER_OBS_PLUGIN_DIR}"
)

add_executable(obs_loader_test
    tests/obs_loader_test.cpp
)
target_link_libraries(obs_loader_test PRIVATE ${LIBOBS_FRAMEWORK})
set_target_properties(obs_loader_test PROPERTIES
    BUILD_WITH_INSTALL_RPATH TRUE
    INSTALL_RPATH "${OBS_FRAMEWORKS_DIR}"
)
add_test(NAME obs_loader_test COMMAND obs_loader_test)
