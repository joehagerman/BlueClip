#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================================"
echo "    📎 Building & Launching BlueClip for macOS              "
echo "============================================================"

# Check if icons exist, generate if needed
if [ ! -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]; then
    echo "Generating icons..."
    swift "$SCRIPT_DIR/Resources/generate_icons.swift"
    iconutil -c icns "$SCRIPT_DIR/Resources/AppIcon.iconset" -o "$SCRIPT_DIR/Resources/AppIcon.icns"
fi

echo "Compiling BlueClip via Swift Package Manager..."
swift build -c release 2>&1 | xcbeautify

APP_NAME="BlueClip"
BUNDLE_DIR="$SCRIPT_DIR/build/${APP_NAME}.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$SCRIPT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Copy icons and resources
cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/"
cp "$SCRIPT_DIR/Resources/MenuBarIcon.png" "$RESOURCES_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/Resources/MenuBarIcon@2x.png" "$RESOURCES_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/Resources/MenuBarIconBlue.png" "$RESOURCES_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/Resources/MenuBarIconBlue@2x.png" "$RESOURCES_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/Resources/MenuBarIconBadge.png" "$RESOURCES_DIR/" 2>/dev/null || true
cp "$SCRIPT_DIR/Resources/MenuBarIconBadge@2x.png" "$RESOURCES_DIR/" 2>/dev/null || true

# Create Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.blueclip.BlueClip</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

# Strip extended attributes and dot-underscore resource forks
dot_clean -m "$BUNDLE_DIR" 2>/dev/null || true
xattr -cr "$BUNDLE_DIR" 2>/dev/null || true
codesign -s - --force --deep "$BUNDLE_DIR" 2>/dev/null || true

echo "✅ App bundle created at: $BUNDLE_DIR"

if [ "$1" == "--no-launch" ]; then
    echo "Build complete. Not launching (--no-launch specified)."
    exit 0
fi

# Terminate existing instance if running
killall -9 BlueClip 2>/dev/null || true
pkill -f "clipboard_server.py" 2>/dev/null || true
sleep 0.5

# Ensure local zero-dependency sync hub is running on port 8008
echo "Starting background sync hub on port 8008..."
nohup python3 "$SCRIPT_DIR/server/clipboard_server.py" 8008 > /dev/null 2>&1 &
sleep 0.5

echo "🚀 Launching ${APP_NAME}.app..."
open "$BUNDLE_DIR"

echo "✨ BlueClip is now running in your macOS Menu Bar!"
