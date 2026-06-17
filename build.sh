#!/bin/bash
set -e

WORKSPACE_DIR="/Users/anshul/Documents/Clutch"
BUILD_DIR="$WORKSPACE_DIR/build"
APP_DIR="$BUILD_DIR/Clutch.app"
DIST_DIR="$WORKSPACE_DIR/dist"

echo "=== Cleaning previous builds ==="
rm -rf "$BUILD_DIR"
rm -rf "$DIST_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$DIST_DIR"

echo "=== Building executable via SPM ==="
swift build -c release

echo "=== Copying binary ==="
cp "$WORKSPACE_DIR/.build/release/Clutch" "$APP_DIR/Contents/MacOS/Clutch"

echo "=== Copying SPM Resources ==="
cp -R "$WORKSPACE_DIR/.build/release/"*.bundle "$APP_DIR/Contents/Resources/" 2>/dev/null || true

echo "=== Generating Info.plist ==="
cat <<EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Clutch</string>
	<key>CFBundleIdentifier</key>
	<string>com.clutch.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Clutch</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<false/>
	</dict>
	<key>NSUserNotificationAlertStyle</key>
	<string>alert</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>Clutch needs microphone access to mute your mic during calls when headphones disconnect, preventing audio leaks.</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon.icns</string>
</dict>
</plist>
EOF

echo "=== Generating AppIcon.icns ==="
SRC_ICON="$WORKSPACE_DIR/Clutch/Resources/Assets.xcassets/AppIcon.appiconset/icon.png"
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

sips -s format png -z 16 16     "$SRC_ICON" --out "$ICONSET/icon_16x16.png" > /dev/null
sips -s format png -z 32 32     "$SRC_ICON" --out "$ICONSET/icon_16x16@2x.png" > /dev/null
sips -s format png -z 32 32     "$SRC_ICON" --out "$ICONSET/icon_32x32.png" > /dev/null
sips -s format png -z 64 64     "$SRC_ICON" --out "$ICONSET/icon_32x32@2x.png" > /dev/null
sips -s format png -z 128 128   "$SRC_ICON" --out "$ICONSET/icon_128x128.png" > /dev/null
sips -s format png -z 256 256   "$SRC_ICON" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -s format png -z 256 256   "$SRC_ICON" --out "$ICONSET/icon_256x256.png" > /dev/null
sips -s format png -z 512 512   "$SRC_ICON" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -s format png -z 512 512   "$SRC_ICON" --out "$ICONSET/icon_512x512.png" > /dev/null
sips -s format png -z 1024 1024 "$SRC_ICON" --out "$ICONSET/icon_512x512@2x.png" > /dev/null

iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "=== Generating MenuBarIcon ==="
cp "$WORKSPACE_DIR/Clutch/Resources/menubar.png" "$APP_DIR/Contents/Resources/menubar.png"
cp "$WORKSPACE_DIR/Clutch/Resources/menubar@2x.png" "$APP_DIR/Contents/Resources/menubar@2x.png"

echo "=== Copying audio assets ==="
cp "$WORKSPACE_DIR/Clutch/Resources/Sounds/clutch_save.aiff" "$APP_DIR/Contents/Resources/clutch_save.aiff"
echo "=== Signing App ==="
codesign --force --deep --sign - "$APP_DIR"

echo "=== Packaging into DMG ==="
/opt/homebrew/bin/create-dmg \
  --volname "Clutch" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 128 \
  --icon "Clutch.app" 150 200 \
  --app-drop-link 450 200 \
  "$DIST_DIR/Clutch.dmg" \
  "$BUILD_DIR/Clutch.app"

echo "=== DMG successfully generated at $DIST_DIR/Clutch.dmg ==="
ls -lh "$DIST_DIR/Clutch.dmg"
