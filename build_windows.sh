#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="LocalCast"
APP_VERSION="0.1.0"

echo "==> Building ${APP_NAME} for Windows (x86_64)..."
echo ""

# Check if Windows target is installed
if ! rustup target list | grep -q "x86_64-pc-windows-gnu (installed)"; then
    echo "Windows target not found. Installing..."
    rustup target add x86_64-pc-windows-gnu
    echo ""
fi

# Check if mingw-w64 is installed (needed for cross-compilation)
if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
    echo "❌ Error: mingw-w64 is not installed."
    echo ""
    echo "To install on macOS:"
    echo "  brew install mingw-w64"
    echo ""
    exit 1
fi

echo "Building Windows executable..."
cargo build --release --target x86_64-pc-windows-gnu

if [ $? -eq 0 ]; then
    echo ""
    echo "==> Creating Windows distribution package..."

    DIST_DIR="target/release/windows_dist"
    rm -rf "${DIST_DIR}"
    mkdir -p "${DIST_DIR}/${APP_NAME}"

    # Copy executable
    echo "  - Copying executable..."
    cp "target/x86_64-pc-windows-gnu/release/localcast.exe" "${DIST_DIR}/${APP_NAME}/${APP_NAME}.exe"

    # Copy icon (optional, for reference)
    if [ -d "assets/icon" ]; then
        echo "  - Copying icons..."
        mkdir -p "${DIST_DIR}/${APP_NAME}/icons"
        cp assets/icon/*.png "${DIST_DIR}/${APP_NAME}/icons/" 2>/dev/null || true
    fi

    # Create README
    echo "  - Creating README..."
    cat > "${DIST_DIR}/${APP_NAME}/README.txt" << EOF
${APP_NAME} v${APP_VERSION} for Windows

Installation:
1. Extract all files to a folder of your choice
2. Run ${APP_NAME}.exe

Requirements:
- Windows 10 or later
- Network connection for DLNA device discovery

Usage:
- Run ${APP_NAME}.exe to launch the GUI
- Or run from command line: ${APP_NAME}.exe <video-file>

For more information, visit: https://github.com/yourusername/localcast
EOF

    # Create ZIP archive
    echo "  - Creating ZIP archive..."
    cd "${DIST_DIR}"
    ZIP_NAME="${APP_NAME}-${APP_VERSION}-Windows-x64.zip"
    zip -r "../${ZIP_NAME}" "${APP_NAME}"
    cd "${SCRIPT_DIR}"

    echo ""
    echo "✅ Build complete!"
    echo ""
    echo "Windows executable:"
    echo "  target/x86_64-pc-windows-gnu/release/localcast.exe"
    echo ""
    echo "Distribution package:"
    echo "  target/release/${ZIP_NAME}"
    echo ""
    echo "To test on Windows: Copy the ZIP file to a Windows machine and extract it."
else
    echo ""
    echo "❌ Build failed!"
    exit 1
fi
