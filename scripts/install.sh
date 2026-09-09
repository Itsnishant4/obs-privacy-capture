#!/bin/bash
set -e

echo "🛡️ Installing OBS Privacy Capture for macOS..."

# Ensure Xcode command line tools are installed
if ! xcode-select -p &>/dev/null; then
    echo "❌ Xcode Command Line Tools not found. Run 'xcode-select --install' first."
    exit 1
fi

# Ensure CMake is available
if ! command -v cmake &>/dev/null; then
    if command -v brew &>/dev/null; then
        echo "📦 Installing cmake and simde via Homebrew..."
        brew install cmake simde
    else
        echo "❌ CMake not found and Homebrew is not installed. Please install CMake."
        exit 1
    fi
fi

# Build
echo "⚙️ Building plugin with CMake..."
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

# Install to OBS plugins directory
echo "🚀 Installing to OBS Studio plugins folder..."
cmake --install build

# Remove quarantine attribute
PLUGIN_DIR="$HOME/Library/Application Support/obs-studio/plugins/obs-privacy-capture.plugin"
if [ -d "$PLUGIN_DIR" ]; then
    xattr -cr "$PLUGIN_DIR" 2>/dev/null || true
fi

echo "✅ OBS Privacy Capture installed successfully!"
echo "👉 Restart OBS Studio and add 'Privacy Capture' from the Sources list."
