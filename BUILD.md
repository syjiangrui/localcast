# Building LocalCast

This guide explains how to build LocalCast for macOS and Windows.

## Prerequisites

### For macOS builds:
- macOS 10.13 or later
- Rust toolchain installed
- Xcode Command Line Tools

### For Windows builds (cross-compilation from macOS):
- macOS with Rust toolchain
- mingw-w64 installed: `brew install mingw-w64`
- Windows target: `rustup target add x86_64-pc-windows-gnu`

## Quick Start

### Build for macOS only:
```bash
./build_macos_app.sh
```

This will create:
- `target/release/LocalCast.app` - macOS application bundle
- `target/release/LocalCast-0.1.0-macOS.dmg` - DMG installer

### Build for Windows only:
```bash
./build_windows.sh
```

This will create:
- `target/x86_64-pc-windows-gnu/release/localcast.exe` - Windows executable
- `target/release/LocalCast-0.1.0-Windows-x64.zip` - Distribution package

### Build for all platforms:
```bash
./build_all.sh
```

Or with specific platforms:
```bash
./build_all.sh macos windows
```

## Distribution

### macOS:
1. Share the `.dmg` file with users
2. Users open the DMG and drag LocalCast.app to Applications folder
3. On first launch, users may need to right-click → Open due to Gatekeeper

### Windows:
1. Share the `.zip` file with users
2. Users extract the ZIP to any folder
3. Run `LocalCast.exe` from the extracted folder

## Code Signing (Optional)

### macOS:
For distribution outside the App Store, you should sign the app with a Developer ID:

```bash
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" target/release/LocalCast.app
```

Then notarize the app with Apple:
```bash
xcrun notarytool submit target/release/LocalCast-0.1.0-macOS.dmg --apple-id your@email.com --team-id TEAMID --password app-specific-password
```

### Windows:
For Windows, you can sign the executable with a code signing certificate:

```bash
signtool sign /f certificate.pfx /p password /t http://timestamp.digicert.com target/x86_64-pc-windows-gnu/release/localcast.exe
```

## Troubleshooting

### macOS: "App is damaged and can't be opened"
This happens when the app is not properly signed. Users can fix this by running:
```bash
xattr -cr /Applications/LocalCast.app
```

### Windows: "Windows protected your PC"
This appears for unsigned executables. Users can click "More info" → "Run anyway"

### Windows build fails with "linker not found"
Make sure mingw-w64 is installed:
```bash
brew install mingw-w64
```

## Build Configuration

Edit `Cargo.toml` to change:
- Version number: `version = "0.1.0"`
- App name: `name = "localcast"`

Edit build scripts to change:
- Bundle identifier (macOS): `BUNDLE_ID` in `build_macos_app.sh`
- App metadata: `APP_NAME` and `APP_VERSION` variables

## Release Checklist

Before creating a release:

- [ ] Update version in `Cargo.toml`
- [ ] Update version in build scripts
- [ ] Test the app thoroughly
- [ ] Build for all platforms
- [ ] Test installers on clean machines
- [ ] Create release notes
- [ ] Tag the release in git
- [ ] Upload build artifacts

## File Sizes (Approximate)

- macOS .app bundle: ~15-20 MB
- macOS .dmg installer: ~8-10 MB (compressed)
- Windows .exe: ~10-15 MB
- Windows .zip: ~5-8 MB (compressed)

## Additional Notes

- The builds are optimized for release (with `--release` flag)
- Strip symbols are enabled by default for smaller binaries
- The Windows build is 64-bit only (x86_64)
- macOS build requires macOS 10.13 or later
