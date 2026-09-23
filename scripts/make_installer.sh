#!/bin/bash
# Builds the app and packs two installers into dist/:
#   Dictate-for-TickTick.dmg — drag the app into Applications
#   Dictate-for-TickTick.pkg — classic installer wizard, installs into /Applications
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
export VERSION
APP_NAME="Dictate for TickTick"
APP="build/$APP_NAME.app"

./scripts/build.sh

mkdir -p dist
# Stable names: README links to releases/latest/download/<name>, which must not change between versions.
DMG="dist/Dictate-for-TickTick.dmg"
PKG="dist/Dictate-for-TickTick.pkg"

echo "▸ Creating DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp scripts/installer/README.txt "$STAGE/Прочти меня — Read me.txt"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$STAGE"

echo "▸ Creating PKG"
PKGROOT="$(mktemp -d)"
mkdir -p "$PKGROOT/Applications"
cp -R "$APP" "$PKGROOT/Applications/"
COMPONENT_PLIST="$(mktemp).plist"
pkgbuild --analyze --root "$PKGROOT" "$COMPONENT_PLIST" >/dev/null
# Always install into /Applications, even if a copy of the app exists elsewhere.
/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$COMPONENT_PLIST"
pkgbuild --root "$PKGROOT" --component-plist "$COMPONENT_PLIST" --identifier app.dictate-for-ticktick \
    --version "$VERSION" --scripts scripts/installer/pkg-scripts --install-location / build/component.pkg >/dev/null
productbuild --distribution scripts/installer/distribution.xml --resources scripts/installer/resources \
    --package-path build "$PKG" >/dev/null
rm -rf "$PKGROOT" "$COMPONENT_PLIST" build/component.pkg

echo "✓ $DMG"
echo "✓ $PKG"
