@echo off
setlocal

set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

set FLUTTER_DIR=%SCRIPT_DIR%flutter_app
set RELEASE_DIR=%FLUTTER_DIR%\build\windows\x64\runner\Release

echo ==^> Building Rust backend (release)...
cargo build --release
if errorlevel 1 (
    echo ERROR: cargo build failed
    exit /b 1
)

echo ==^> Building Flutter Windows app (release)...
cd /d "%FLUTTER_DIR%"
flutter build windows --release
if errorlevel 1 (
    echo ERROR: flutter build failed
    exit /b 1
)
cd /d "%SCRIPT_DIR%"

echo ==^> Copying backend binary into Release directory...
copy /y "target\release\localcast.exe" "%RELEASE_DIR%\localcast.exe"
if errorlevel 1 (
    echo ERROR: failed to copy localcast.exe
    exit /b 1
)

echo.
echo Done! Release directory is at:
echo   %RELEASE_DIR%
echo.
echo You can zip this entire directory for distribution.
