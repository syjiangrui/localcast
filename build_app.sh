#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Building LocalCast (release)..."
cargo build --release

echo ""
echo "Done! Binary is at:"
echo "  target/release/localcast"
