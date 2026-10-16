#!/usr/bin/env bash
# Builds build/WordLock.app (and build/WordLock.dmg with --dmg).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD="$ROOT/build"
APP="$BUILD/WordLock.app"
VERSION="$(cat VERSION)"
# Sign with a real identity if one is given, e.g. SIGN_IDENTITY="Developer ID Application: ..."
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

echo "==> Compiling (release)"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/WordLock"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WordLock"
strip -x "$APP/Contents/MacOS/WordLock"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"

ICONSET="$BUILD/AppIcon.iconset"
if [[ ! -f "$BUILD/AppIcon.icns" ]]; then
  echo "==> Rendering app icon"
  rm -rf "$ICONSET" && mkdir -p "$ICONSET"
  swift scripts/make-icon.swift "$BUILD/icon_1024.png"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$BUILD/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$BUILD/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$BUILD/AppIcon.icns"
fi
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> Signing ($SIGN_IDENTITY)"
codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"

if [[ "${1:-}" == "--dmg" ]]; then
  echo "==> Creating DMG"
  STAGE="$BUILD/dmg"
  rm -rf "$STAGE" "$BUILD/WordLock.dmg" && mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "WordLock" -srcfolder "$STAGE" -ov -format UDZO "$BUILD/WordLock.dmg" >/dev/null
  rm -rf "$STAGE"
  echo "Built $BUILD/WordLock.dmg"
fi

echo "Built $APP"
