#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

FLUTTER_DIR="$SCRIPT_DIR/flutter_app"
RELEASE_DIR="$FLUTTER_DIR/build/macos/Build/Products/Release"

echo "==> Building Rust backend (release)..."
cargo build --release

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
cp "target/release/localcast" "$APP_BUNDLE/Contents/Helpers/localcast"

echo "==> Re-signing app bundle..."
ENTITLEMENTS="$FLUTTER_DIR/macos/Runner/Release.entitlements"
# Sign the helper binary first (no entitlements needed for it)
codesign --force --sign - "$APP_BUNDLE/Contents/Helpers/localcast"
# Sign the main app with entitlements preserved
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"

echo ""
echo "Done! App bundle is at:"
echo "  $APP_BUNDLE"
