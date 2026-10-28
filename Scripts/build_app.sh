#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "🍊 Building Tangerine for macOS..."
export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
swift build -c release

APP_NAME="Tangerine.app"
CONTENTS_DIR="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Packaging $APP_NAME..."
rm -rf "$APP_NAME"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
if [ -f ".build/release/TangerineApp" ]; then
    cp ".build/release/TangerineApp" "$MACOS_DIR/Tangerine"
else
    cp ".build/release/Tangerine" "$MACOS_DIR/Tangerine"
fi

# Copy Info.plist
cat << 'EOF' > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Tangerine</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.tangerine.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Tangerine</string>
    <key>CFBundleDisplayName</key>
    <string>Tangerine</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>Tangerine connects with Finder to streamline file actions.</string>
</dict>
</plist>
EOF

# Copy all resources
cp -R Resources/* "$RESOURCES_DIR/"
chmod -R +rx "$RESOURCES_DIR/Tools" 2>/dev/null || true
chmod -R +rx "$RESOURCES_DIR/ExifTool" 2>/dev/null || true

echo "🔏 Signing application with stable identifier requirement..."
codesign --force --deep --sign - --requirements '=designated => identifier "com.tangerine.app"' "$APP_NAME"

echo "✨ Successfully built $APP_NAME!"
ls -ld "$APP_NAME"

echo "🚀 Installing / updating /Applications/Tangerine.app..."
rm -rf /Applications/Tangerine.app
cp -R "$APP_NAME" /Applications/Tangerine.app
echo "✅ /Applications/Tangerine.app is up to date!"
