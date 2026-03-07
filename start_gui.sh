#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build Rust backend
echo "Building Rust backend..."
cargo build --manifest-path "$SCRIPT_DIR/Cargo.toml" --release

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Opening Xcode project (use Xcode Run to launch)..."
    open "$SCRIPT_DIR/swiftui_app/LocalCast.xcodeproj"
else
    # Windows: continue using Flutter
    echo "Starting Flutter GUI..."
    cd "$SCRIPT_DIR/flutter_app"
    flutter run -d windows
fi

echo "Done."
