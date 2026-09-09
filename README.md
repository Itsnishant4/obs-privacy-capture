<div align="center">

# 🛡️ OBS Privacy Capture for macOS

**Capture full macOS displays while selectively hiding private applications in real-time.**

[![Platform](https://img.shields.io/badge/Platform-macOS%2013%2B%20%28Ventura%2B%29-007AFF?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com)
[![OBS Studio](https://img.shields.io/badge/OBS%20Studio-30.0%2B-302D42?style=for-the-badge&logo=obsstudio&logoColor=white)](https://obsproject.com)
[![ScreenCaptureKit](https://img.shields.io/badge/Engine-Apple%20ScreenCaptureKit-FF9500?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/documentation/screencapturekit)
[![Performance](https://img.shields.io/badge/Rendering-Zero--Copy%20IOSurface-34C759?style=for-the-badge&logo=speedtest&logoColor=white)](#-architecture--hardware-pipeline)
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

<br/>

<a href="https://www.buymeacoffee.com/Nishant4" target="_blank">
  <img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=%E2%98%95&slug=Nishant4&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" alt="Buy Me A Coffee" height="42" />
</a>

</div>

---

## 📑 Table of Contents

- [🌟 Overview](#-overview)
- [✨ Key Features](#-key-features)
- [🎛️ Source Properties UI](#️-source-properties-ui)
- [⌨️ Universal Hotkeys (Instant Hide From Any App)](#️-universal-hotkeys-instant-hide-from-any-app)
- [🏗️ Architecture & Hardware Pipeline](#️-architecture--hardware-pipeline)
- [📋 System Requirements](#-system-requirements)
- [🚀 Quick Start & Installation](#-quick-start--installation)
- [🎥 Using Privacy Capture in OBS Studio](#-using-privacy-capture-in-obs-studio)
- [❓ Frequently Asked Questions (FAQ)](#-frequently-asked-questions-faq)
- [🧪 Testing & Verification](#-testing--verification)
- [☕ Support the Project](#-support-the-project)
- [👨‍💻 Author & Credits](#-author--credits)
- [📄 License](#-license)

---

## 🌟 Overview

**Privacy Capture** (`privacy_capture`) is a high-performance native OBS Studio plugin for macOS that solves the long-standing privacy challenge for streamers, developers, educators, and creators: **"Capture my entire monitor, but exclude specific sensitive applications."**

### The Problem
Normal Display Capture broadcasts *everything* on your screen. If a private chat pops up on Discord, sensitive tokens appear in your Terminal, or you need to unlock 1Password, your viewers see it unless you quickly scramble to minimize windows, drag them off-screen, or switch scenes.

### The Solution
Instead of capturing the full screen and attempting to blur or mask pixels after the fact, **Privacy Capture leverages Apple's OS-level ScreenCaptureKit compositor** (`SCContentFilter`). macOS WindowServer itself removes the excluded applications before the video frames ever enter OBS Studio.

> 🔒 **Streamer View vs. Viewer View**: Excluded applications remain completely visible and interactive on your physical monitor, but are 100% invisible in OBS Preview, recordings, and live broadcasts!

---

## ✨ Key Features

| Feature | Description |
| :--- | :--- |
| **🛡️ Dual Capture Modes** | **Exclude Mode (Blacklist)**: Hide sensitive apps from your screen.<br/>**Include Workspace Mode (Whitelist)**: Capture *only* selected apps on screen—ideal for multi-desktop (macOS Spaces) workflows! |
| **🛡️ Native OS-Level Filtering** | Powered by Apple's `SCContentFilter(display:excludingApplications:exceptingWindows:)` and `initWithDisplay:includingApplications:exceptingWindows:` directly inside macOS WindowServer. |
| **⚡ Zero-Copy Hardware Pipeline** | Direct `CVPixelBuffer` ➔ `IOSurface` ➔ `gs_texture_create_from_iosurface` GPU binding. Direct hardware texturing with **< 5% CPU overhead at 1080p60 / 4K60**. |
| **⌨️ Universal Hotkey System** | Press a global keyboard shortcut while inside **any focused application** to instantly hide or toggle it from your live stream. |
| **🔄 Real-Time Dynamic Detection** | Subscribes to `NSWorkspace` application lifecycle notifications. When an excluded app opens or closes, the capture filter updates seamlessly without stream restarts or dropped frames. |
| **🎯 Stable Bundle Identifiers** | Persists exclusions using canonical macOS bundle IDs (e.g. `com.hnc.Discord`, `com.google.Chrome`, `com.apple.Terminal`) rather than fragile window titles. |
| **🎛️ Native OBS Properties UI** | Includes mode selector, monitor selector, running applications dropdown picker with 1-click **Add**, and an editable filter list. |
| **🖥️ Multi-Display & Retina Scaling** | Full native support for Retina 2x scaling, Display P3 wide color gamut, and multi-monitor setups. |
| **🔒 Fail-Closed Privacy Guarantee** | The status indicator only reports active protection when the application is verified to be actively filtered by macOS. |

---

## 🎛️ Source Properties UI

Privacy Capture provides an intuitive, native property inspector right inside OBS Studio:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ Privacy Capture Properties                                             │
├────────────────────────────────────────────────────────────────────────┤
│ Display               [ Built-in Retina Display (1920x1080)        ▼ ] │
│ Capture Mode          [ Include Workspace Mode (Capture ONLY)      ▼ ] │
│                         • Exclude Mode (Hide selected apps)            │
│                         • Include Workspace Mode (Capture ONLY)        │
│ ☑ Capture Cursor                                                       │
│ ☑ Automatically detect launched/closed apps                            │
│                                                                        │
│ Running Applications  [ Google Chrome (com.google.Chrome)          ▼ ] │
│                       [ Add Selected Application to Filter ]           │
│                                                                        │
│ Active Filter List (Bundle IDs):                                       │
│ ┌────────────────────────────────────────────────────────────────────┐ │
│ │ com.google.Chrome                                                  │ │
│ │ com.microsoft.VSCode                                               │ │
│ └────────────────────────────────────────────────────────────────────┘ │
│                       [ Refresh Applications ]                         │
│                                                                        │
│ Status: ● Include Workspace: 2 configured, 2 running (Chrome, VSCode)  │
└────────────────────────────────────────────────────────────────────────┘
```

### 🖥️ Working with macOS Virtual Desktops (Spaces)
When you have multiple desktops in Mission Control (Desktop 1, 2, 3, 4) on your Mac:
- Switch **Capture Mode** to **Include Workspace Mode**.
- Add the applications that belong to your stream workspace (e.g., *Google Chrome* and *VS Code*).
- **Benefit**: You can 3-finger swipe across Desktops 1, 2, 3, and 4 on your Mac to check emails, Slack, or Discord—**OBS will only ever render the included apps**. Any other application or private desktop you switch to remains 100% invisible to viewers!

---

## ⌨️ Universal Hotkeys (Instant Hide From Any App)

Privacy Capture registers global system hotkeys through OBS Studio, allowing you to exclude whatever app you are currently looking at on your Mac **without needing to switch windows or open OBS**:

| Hotkey Action | Behavior |
| :--- | :--- |
| **Toggle Exclude Active Application** | Focus any window (e.g. *Discord*, *WhatsApp*, *VS Code*, *Browser*) and press your shortcut. If it is visible, it immediately disappears from the stream; press again to show it. Plays a subtle audio confirmation chime (`NSBeep`). |
| **Exclude Active Application** | One-touch panic hide: immediately adds the active frontmost application to your exclusion filter. |
| **Clear All Excluded Applications** | Instantly clears all excluded applications, restoring full monitor capture. |

### How to Configure Hotkeys:
1. Open **OBS Studio** > **Settings** (or press `⌘ + ,`).
2. Select **Hotkeys** in the left sidebar.
3. Search for **Privacy Capture** (or scroll to your Privacy Capture source).
4. Assign your preferred key combinations (for example: `⌥ + ⌘ + H` for *Toggle Active*, or `⌃ + ⌥ + P` for *Exclude Active*).
5. Click **Apply** / **OK**. Now, whenever you are working in any application on macOS, tap your hotkey to instantly protect your privacy on stream!

---

## 🏗️ Architecture & Hardware Pipeline

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
 │ • hotkeys:      Universal active app exclude & toggle    │
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

## 🚀 Quick Start & Installation

### Option 1: Automatic 1-Step Installation Script

Run this command in Terminal to build and install the plugin automatically:

```bash
git clone https://github.com/Itsnishant4/obs-privacy-capture.git
cd obs-privacy-capture
./scripts/install.sh
```

### Option 2: Manual Build & Install from Source

```bash
# 1. Install build tools and dependencies
brew install cmake simde

# 2. Clone repository
git clone https://github.com/Itsnishant4/obs-privacy-capture.git
cd obs-privacy-capture

# 3. Configure and build
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

# 4. Install plugin into OBS
cmake --install build

# 5. Clear quarantine attributes (if needed)
xattr -cr "$HOME/Library/Application Support/obs-studio/plugins/obs-privacy-capture.plugin"
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

## ❓ Frequently Asked Questions (FAQ)

<details>
<summary><b>Why is the excluded app still visible on my screen?</b></summary>
That is the intended design! Privacy Capture filters the video stream captured by OBS, not your physical screen. You can continue reading private notes, typing passwords, or chatting with friends while your viewers see whatever content is behind that window.
</details>

<details>
<summary><b>Does this plugin mute or hide application audio?</b></summary>
Privacy Capture focuses exclusively on video filtering. If you want to capture or mute specific application audio, use OBS Studio's built-in <b>Application Audio Capture (macOS)</b> source.
</details>

<details>
<summary><b>What happens if I close an excluded application and reopen it later?</b></summary>
Privacy Capture remembers all configured bundle identifiers. When an excluded application is relaunched, the plugin automatically detects it and reapplies the exclusion filter instantly without requiring any action.
</details>

<details>
<summary><b>What should I do if OBS shows "Permission Required"?</b></summary>
Open <b>System Settings > Privacy & Security > Screen Recording</b> and ensure that OBS Studio has toggle enabled. Restart OBS after enabling permission.
</details>

---

## 🧪 Testing & Verification

The project comes with a comprehensive automated test suite covering serialization, application resolution, standalone capture POC, and OBS module loading:

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

<br/>

<div align="center">

<!-- STANDOUT SPONSOR CARD -->
<table border="0" cellpadding="0" cellspacing="0">
  <tr>
    <td align="center" width="720">
      <br/>
      <h2>☕ Support the Project</h2>
      <p>
        Building and maintaining a native macOS ScreenCaptureKit plugin requires extensive testing and maintenance across macOS versions.
        <br/>
        If <b>Privacy Capture</b> saved your stream or recordings from accidental leaks of private messages, code, or personal data, consider showing your support!
      </p>
      <br/>
      <a href="https://www.buymeacoffee.com/Nishant4" target="_blank">
        <img src="https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=%E2%98%95&slug=Nishant4&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff" alt="Buy Me A Coffee" height="54" />
      </a>
      <br/><br/>
      <p>
        <sub>⭐ Every coffee fuels new features, bug fixes, and ongoing macOS updates! ⭐</sub>
      </p>
      <br/>
    </td>
  </tr>
</table>

<br/><br/>

<!-- STANDOUT CREATOR CARD -->
<table border="0" cellpadding="0" cellspacing="0">
  <tr>
    <td align="center" width="720">
      <br/>
      <h2>👨‍💻 Author & Lead Developer</h2>
      <br/>
      <img src="https://github.com/Itsnishant4.png" width="90" height="90" style="border-radius: 50%;" alt="Nishant Patel" />
      <h3>Nishant Patel</h3>
      <p><i>Creator & Maintainer of Privacy Capture for OBS on macOS</i></p>
      <p>
        <a href="https://github.com/Itsnishant4">
          <img src="https://img.shields.io/badge/GitHub-Itsnishant4-181717?style=for-the-badge&logo=github&logoColor=white" alt="GitHub Profile" />
        </a>
        &nbsp;&nbsp;
        <a href="https://www.buymeacoffee.com/Nishant4" target="_blank">
          <img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Nishant4-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Support on BMC" />
        </a>
      </p>
      <p><sub>Special thanks to the OBS Project team and Apple ScreenCaptureKit engineers.</sub></p>
      <br/>
    </td>
  </tr>
</table>

<br/>

</div>

---

## 📄 License

This project is licensed under the **GNU General Public License v2.0 or later** ([GPL-2.0-or-later](LICENSE)) in alignment with OBS Studio's plugin licensing.
