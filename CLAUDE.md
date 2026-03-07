# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Project Is

LocalCast (本地投屏助手) is a macOS/Windows app that casts local video files to DLNA-compatible TVs on the local network. It has two interfaces:

- **TUI mode** (standalone): `localcast <file>` — Rust-based terminal UI for device discovery and playback control
- **GUI mode**: A native SwiftUI macOS app (or Flutter Windows app) that communicates with the Rust backend via a local HTTP API

## Build Commands

```bash
# Build everything and produce a .dmg for distribution (macOS)
./build_app.sh

# Build everything and produce a .zip for distribution (Windows)
# Run from PowerShell:
.\build_app.ps1
# Or from Command Prompt / double-click:
build_app.bat

# Development: build Rust backend and open Xcode (macOS)
./start_gui.sh

# Build Rust backend only
cargo build --release

# Build SwiftUI app only (macOS, via xcodebuild)
xcodebuild -project swiftui_app/LocalCast.xcodeproj -scheme LocalCast -configuration Release

# Build Flutter app only (Windows)
cd flutter_app && flutter build windows --release

# Run Flutter tests (Windows UI only)
cd flutter_app && flutter test
```

## Architecture

### Rust Backend (`src/`)

Two execution modes controlled by CLI args (`src/cli.rs`):

1. **TUI mode** (default): Takes a file path, starts an HTTP media server (`src/server.rs`), discovers DLNA devices (`src/discovery.rs`), renders a terminal UI (`src/tui/`), and controls playback via DLNA/UPnP SOAP commands (`src/dlna/transport.rs`).

2. **API mode** (`--api`): Runs an Axum HTTP server on `127.0.0.1:<port>` (`src/api/`) that exposes REST endpoints for the GUI frontends. The API manages its own state (`src/api/state.rs`) and pushes real-time status updates via SSE (`src/api/sse.rs`).

Key API endpoints defined in `src/api/mod.rs`:
- `POST /api/select-file`, `GET /api/discover`, `POST /api/discover/refresh`, `POST /api/select-device`
- `POST /api/cast`, `/api/play`, `/api/pause`, `/api/stop`, `/api/seek`
- `GET /api/status`, `GET /api/status/stream` (SSE), `GET /api/devices/stream` (SSE)

### macOS SwiftUI Frontend (`swiftui_app/`)

Native SwiftUI macOS app (macOS 14+) using `@Observable` for state management:

- **App**: `LocalCastApp.swift` (`@main` entry point, WindowGroup, SwiftData container), `BackendManager.swift` (Rust backend process lifecycle)
- **Models**: `DlnaDevice`, `PlaybackStatus`, `FileInfo`, `DiscoverResult` (Codable), `HistoryEntry` (SwiftData `@Model`)
- **Services**: `ApiService` (actor-based URLSession HTTP client), `SseService` (delegate-based SSE client using `URLSessionDataDelegate` for chunked streaming)
- **ViewModels**: `FileViewModel`, `DeviceViewModel`, `PlaybackViewModel`, `HistoryViewModel` (all `@Observable`)
- **Views**: `ContentView` (NavigationStack root) → `FilePickerView` (drag-drop + file picker + history panel) → `DeviceListView` (device scan/select) → `PlaybackView` (controls + progress)
- **Localization**: Xcode String Catalog (`Localizable.xcstrings`, zh-Hans / en)

### Windows Flutter Frontend (`flutter_app/`)

Flutter Windows app using Provider for state management (macOS Flutter UI is no longer used):

- **Providers**: `FileProvider`, `DeviceProvider`, `PlaybackProvider`, `HistoryProvider` — each wraps service calls
- **Services**: `ApiService` (HTTP client to Rust backend), `SseService` (SSE stream for live playback status), `DeviceSseService` (SSE stream for live device list updates), `HistoryService` (local SQLite via sqflite_common_ffi for play history)
- **Screens**: `FilePickerScreen` → `DeviceListScreen` → `PlaybackScreen`
- **Localization**: Manual i18n in `lib/l10n/app_localizations.dart` (zh/en)

### macOS App Bundle Integration

`BackendManager.swift` manages the Rust backend lifecycle:
- On launch: looks for the backend binary in `Contents/Helpers/` (production), walks up from bundle (in-tree builds), or resolves from source path via `#filePath` (Xcode DerivedData)
- Spawns the backend with `--api --api-port 0`, reads `LOCALCAST_PORT=<port>` from stdout
- Polls `GET /api/status` until ready (10s timeout)
- Terminates the backend when the app quits

### Windows App Integration

`flutter_window.cpp` manages the Rust backend lifecycle (mirrors the macOS approach):
- On launch: looks for `localcast.exe` next to the Flutter executable (production) or walks up to find `target\release\localcast.exe` (development)
- Spawns the backend with `--api` flag via `CreateProcessW` with `CREATE_NO_WINDOW`
- Terminates the backend when the window is destroyed

### Build & Packaging (`build_app.sh` / `build_app.ps1`)

**macOS** (`build_app.sh`):
1. Builds Rust backend for both `aarch64-apple-darwin` and `x86_64-apple-darwin`, then merges them with `lipo` into a universal binary at `target/universal-release/localcast`
2. `xcodebuild` — builds SwiftUI .app bundle
3. Copies the universal Rust binary into `.app/Contents/Helpers/`
4. Re-signs the bundle with ad-hoc signature
5. Creates a DMG with an Applications symlink for drag-to-install

**Windows** (`build_app.ps1`, also invoked by `build_app.bat`):
1. `cargo build --release` — builds Rust backend to `target\release\localcast.exe`
2. `flutter build windows --release` — builds Flutter app to `flutter_app\build\windows\x64\runner\Release\`
3. Copies `localcast.exe` into the Release directory
4. Zips the Release directory into `localcast-windows.zip` using `System.IO.Compression.ZipFile`

## Key Configuration Files

- `swiftui_app/LocalCast.xcodeproj` — macOS SwiftUI Xcode project
- `swiftui_app/LocalCast.entitlements` — macOS entitlements for code signing
- `swiftui_app/LocalCast/Localization/Localizable.xcstrings` — macOS localization (zh-Hans / en)
- `flutter_app/` — Windows Flutter app (providers, services, screens, widgets)
