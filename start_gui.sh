#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_PID=""

cleanup() {
    if [ -n "$BACKEND_PID" ]; then
        echo "Stopping backend (PID $BACKEND_PID)..."
        kill "$BACKEND_PID" 2>/dev/null || true
        wait "$BACKEND_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# Build Rust backend
echo "Building Rust backend..."
cargo build --manifest-path "$SCRIPT_DIR/Cargo.toml" --release

# Start backend in API mode
echo "Starting API server..."
"$SCRIPT_DIR/target/release/localcast" --api &
BACKEND_PID=$!

# Wait for backend to become ready
echo "Waiting for backend..."
for i in $(seq 1 30); do
    if curl -sf http://127.0.0.1:8080/api/status > /dev/null 2>&1; then
        echo "Backend is ready."
        break
    fi
    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
        echo "Backend process exited unexpectedly."
        exit 1
    fi
    sleep 0.5
done

# Verify backend is responding
if ! curl -sf http://127.0.0.1:8080/api/status > /dev/null 2>&1; then
    echo "Backend did not start in time."
    exit 1
fi

# Run Flutter app
echo "Starting Flutter GUI..."
cd "$SCRIPT_DIR/flutter_app"
flutter run -d macos

echo "Done."
