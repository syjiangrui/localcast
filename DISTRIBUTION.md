# LocalCast Distribution Package

## Installation

### macOS
1. Open `LocalCast-0.1.0-macOS.dmg`
2. Drag `LocalCast.app` to the Applications folder
3. Launch LocalCast from Applications

**First Launch Note:** macOS Gatekeeper may prevent the app from opening. If you see "LocalCast can't be opened", right-click the app and select "Open", then click "Open" in the dialog.

### Windows
1. Extract `LocalCast-0.1.0-Windows-x64.zip`
2. Run `LocalCast.exe` from the extracted folder

**Security Note:** Windows SmartScreen may show a warning for unsigned apps. Click "More info" → "Run anyway" to continue.

## Usage

### GUI Mode (Default)
Simply launch the application to use the graphical interface:
1. Select a video file to cast
2. Choose a DLNA device from the list
3. Control playback with the on-screen controls

### Command Line Mode
You can also run LocalCast from the terminal/command prompt:

```bash
# Cast a specific video file
localcast video.mp4

# Show help
localcast --help
```

## Features

- 🎬 Cast video files to DLNA-compatible devices (Smart TVs, media players)
- 📺 Automatic device discovery on your local network
- 🎮 Playback controls (play, pause, seek, stop)
- 🌍 Bilingual interface (English/Chinese)
- 📁 Support for MP4, MKV, AVI, WebM formats

## Requirements

- **Network:** Local network connection
- **Devices:** DLNA-compatible TV or media player
- **macOS:** macOS 10.13 or later
- **Windows:** Windows 10 or later

## Troubleshooting

### No devices found
- Ensure your TV/device supports DLNA
- Make sure your computer and TV are on the same network
- Check that your firewall isn't blocking the app

### Playback issues
- Ensure your video file is in a supported format
- Try a different video to rule out file corruption
- Restart both the app and your DLNA device

### macOS: "App is damaged"
Run this command in Terminal:
```bash
xattr -cr /Applications/LocalCast.app
```

## Support

For issues, questions, or feature requests, please visit:
- GitHub: https://github.com/yourusername/localcast
- Issues: https://github.com/yourusername/localcast/issues

## License

See LICENSE file for details.

---

**Version:** 0.1.0
**Build Date:** $(date +%Y-%m-%d)
