@echo off
setlocal

set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

echo ==^> Building LocalCast (release)...
cargo build --release
if errorlevel 1 (
    echo ERROR: cargo build failed
    exit /b 1
)

echo.
echo Done! Binary is at:
echo   target\release\localcast.exe
