#!/usr/bin/env pwsh
# Creates placeholder sing-box binaries for development
# This allows the build to succeed while we work on getting the real binaries

param(
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$AndroidLibDir = Join-Path $ProjectRoot "android/app/src/main/jniLibs"
$WindowsBinDir = Join-Path $ProjectRoot "windows/sing-box"

Write-Host "Creating placeholder sing-box binaries for development..." -ForegroundColor Green

# Create placeholder Android libraries
$AndroidArm64Path = Join-Path $AndroidLibDir "arm64-v8a/libsing-box.so"
$AndroidArmPath = Join-Path $AndroidLibDir "armeabi-v7a/libsing-box.so"

if (!(Test-Path $AndroidArm64Path) -or $Force) {
    Write-Host "Creating placeholder ARM64 library..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path (Split-Path $AndroidArm64Path) -Force | Out-Null
    
    # Create a minimal ELF shared library placeholder
    $PlaceholderContent = @(
        0x7F, 0x45, 0x4C, 0x46, 0x02, 0x01, 0x01, 0x00,  # ELF header
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x03, 0x00, 0xB7, 0x00, 0x01, 0x00, 0x00, 0x00,  # ARM64 machine type
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    )
    [System.IO.File]::WriteAllBytes($AndroidArm64Path, $PlaceholderContent)
    Write-Host "Created: $AndroidArm64Path" -ForegroundColor Green
}

if (!(Test-Path $AndroidArmPath) -or $Force) {
    Write-Host "Creating placeholder ARM library..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path (Split-Path $AndroidArmPath) -Force | Out-Null
    
    # Create a minimal ELF shared library placeholder
    $PlaceholderContent = @(
        0x7F, 0x45, 0x4C, 0x46, 0x01, 0x01, 0x01, 0x00,  # ELF header
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x03, 0x00, 0x28, 0x00, 0x01, 0x00, 0x00, 0x00,  # ARM machine type
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    )
    [System.IO.File]::WriteAllBytes($AndroidArmPath, $PlaceholderContent)
    Write-Host "Created: $AndroidArmPath" -ForegroundColor Green
}

# Create placeholder Windows executable
$WindowsExePath = Join-Path $WindowsBinDir "sing-box.exe"
if (!(Test-Path $WindowsExePath) -or $Force) {
    Write-Host "Creating placeholder Windows executable..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path (Split-Path $WindowsExePath) -Force | Out-Null
    
    # Create a minimal PE executable placeholder
    $PlaceholderContent = @(
        0x4D, 0x5A, 0x90, 0x00, 0x03, 0x00, 0x00, 0x00,  # PE header
        0x04, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x00, 0x00,
        0xB8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    )
    [System.IO.File]::WriteAllBytes($WindowsExePath, $PlaceholderContent)
    Write-Host "Created: $WindowsExePath" -ForegroundColor Green
}

Write-Host "" -ForegroundColor Green
Write-Host "Placeholder binaries created successfully!" -ForegroundColor Green
Write-Host "" -ForegroundColor Yellow
Write-Host "IMPORTANT: These are placeholder files for development only." -ForegroundColor Red
Write-Host "To get real sing-box functionality, you need to:" -ForegroundColor Yellow
Write-Host "1. Download real sing-box binaries from: https://github.com/SagerNet/sing-box/releases" -ForegroundColor White
Write-Host "2. Replace the placeholder files with real binaries" -ForegroundColor White
Write-Host "3. For Android: rename sing-box binary to libsing-box.so" -ForegroundColor White
Write-Host "4. For Windows: use sing-box.exe directly" -ForegroundColor White
Write-Host "" -ForegroundColor Green

Write-Host "Files created:" -ForegroundColor Cyan
Write-Host "- $AndroidArm64Path" -ForegroundColor White
Write-Host "- $AndroidArmPath" -ForegroundColor White
Write-Host "- $WindowsExePath" -ForegroundColor White