# LocalCast App Icons

This directory contains the app icons for LocalCast in various formats and sizes.

## Files

- `localcast_icon.svg` - Original vector icon source (1024x1024)
- `LocalCast.icns` - macOS app icon bundle
- `localcast_*.png` - PNG icons in various sizes (16, 32, 64, 128, 256, 512, 1024)

## Icon Design

The icon features:
- An indigo gradient background representing the app's theme color
- A TV/monitor screen with a play button symbolizing media playback
- Cast waves emanating from a source point, representing wireless streaming/casting

## Usage

### macOS App Bundle
The `LocalCast.icns` file should be used in the macOS app bundle:
1. Place in `LocalCast.app/Contents/Resources/LocalCast.icns`
2. Reference in `Info.plist` with `<key>CFBundleIconFile</key><string>LocalCast</string>`

### Windows
For Windows, you'll need to convert the PNG files to .ico format using ImageMagick:
```bash
magick convert localcast_16.png localcast_32.png localcast_64.png localcast_128.png localcast_256.png LocalCast.ico
```

### Linux
Use the PNG files directly, typically placing them in:
- `/usr/share/icons/hicolor/{size}/apps/localcast.png`
