# Privacy Capture for OBS Studio on macOS

**Privacy Capture** (`privacy_capture`) is an OBS Studio plugin source for macOS (macOS 13 Ventura+) that provides a privacy-aware alternative to normal Display Capture. It captures an entire physical monitor while selectively excluding one or more user-specified applications from the captured video in real-time.

Excluded applications remain completely visible on the physical display for the streamer/user, but are never rendered into OBS's preview, recording, or streaming outputs.

## Features

- **Native ScreenCaptureKit Filtering**: Uses Apple's `SCContentFilter(display:excludingApplications:exceptingWindows:)` directly at the OS compositor level.
- **Zero-Copy GPU Rendering**: Frames are streamed from ScreenCaptureKit as `IOSurface` references directly into OBS GPU textures via `gs_texture_create_from_iosurface` and `gs_texture_rebind_iosurface`, achieving 60 FPS performance with < 5% CPU overhead.
- **Dynamic Application Detection**:
  - Automatically detects when excluded applications launch or terminate via macOS `NSWorkspace` notifications and updates the capture filter on-the-fly without restarting the stream.
  - Periodic low-frequency background validation ensures consistent state.
- **Application Identification by Bundle ID**: Persists applications using stable bundle identifiers (e.g. `com.google.Chrome`, `com.hnc.Discord`, `com.apple.Terminal`) rather than volatile window titles.
- **Source Configuration UI**:
  - Display selector (supports multi-monitor setups and Retina scaling).
  - "Capture Cursor" toggle.
  - "Automatically detect launched/closed apps" toggle.
  - Running applications dropdown picker with one-click "Exclude Selected Application" button.
  - Editable exclusions list with add/remove support.
  - Real-time status display (e.g., `● Active: 3 configured, 2 running`).
- **Fail-Closed Safety Design**: Never reports protected status unless exclusions are actively applied in the capture filter.

## Requirements

- macOS 13.0 (Ventura) or newer
- Apple Silicon or Intel Mac
- OBS Studio 30.0+ (Tested with OBS Studio 32.2.2)
- macOS Screen Recording permissions enabled in System Settings

## Building and Installing

### Prerequisites

- CMake 3.20+
- Clang / Xcode Command Line Tools
- `simde` (`brew install simde`)
- OBS Studio installed in `/Applications/OBS.app`

### Build

```bash
cmake -B build -S .
cmake --build build
```

### Run Tests

```bash
ctest --test-dir build --output-on-failure
```

### Install

Install the plugin bundle into your user OBS plugins folder:

```bash
cmake --install build
```

The plugin will be installed to:
`~/Library/Application Support/obs-studio/plugins/obs-privacy-capture.plugin`

## Usage in OBS Studio

1. Launch OBS Studio.
2. Under **Sources**, click **+** and choose **Privacy Capture**.
3. Select the target monitor in the **Display** dropdown.
4. Select an application to exclude in the **Running Applications** dropdown and click **Exclude Selected Application**, or manually enter bundle IDs in the **Excluded Applications** list.
5. The excluded application will remain visible on your screen, but is completely excluded from OBS Preview, Recording, and Streaming.

## License

GNU General Public License v2.0 or later (GPL-2.0-or-later).
