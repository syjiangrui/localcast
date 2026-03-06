#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build Rust backend
echo "Building Rust backend..."
cargo build --manifest-path "$SCRIPT_DIR/Cargo.toml" --release

# Run Flutter app (AppDelegate/flutter_window.cpp will start/stop the backend)
echo "Starting Flutter GUI..."
cd "$SCRIPT_DIR/flutter_app"
if [[ "$OSTYPE" == "darwin"* ]]; then
    flutter run -d macos
else
    flutter run -d windows
fi

echo "Done."
