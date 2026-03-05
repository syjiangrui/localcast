# LocalCast (本地投屏助手)

将本地视频文件投屏到局域网中的 DLNA 兼容电视。

Cast local video files to DLNA-compatible TVs on your local network.

## Features

- **Two modes**: TUI command-line interface + GUI desktop app
- **Cross-platform**: macOS (universal binary) and Windows
- **Auto-discovery**: Automatically finds DLNA/UPnP devices on the network
- **Video formats**: MP4, MKV, AVI, WebM, and other formats supported by your TV
- **Playback control**: Play, pause, stop, and seek
- **Bilingual UI**: Chinese and English (GUI)
- **Drag & drop**: Drop video files directly into the app (GUI)
- **Play history**: Recently cast files are saved locally and shown in a side panel for quick access (GUI)

## Installation

Download the latest release from [GitHub Releases](https://github.com/nickcao/localcast/releases):

- **macOS**: Download the `.dmg`, open it, and drag LocalCast to Applications
- **Windows**: Download the `.zip`, extract, and run `localcast.exe`

## CLI Usage

```bash
localcast <video-file>
```

Options:

- `-p, --port <PORT>` — Port for the HTTP media server (default: auto-assign)

Example:

```bash
localcast movie.mp4
localcast --port 9000 movie.mkv
```

The TUI will discover DLNA devices on your network, let you select one, and start casting.

## Building from Source

### Prerequisites

- [Rust](https://www.rust-lang.org/tools/install) (stable)
- [Flutter](https://docs.flutter.dev/get-started/install) (for the GUI)

### macOS

```bash
./build_app.sh
```

Produces a `.dmg` installer with a universal (arm64 + x86_64) binary.

### Windows

```powershell
.\build_app.ps1
```

Produces a `localcast-windows.zip` package.

### Development

```bash
# Run the GUI with hot-reload (builds Rust backend automatically)
./start_gui.sh

# Build Rust backend only
cargo build --release

# Run Flutter tests
cd flutter_app && flutter test
```

## Architecture

```
┌─────────────────────┐      HTTP API       ┌──────────────────┐
│   Flutter Frontend   │ ◄──────────────────► │   Rust Backend   │
│   (flutter_app/)     │   localhost:8080     │   (src/)         │
│                      │      + SSE           │                  │
│  • FilePickerScreen  │                      │  • Axum API      │
│  • DeviceListScreen  │                      │  • DLNA/UPnP     │
│  • PlaybackScreen    │                      │  • Media Server   │
└─────────────────────┘                      └──────────────────┘
```

**Rust backend** (`src/`): DLNA device discovery, UPnP/SOAP playback control, HTTP media server for streaming files to TVs, and a REST API + SSE for the GUI.

**Flutter frontend** (`flutter_app/`): macOS/Windows desktop app with Provider state management. Communicates with the backend via HTTP and receives real-time updates via SSE.

In TUI mode, the Rust binary runs standalone with a terminal UI — no Flutter needed.
