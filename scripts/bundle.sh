#!/bin/bash
# bundle.sh — Build Key.app and install to /Applications
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Key"
APP_BUNDLE="/Applications/${APP_NAME}.app"
BUILD_DIR="${PROJECT_DIR}/.build/release"

echo "[Key] Building release..."
cd "$PROJECT_DIR"
swift build -c release

echo "[Key] Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy App Icon
cp "$PROJECT_DIR/assets/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

# Copy resource bundle
if [ -d "$BUILD_DIR/Key_Key.bundle" ]; then
    cp -R "$BUILD_DIR/Key_Key.bundle" "$APP_BUNDLE/Contents/Resources/"
fi

# Generate Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Key</string>
    <key>CFBundleDisplayName</key>
    <string>Key</string>
    <key>CFBundleIdentifier</key>
    <string>io.laststance.key</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleExecutable</key>
    <string>Key</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "[Key] Installed to $APP_BUNDLE"
echo "[Key] Launch with: open /Applications/Key.app"
