#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Build Rust backend
echo "Building Rust backend..."
cargo build --manifest-path "$SCRIPT_DIR/Cargo.toml" --release

# Run Flutter app (AppDelegate will start/stop the backend with dynamic port)
echo "Starting Flutter GUI..."
cd "$SCRIPT_DIR/flutter_app"
flutter run -d macos

echo "Done."
