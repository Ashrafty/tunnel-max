# PowerShell build script for TunnelMax VPN Android APK
# This script builds debug and release APKs with proper configuration

Write-Host "Building TunnelMax VPN for Android..." -ForegroundColor Green
Write-Host ""

# Check if Flutter is installed
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    Write-Host "Error: Flutter is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Flutter from https://flutter.dev/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Blue
flutter clean
flutter pub get

# Generate launcher icons
Write-Host "Generating launcher icons..." -ForegroundColor Blue
flutter packages pub run flutter_launcher_icons:main

# Build debug APK
Write-Host ""
Write-Host "Building debug APK..." -ForegroundColor Blue
flutter build apk --debug

if ($LASTEXITCODE -eq 0) {
    Write-Host "Debug APK built successfully!" -ForegroundColor Green
    Write-Host "Location: build\app\outputs\flutter-apk\app-debug.apk" -ForegroundColor Yellow
} else {
    Write-Host "Error: Debug build failed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Build release APK
Write-Host ""
Write-Host "Building release APK..." -ForegroundColor Blue
flutter build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "Release APK built successfully!" -ForegroundColor Green
    Write-Host "Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Yellow
    Write-Host ""
    
    # Copy APKs to root directory for easy access
    if (Test-Path "build\app\outputs\flutter-apk\app-release.apk") {
        Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "TunnelMax_VPN_v1.0.0.apk"
        Write-Host "Release APK copied to: TunnelMax_VPN_v1.0.0.apk" -ForegroundColor Green
    }
    
    if (Test-Path "build\app\outputs\flutter-apk\app-debug.apk") {
        Copy-Item "build\app\outputs\flutter-apk\app-debug.apk" "TunnelMax_VPN_v1.0.0_debug.apk"
        Write-Host "Debug APK copied to: TunnelMax_VPN_v1.0.0_debug.apk" -ForegroundColor Green
    }
} else {
    Write-Host "Error: Release build failed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Build Android App Bundle (AAB) for Play Store
Write-Host ""
Write-Host "Building Android App Bundle (AAB)..." -ForegroundColor Blue
flutter build appbundle --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "App Bundle built successfully!" -ForegroundColor Green
    Write-Host "Location: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Yellow
    
    if (Test-Path "build\app\outputs\bundle\release\app-release.aab") {
        Copy-Item "build\app\outputs\bundle\release\app-release.aab" "TunnelMax_VPN_v1.0.0.aab"
        Write-Host "App Bundle copied to: TunnelMax_VPN_v1.0.0.aab" -ForegroundColor Green
    }
} else {
    Write-Host "Warning: App Bundle build failed (this is optional)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Android build completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Files created:" -ForegroundColor Cyan
if (Test-Path "TunnelMax_VPN_v1.0.0.apk") { Write-Host "- TunnelMax_VPN_v1.0.0.apk (Release APK)" -ForegroundColor White }
if (Test-Path "TunnelMax_VPN_v1.0.0_debug.apk") { Write-Host "- TunnelMax_VPN_v1.0.0_debug.apk (Debug APK)" -ForegroundColor White }
if (Test-Path "TunnelMax_VPN_v1.0.0.aab") { Write-Host "- TunnelMax_VPN_v1.0.0.aab (App Bundle for Play Store)" -ForegroundColor White }
Write-Host ""

# Show APK information
if (Test-Path "TunnelMax_VPN_v1.0.0.apk") {
    Write-Host "APK Information:" -ForegroundColor Cyan
    $aaptPath = Get-Command aapt -ErrorAction SilentlyContinue
    if ($aaptPath) {
        & aapt dump badging "TunnelMax_VPN_v1.0.0.apk" 2>$null | Select-String "package|application-label|versionCode|versionName"
    } else {
        Write-Host "aapt not found. Install Android SDK build-tools to view APK information." -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "Build process completed!" -ForegroundColor Green
Read-Host "Press Enter to exit"