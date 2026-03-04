$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FlutterDir = Join-Path $ScriptDir 'flutter_app'
$ReleaseDir = Join-Path $FlutterDir 'build\windows\x64\runner\Release'
$ZipPath = Join-Path $ScriptDir 'localcast-windows.zip'

# Build Rust backend
Write-Host '==> Building Rust backend (release)...'
& cargo build --release
if (-not (Test-Path (Join-Path $ScriptDir 'target\release\localcast.exe'))) {
    Write-Error 'ERROR: cargo build failed, localcast.exe not found'
    exit 1
}

# Build Flutter app
Write-Host '==> Building Flutter Windows app (release)...'
Push-Location $FlutterDir
try {
    & flutter build windows --release
} finally {
    Pop-Location
}
if (-not (Test-Path (Join-Path $ReleaseDir 'flutter_app.exe'))) {
    Write-Error 'ERROR: flutter build failed, flutter_app.exe not found'
    exit 1
}

# Copy backend binary
Write-Host '==> Copying backend binary into Release directory...'
Copy-Item -Force (Join-Path $ScriptDir 'target\release\localcast.exe') (Join-Path $ReleaseDir 'localcast.exe')

# Create zip
Write-Host '==> Creating zip package...'
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Add-Type -Assembly System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($ReleaseDir, $ZipPath)
if (-not (Test-Path $ZipPath)) {
    Write-Error 'ERROR: failed to create zip'
    exit 1
}

Write-Host ''
Write-Host "Done! Release directory is at:"
Write-Host "  $ReleaseDir"
Write-Host ''
Write-Host "Zip package: $ZipPath"
