@echo off
REM Build script for TunnelMax VPN Windows installer
REM This script builds the Flutter app and creates a Windows installer

echo Building TunnelMax VPN Windows Installer...
echo.

REM Check if NSIS is installed
where makensis >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: NSIS (Nullsoft Scriptable Install System) is not installed or not in PATH.
    echo Please install NSIS from https://nsis.sourceforge.io/
    echo.
    pause
    exit /b 1
)

REM Build Flutter app for Windows release
echo Building Flutter app for Windows...
flutter build windows --release

if %ERRORLEVEL% NEQ 0 (
    echo Error: Flutter build failed.
    pause
    exit /b 1
)

REM Check if build output exists
if not exist "build\windows\x64\runner\Release\tunnel_max.exe" (
    echo Error: Flutter build output not found.
    echo Expected: build\windows\x64\runner\Release\tunnel_max.exe
    pause
    exit /b 1
)

REM Create installer using NSIS
echo Creating Windows installer...
cd windows\installer
makensis tunnelmax_installer.nsi

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Installer created successfully!
    echo Output: windows\installer\TunnelMax_VPN_Setup_1.0.0.exe
    echo.
    
    REM Move installer to root directory for easy access
    move "TunnelMax_VPN_Setup_1.0.0.exe" "..\..\TunnelMax_VPN_Setup_1.0.0.exe"
    echo Installer moved to: TunnelMax_VPN_Setup_1.0.0.exe
) else (
    echo Error: Failed to create installer.
)

cd ..\..
echo.
pause