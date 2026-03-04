# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

LocalCast (本地投屏助手) is a macOS/Windows app that casts local video files to DLNA-compatible TVs on the local network. It has two interfaces:

- **TUI mode** (standalone): `localcast <file>` — Rust-based terminal UI for device discovery and playback control
- **GUI mode**: A Flutter macOS/Windows app that communicates with the Rust backend via a local HTTP API on port 8080

## Build Commands

```bash
# Build everything and produce a .dmg for distribution (macOS)
./build_app.sh

# Development: run Flutter GUI with hot-reload (builds and starts Rust backend automatically, macOS)
./start_gui.sh

# Build Rust backend only
cargo build --release

# Build Flutter app only (macOS)
cd flutter_app && flutter build macos --release

# Build Flutter app only (Windows)
cd flutter_app && flutter build windows --release

# Run Flutter tests
cd flutter_app && flutter test

# Run a single Flutter test
cd flutter_app && flutter test test/widget_test.dart
```

## Architecture

### Rust Backend (`src/`)

Two execution modes controlled by CLI args (`src/cli.rs`):

1. **TUI mode** (default): Takes a file path, starts an HTTP media server (`src/server.rs`), discovers DLNA devices (`src/discovery.rs`), renders a terminal UI (`src/tui/`), and controls playback via DLNA/UPnP SOAP commands (`src/dlna/transport.rs`).

2. **API mode** (`--api`): Runs an Axum HTTP server on `127.0.0.1:8080` (`src/api/`) that exposes REST endpoints for the Flutter GUI. The API manages its own state (`src/api/state.rs`) and pushes real-time status updates via SSE (`src/api/sse.rs`).

Key API endpoints defined in `src/api/mod.rs`:
- `POST /api/select-file`, `GET /api/discover`, `POST /api/select-device`
- `POST /api/cast`, `/api/play`, `/api/pause`, `/api/stop`, `/api/seek`
- `GET /api/status`, `GET /api/status/stream` (SSE)

### Flutter Frontend (`flutter_app/`)

macOS/Windows Flutter app using Provider for state management:

- **Providers**: `FileProvider`, `DeviceProvider`, `PlaybackProvider` — each wraps `ApiService` calls
- **Services**: `ApiService` (HTTP client to Rust backend), `SseService` (SSE stream for live status)
- **Screens**: `FilePickerScreen` → `DeviceListScreen` → `PlaybackScreen`
- **Localization**: Manual i18n in `lib/l10n/app_localizations.dart` (zh/en)

### macOS App Bundle Integration

`AppDelegate.swift` manages the Rust backend lifecycle:
- On launch: looks for the backend binary in `Contents/Helpers/` (production) or walks up to find `target/release/localcast` (development)
- Spawns the backend with `--api` flag
- Terminates the backend when the app quits

### Windows App Integration

`flutter_window.cpp` manages the Rust backend lifecycle (mirrors the macOS approach):
- On launch: looks for `localcast.exe` next to the Flutter executable (production) or walks up to find `target\release\localcast.exe` (development)
- Spawns the backend with `--api` flag via `CreateProcessW` with `CREATE_NO_WINDOW`
- Terminates the backend when the window is destroyed

`flutter_app/lib/main.dart` has a `BackendGate` widget that waits for the backend to respond before showing the main UI.

### Build & Packaging (`build_app.sh`)

1. Builds Rust backend for both `aarch64-apple-darwin` and `x86_64-apple-darwin`, then merges them with `lipo` into a universal binary at `target/universal-release/localcast`
2. `flutter build macos --release` — builds Flutter .app bundle (also universal via Xcode config)
3. Copies the universal Rust binary into `.app/Contents/Helpers/`
4. Re-signs the bundle with ad-hoc signature
5. Creates a DMG with an Applications symlink for drag-to-install

## Key Configuration Files

- `flutter_app/macos/Runner/Configs/AppInfo.xcconfig` — app display name (`PRODUCT_NAME`)
- `flutter_app/macos/Runner/Base.lproj/MainMenu.xib` — macOS menu bar and window title
- `flutter_app/macos/Runner/Release.entitlements` — macOS entitlements for code signing
