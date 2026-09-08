<div align="center">

# 🛡️ OBS Privacy Capture for macOS

**Capture full macOS displays while selectively hiding private applications in real-time.**

[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B%20%28Ventura%2B%29-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com)
[![OBS Studio](https://img.shields.io/badge/OBS%20Studio-30.0%2B-302D42?style=for-the-badge&logo=obsstudio&logoColor=white)](https://obsproject.com)
[![ScreenCaptureKit](https://img.shields.io/badge/Engine-Apple%20ScreenCaptureKit-FF9500?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/documentation/screencapturekit)
[![Performance](https://img.shields.io/badge/Rendering-Zero--Copy%20IOSurface-34C759?style=for-the-badge&logo=speedtest&logoColor=white)](#performance--architecture)
[![License](https://img.shields.io/badge/License-GPL%20v2.0-blue?style=for-the-badge)](LICENSE)
[![Buy Me A Coffee](https://img.shields.io/badge/Support-Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/Nishant4)

<br/>

```
  PHYSICAL MAC MONITOR                           OBS CAPTURED OUTPUT
┌───────────────────────────────┐               ┌───────────────────────────────┐
│  🌐 Google Chrome             │               │  🌐 Google Chrome             │
│  💻 Visual Studio Code        │               │  💻 Visual Studio Code        │
│  💬 Discord                   │    ──────►    │                               │
│  📟 Terminal                  │               │                               │
│  🔑 1Password                 │               │                               │
└───────────────────────────────┘               └───────────────────────────────┘
      (Visible to Streamer)                            (Safe for Stream)
                                            Discord, Terminal & 1Password excluded!
```

</div>

---

## 🌟 Overview

**Privacy Capture** (`privacy_capture`) is a native OBS Studio plugin for macOS that solves the long-standing privacy problem for streamers and creators: **"Capture everything on my display EXCEPT these sensitive apps."**

Instead of capturing the screen and attempting to blur or mask pixels after the fact, Privacy Capture leverages Apple's OS-level **ScreenCaptureKit** compositor filter (`SCContentFilter`). The operating system itself removes the excluded applications before the video frames ever reach OBS.

> 🔒 **Streamer View vs. Viewer View**: Excluded applications remain completely visible and usable on your physical Mac monitor, but are completely absent from OBS Studio's preview, video recordings, and live streams.

---

## ✨ Key Features

| Feature | Description |
| :--- | :--- |
| **🛡️ Native OS Filtering** | Powered by Apple's `SCContentFilter(display:excludingApplications:exceptingWindows:)` directly inside macOS WindowServer. |
| **⚡ Zero-Copy Hardware Pipeline** | Direct `CVPixelBuffer` ➔ `IOSurface` ➔ `gs_texture_create_from_iosurface` GPU binding. Direct hardware texturing with **< 5% CPU usage at 1080p60 / 4K60**. |
| **🔄 Dynamic App Detection** | Subscribes to `NSWorkspace` app lifecycle notifications. When an excluded app launches or quits, the capture filter updates instantly without restarting the stream. |
| **🎯 Stable Bundle Identifiers** | Persists exclusions using canonical macOS bundle IDs (e.g. `com.hnc.Discord`, `com.google.Chrome`, `com.apple.Terminal`) rather than brittle window titles. |
| **🎛️ Native OBS Properties UI** | Includes a monitor selector, running applications dropdown picker with 1-click **Exclude**, and an editable exclusions list. |
| **🖥️ Multi-Display & Retina** | Full support for Retina 2x scaling, Display P3 wide color gamut, and multiple active monitors. |
| **🔒 Fail-Closed Security** | The status indicator only reports active protection if the application is verified to be in the active filter. |

---

## 🏗️ Architecture & Pipeline

```
 ┌──────────────────────────────────────────────────────────┐
 │                  macOS WindowServer                      │
 │    ScreenCaptureKit Engine (SCShareableContent)          │
 └────────────────────────────┬─────────────────────────────┘
                              │ Filtered CMSampleBuffer
                              ▼
 ┌──────────────────────────────────────────────────────────┐
 │                   StreamManager (ObjC++)                 │
 │       Extracts CVPixelBuffer & IOSurfaceRef              │
 └────────────────────────────┬─────────────────────────────┘
                              │ Zero-Copy Surface Handoff
                              ▼
 ┌──────────────────────────────────────────────────────────┐
 │                   CaptureEngine (ObjC++)                 │
 │  • Coordinates ApplicationManager & FilterManager        │
 │  • Listens to NSWorkspace lifecycle notifications        │
 │  • Calls [SCStream updateContentFilter:...] dynamically  │
 └────────────────────────────┬─────────────────────────────┘
                              │
 ┌────────────────────────────┴─────────────────────────────┐
 │               Privacy Capture OBS Source                 │
 │                (obs_source_info, C++/ObjC)               │
 ├──────────────────────────────────────────────────────────┤
 │ • video_tick:   Binds/rebinds IOSurface into gs_texture  │
 │ • video_render: Draws sprite via OBS DrawD65P3 shader    │
 │ • properties:   Display, App picker, Excluded List, State│
 └────────────────────────────┬─────────────────────────────┘
                              │ Filtered Frame
                              ▼
             OBS Compositor (Preview / Record / Stream)
```

---

## 📋 System Requirements

- **Operating System**: macOS 13.0 (Ventura), macOS 14 (Sonoma), macOS 15 (Sequoia), or newer.
- **Hardware**: Apple Silicon (M1/M2/M3/M4) or Intel Mac running supported macOS.
- **OBS Studio**: OBS Studio 30.0 or later (Fully tested on **OBS Studio 32.2.2**).
- **Permissions**: Screen Recording permission enabled for OBS Studio in `System Settings > Privacy & Security > Screen Recording`.

---

## 🚀 Installation & Quick Start

### Option 1: Automatic Build & Install from Source

Ensure you have [Homebrew](https://brew.sh) and CMake installed:

```bash
# 1. Install dependencies
brew install cmake simde

# 2. Clone repository
git clone https://github.com/Itsnishant4/obs-privacy-capture.git
cd obs-privacy-capture

# 3. Configure and build
cmake -B build -S .
cmake --build build

# 4. Install plugin into OBS
cmake --install build
```

The plugin bundle will be installed directly to:
```
~/Library/Application Support/obs-studio/plugins/obs-privacy-capture.plugin
```

---

## 🎥 Using Privacy Capture in OBS Studio

1. Launch **OBS Studio**.
2. In the **Sources** dock, click the **`+`** (Add Source) button.
3. Select **Privacy Capture** from the list of available sources.
4. In the properties dialog:
   - **Display**: Select your physical display.
   - **Running Applications**: Choose an application you want to hide (e.g. *Discord*, *Terminal*, *Chrome*, *1Password*).
   - Click **`Exclude Selected Application`**.
   - The application's bundle identifier is added to the **Excluded Applications** list.
5. The application is now invisible in your OBS Preview, recorded videos, and live broadcasts, but remains fully visible on your monitor!

---

## 🧪 Testing & Verification

The project comes with a comprehensive test suite covering serialization, application resolution, standalone capture POC, and OBS module loading:

```bash
ctest --test-dir build --output-on-failure
```

```
Test project /path/to/build
    Start 1: settings_tests
1/4 Test #1: settings_tests ...................   Passed    0.01 sec
    Start 2: application_manager_tests
2/4 Test #2: application_manager_tests ........   Passed    0.04 sec
    Start 3: standalone_capture_poc
3/4 Test #3: standalone_capture_poc ...........   Passed    0.49 sec
    Start 4: obs_loader_test
4/4 Test #4: obs_loader_test ..................   Passed    0.16 sec

100% tests passed out of 4!
```

---

## ☕ Support & Sponsor

If you find this plugin helpful for your streaming setup or workflow, consider buying me a coffee!

<p align="left">
  <a href="https://www.buymeacoffee.com/Nishant4" target="_blank">
    <img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=%E2%98%95&slug=Nishant4&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" alt="Buy Me A Coffee" />
  </a>
</p>

---

## 👨‍💻 Author & Credits

Developed with ❤️ by:

### **Nishant Patel**
- **GitHub**: [@Itsnishant4](https://github.com/Itsnishant4)
- **Buy Me a Coffee**: [buymeacoffee.com/Nishant4](https://www.buymeacoffee.com/Nishant4)
- **Project**: Privacy Capture for OBS Studio on macOS

*Special thanks to the OBS Project team and Apple ScreenCaptureKit engineers for providing the underlying compositing and graphics frameworks.*

---

## 📄 License

This project is licensed under the **GNU General Public License v2.0 or later** ([GPL-2.0-or-later](LICENSE)) in alignment with OBS Studio's plugin licensing.
