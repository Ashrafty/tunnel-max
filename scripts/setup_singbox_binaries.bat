@echo off
REM Setup script for sing-box binaries
REM Downloads and sets up sing-box binaries for Android and Windows

echo Setting up sing-box binaries...
echo.

REM Check if PowerShell is available
where powershell >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo PowerShell is required but not found. Please install PowerShell.
    pause
    exit /b 1
)

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "%~dp0setup_singbox_binaries.ps1" %*

if %ERRORLEVEL% NEQ 0 (
    echo Failed to setup sing-box binaries.
    pause
    exit /b 1
)

echo.
echo sing-box binaries setup completed!
pause