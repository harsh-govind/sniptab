#!/bin/zsh
# Builds SnipTab.app next to this script.
set -e
cd "$(dirname "$0")"
VERSION=${VERSION:-1.0}
rm -rf SnipTab.app
mkdir -p SnipTab.app/Contents/MacOS SnipTab.app/Contents/Resources
swiftc -O -swift-version 5 main.swift -o SnipTab.app/Contents/MacOS/SnipTab -framework Cocoa
swift make_icon.swift scissors FF8A4C E5395B SnipTab.app/Contents/Resources/AppIcon.icns
cat > SnipTab.app/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>SnipTab</string>
  <key>CFBundleDisplayName</key><string>SnipTab</string>
  <key>CFBundleIdentifier</key><string>local.sniptab</string>
  <key>CFBundleExecutable</key><string>SnipTab</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF
# Sign with a stable identity (bundle id) instead of the per-build hash, so macOS
# keeps the Screen Recording permission across rebuilds.
codesign --force --sign - -r='designated => identifier "local.sniptab"' SnipTab.app
echo "Built $(pwd)/SnipTab.app"
