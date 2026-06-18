#!/bin/bash
set -e

echo "=== Packaging OnlyOneFriend ==="

# Clean previous build
rm -rf OnlyOneFriend.app
rm -f OnlyOneFriend
rm -f onlyOneFriend_v0.1.dmg

# Compile Swift file
echo "Compiling main.swift..."
swiftc main.swift -o OnlyOneFriend

# Create App Bundle structure
echo "Creating .app directory structure..."
mkdir -p OnlyOneFriend.app/Contents/MacOS
mkdir -p OnlyOneFriend.app/Contents/Resources

# Copy AppIcon.icns if it exists
if [ -f AppIcon.icns ]; then
    echo "Copying AppIcon.icns..."
    cp AppIcon.icns OnlyOneFriend.app/Contents/Resources/
else
    echo "Warning: AppIcon.icns not found, AppIcon will not be displayed."
fi

# Move executable
mv OnlyOneFriend OnlyOneFriend.app/Contents/MacOS/

# Create Info.plist
echo "Creating Info.plist..."
cat <<EOF > OnlyOneFriend.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>OnlyOneFriend</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.tanbinhasann.onlyonefriend</string>
    <key>CFBundleName</key>
    <string>OnlyOneFriend</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>We need microphone access to record audio messages.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 tanbinhasann. All rights reserved.</string>
</dict>
</plist>
EOF

echo "OnlyOneFriend.app packaged successfully!"

echo "=== Packaging DMG Installer ==="
# Create temporary staging directory
mkdir -p DmgTemp
cp -R OnlyOneFriend.app DmgTemp/
ln -s /Applications DmgTemp/Applications

# Build DMG using hdiutil
hdiutil create -volname "OnlyOneFriend" -srcfolder DmgTemp -ov -format UDZO onlyOneFriend_v0.1.dmg
rm -rf DmgTemp

echo "DMG Installer created at: onlyOneFriend_v0.1.dmg"
