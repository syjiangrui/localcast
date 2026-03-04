#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

FLUTTER_DIR="$SCRIPT_DIR/flutter_app"
RELEASE_DIR="$FLUTTER_DIR/build/macos/Build/Products/Release"

echo "==> Building Rust backend (universal binary)..."
# Ensure the x86_64 target is installed
rustup target add x86_64-apple-darwin 2>/dev/null || true
# Build for both architectures
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin
# Merge into a universal binary
mkdir -p target/universal-release
lipo -create \
  target/aarch64-apple-darwin/release/localcast \
  target/x86_64-apple-darwin/release/localcast \
  -output target/universal-release/localcast

echo "==> Building Flutter macOS app (release)..."
cd "$FLUTTER_DIR"
flutter build macos --release
cd "$SCRIPT_DIR"

# Auto-detect the .app bundle name
APP_BUNDLE="$(find "$RELEASE_DIR" -maxdepth 1 -name '*.app' -type d | head -1)"
if [ -z "$APP_BUNDLE" ]; then
  echo "ERROR: No .app bundle found in $RELEASE_DIR" >&2
  exit 1
fi

echo "==> Embedding backend binary into $(basename "$APP_BUNDLE")..."
mkdir -p "$APP_BUNDLE/Contents/Helpers"
cp "target/universal-release/localcast" "$APP_BUNDLE/Contents/Helpers/localcast"

echo "==> Re-signing app bundle..."
ENTITLEMENTS="$FLUTTER_DIR/macos/Runner/Release.entitlements"
# Sign the helper binary first (no entitlements needed for it)
codesign --force --sign - "$APP_BUNDLE/Contents/Helpers/localcast"
# Sign the main app with entitlements preserved
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"

APP_NAME="$(basename "$APP_BUNDLE" .app)"
DMG_STAGING="$SCRIPT_DIR/build_dmg_staging"
DMG_OUT="$SCRIPT_DIR/${APP_NAME}.dmg"

echo "==> Creating DMG..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_OUT"

rm -rf "$DMG_STAGING"

echo ""
echo "Done!"
echo "  App bundle : $APP_BUNDLE"
echo "  DMG        : $DMG_OUT"
