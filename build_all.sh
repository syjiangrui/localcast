#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔════════════════════════════════════════╗"
echo "║   LocalCast - Universal Build Script   ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Parse command line arguments
BUILD_MACOS=false
BUILD_WINDOWS=false
BUILD_ALL=false

if [ $# -eq 0 ]; then
    BUILD_ALL=true
else
    for arg in "$@"; do
        case $arg in
            macos|mac)
                BUILD_MACOS=true
                ;;
            windows|win)
                BUILD_WINDOWS=true
                ;;
            all)
                BUILD_ALL=true
                ;;
            *)
                echo "Unknown argument: $arg"
                echo "Usage: $0 [macos|windows|all]"
                exit 1
                ;;
        esac
    done
fi

if [ "$BUILD_ALL" = true ]; then
    BUILD_MACOS=true
    BUILD_WINDOWS=true
fi

# Build for macOS
if [ "$BUILD_MACOS" = true ]; then
    echo "🍎 Building for macOS..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./build_macos_app.sh
    echo ""
fi

# Build for Windows
if [ "$BUILD_WINDOWS" = true ]; then
    echo "🪟 Building for Windows..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ./build_windows.sh
    echo ""
fi

echo "╔════════════════════════════════════════╗"
echo "║         All Builds Complete! 🎉         ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Build artifacts:"
echo "  📦 target/release/"
echo ""
