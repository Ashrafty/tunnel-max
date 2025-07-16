@echo off
REM Build script for TunnelMax VPN Android APK
REM This script builds debug and release APKs with proper configuration

echo Building TunnelMax VPN for Android...
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Flutter is not installed or not in PATH.
    echo Please install Flutter from https://flutter.dev/
    pause
    exit /b 1
)

REM Clean previous builds
echo Cleaning previous builds...
flutter clean
flutter pub get

REM Generate launcher icons
echo Generating launcher icons...
flutter packages pub run flutter_launcher_icons:main

REM Build debug APK
echo.
echo Building debug APK...
flutter build apk --debug

if %ERRORLEVEL% EQU 0 (
    echo Debug APK built successfully!
    echo Location: build\app\outputs\flutter-apk\app-debug.apk
) else (
    echo Error: Debug build failed.
    pause
    exit /b 1
)

REM Build release APK
echo.
echo Building release APK...
flutter build apk --release

if %ERRORLEVEL% EQU 0 (
    echo Release APK built successfully!
    echo Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    
    REM Copy APKs to root directory for easy access
    if exist "build\app\outputs\flutter-apk\app-release.apk" (
        copy "build\app\outputs\flutter-apk\app-release.apk" "TunnelMax_VPN_v1.0.0.apk"
        echo Release APK copied to: TunnelMax_VPN_v1.0.0.apk
    )
    
    if exist "build\app\outputs\flutter-apk\app-debug.apk" (
        copy "build\app\outputs\flutter-apk\app-debug.apk" "TunnelMax_VPN_v1.0.0_debug.apk"
        echo Debug APK copied to: TunnelMax_VPN_v1.0.0_debug.apk
    )
) else (
    echo Error: Release build failed.
    pause
    exit /b 1
)

REM Build Android App Bundle (AAB) for Play Store
echo.
echo Building Android App Bundle (AAB)...
flutter build appbundle --release

if %ERRORLEVEL% EQU 0 (
    echo App Bundle built successfully!
    echo Location: build\app\outputs\bundle\release\app-release.aab
    
    if exist "build\app\outputs\bundle\release\app-release.aab" (
        copy "build\app\outputs\bundle\release\app-release.aab" "TunnelMax_VPN_v1.0.0.aab"
        echo App Bundle copied to: TunnelMax_VPN_v1.0.0.aab
    )
) else (
    echo Warning: App Bundle build failed (this is optional).
)

echo.
echo Android build completed!
echo.
echo Files created:
if exist "TunnelMax_VPN_v1.0.0.apk" echo - TunnelMax_VPN_v1.0.0.apk (Release APK)
if exist "TunnelMax_VPN_v1.0.0_debug.apk" echo - TunnelMax_VPN_v1.0.0_debug.apk (Debug APK)
if exist "TunnelMax_VPN_v1.0.0.aab" echo - TunnelMax_VPN_v1.0.0.aab (App Bundle for Play Store)
echo.

REM Show APK information
if exist "TunnelMax_VPN_v1.0.0.apk" (
    echo APK Information:
    aapt dump badging "TunnelMax_VPN_v1.0.0.apk" 2>nul | findstr "package\|application-label\|versionCode\|versionName"
    echo.
)

echo Build process completed!
pause