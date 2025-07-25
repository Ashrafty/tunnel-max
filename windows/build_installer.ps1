# PowerShell build script for TunnelMax VPN Windows installer
# This script builds the Flutter app and creates a Windows installer

Write-Host "Building TunnelMax VPN Windows Installer..." -ForegroundColor Green
Write-Host ""

# Check if NSIS is installed
$nsisPath = Get-Command makensis -ErrorAction SilentlyContinue
if (-not $nsisPath) {
    Write-Host "Error: NSIS (Nullsoft Scriptable Install System) is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install NSIS from https://nsis.sourceforge.io/" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Validate sing-box executable before building
Write-Host "Validating sing-box executable..." -ForegroundColor Blue
$singboxPath = "sing-box\sing-box.exe"
if (-not (Test-Path $singboxPath)) {
    Write-Host "Error: sing-box executable not found at: $singboxPath" -ForegroundColor Red
    Write-Host "Run 'scripts\setup_singbox_binaries.ps1' to download sing-box binary" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Check sing-box executable size (should be at least 10MB)
$singboxSize = (Get-Item $singboxPath).Length
if ($singboxSize -lt 10MB) {
    Write-Host "Warning: sing-box executable seems too small ($([math]::Round($singboxSize/1MB, 2)) MB)" -ForegroundColor Yellow
    Write-Host "This might indicate a corrupted or placeholder file" -ForegroundColor Yellow
} else {
    Write-Host "sing-box executable validated: $([math]::Round($singboxSize/1MB, 2)) MB" -ForegroundColor Green
}

# Build Flutter app for Windows release
Write-Host "Building Flutter app for Windows..." -ForegroundColor Blue
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Flutter build failed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if build output exists
$buildPath = "build\windows\x64\runner\Release\tunnel_max.exe"
if (-not (Test-Path $buildPath)) {
    Write-Host "Error: Flutter build output not found." -ForegroundColor Red
    Write-Host "Expected: $buildPath" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Create installer using NSIS
Write-Host "Creating Windows installer..." -ForegroundColor Blue
Set-Location "windows\installer"
& makensis tunnelmax_installer.nsi

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Installer created successfully!" -ForegroundColor Green
    Write-Host "Output: windows\installer\TunnelMax_VPN_Setup_1.0.0.exe" -ForegroundColor Yellow
    Write-Host ""
    
    # Move installer to root directory for easy access
    $installerName = "TunnelMax_VPN_Setup_1.0.0.exe"
    if (Test-Path $installerName) {
        Move-Item $installerName "..\..\$installerName" -Force
        Write-Host "Installer moved to: $installerName" -ForegroundColor Green
    }
} else {
    Write-Host "Error: Failed to create installer." -ForegroundColor Red
}

Set-Location "..\..\"
Write-Host ""
Read-Host "Press Enter to exit"