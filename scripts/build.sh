#!/bin/bash
# Builds "TickTick Live.app" into build/. Needs only Xcode Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="TickTick Live"
EXEC="TickTickLive"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"
APP="build/$APP_NAME.app"

echo "▸ Compiling (release)…"
swift build -c release --triple arm64-apple-macosx14.0
swift build -c release --triple x86_64-apple-macosx14.0
BIN_ARM="$(swift build -c release --triple arm64-apple-macosx14.0 --show-bin-path)/$EXEC"
BIN_X86="$(swift build -c release --triple x86_64-apple-macosx14.0 --show-bin-path)/$EXEC"
mkdir -p build
lipo -create "$BIN_ARM" "$BIN_X86" -output "build/$EXEC"
echo "  universal binary: $(lipo -archs "build/$EXEC")"

echo "▸ Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "build/$EXEC" "$APP/Contents/MacOS/$EXEC"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/*.lproj "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ ! -f build/AppIcon.icns ]; then
    echo "▸ Rendering icon"
    rm -rf build/AppIcon.iconset
    swift scripts/make_icon.swift build/AppIcon.iconset >/dev/null
    iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Signing (ad-hoc)"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose=1 "$APP"

echo "✓ Built $APP ($VERSION)"
