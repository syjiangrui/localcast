#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="LocalCast"
APP_VERSION="0.1.0"
BUNDLE_ID="com.localcast.app"

echo "==> Building ${APP_NAME} for macOS..."
cargo build --release

echo ""
echo "==> Creating .app bundle..."

APP_DIR="target/release/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Clean up old bundle if exists
rm -rf "${APP_DIR}"

# Create directory structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
echo "  - Copying binary..."
cp "target/release/localcast" "${MACOS_DIR}/${APP_NAME}-bin"

# Create launcher script
echo "  - Creating launcher script..."
cat > "${MACOS_DIR}/${APP_NAME}" << 'LAUNCHER_EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
exec ./LocalCast-bin "$@"
LAUNCHER_EOF

chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy icon
echo "  - Copying icon..."
if [ -f "assets/icon/LocalCast.icns" ]; then
    cp "assets/icon/LocalCast.icns" "${RESOURCES_DIR}/"
else
    echo "    Warning: Icon file not found at assets/icon/LocalCast.icns"
fi

# Create Info.plist
echo "  - Creating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>LocalCast</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.13</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo ""
echo "==> Signing the app (ad-hoc)..."
codesign --force --deep --sign - "${APP_DIR}" 2>/dev/null || echo "  Warning: Code signing failed (non-fatal)"

echo ""
echo "==> Creating DMG installer..."
DMG_NAME="${APP_NAME}-${APP_VERSION}-macOS"
DMG_PATH="target/release/${DMG_NAME}.dmg"

# Remove old DMG if exists
rm -f "${DMG_PATH}"

# Create temporary directory for DMG contents
DMG_TEMP_DIR="target/release/dmg_temp"
rm -rf "${DMG_TEMP_DIR}"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app to temp directory
cp -R "${APP_DIR}" "${DMG_TEMP_DIR}/"

# Create symbolic link to Applications folder
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create DMG
echo "  - Creating disk image..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${DMG_PATH}"

# Clean up temp directory
rm -rf "${DMG_TEMP_DIR}"

echo ""
echo "✅ Build complete!"
echo ""
echo "macOS App Bundle:"
echo "  ${APP_DIR}"
echo ""
echo "DMG Installer:"
echo "  ${DMG_PATH}"
echo ""
echo "To install: Open the DMG and drag ${APP_NAME}.app to Applications"
