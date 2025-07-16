# PowerShell build script for TunnelMax VPN Windows application
# This script builds the Windows executable and creates an installer

Write-Host "Building TunnelMax VPN for Windows..." -ForegroundColor Green
Write-Host ""

# Check if Flutter is installed
$flutterPath = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterPath) {
    Write-Host "Error: Flutter is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Flutter from https://flutter.dev/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if Visual Studio Build Tools are available
$msbuildPath = Get-Command msbuild -ErrorAction SilentlyContinue
if (-not $msbuildPath) {
    Write-Host "Warning: MSBuild not found in PATH." -ForegroundColor Yellow
    Write-Host "Make sure Visual Studio Build Tools are installed." -ForegroundColor Yellow
    Write-Host "Continuing with Flutter build..." -ForegroundColor Blue
}

# Clean previous builds
Write-Host "Cleaning previous builds..." -ForegroundColor Blue
flutter clean
flutter pub get

# Generate launcher icons
Write-Host "Generating launcher icons..." -ForegroundColor Blue
flutter packages pub run flutter_launcher_icons:main

# Build Windows release
Write-Host ""
Write-Host "Building Windows release..." -ForegroundColor Blue
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Windows build failed." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Windows build completed successfully!" -ForegroundColor Green
Write-Host "Location: build\windows\x64\runner\Release\" -ForegroundColor Yellow

# Check if executable exists
$exePath = "build\windows\x64\runner\Release\tunnel_max.exe"
if (-not (Test-Path $exePath)) {
    Write-Host "Error: Executable not found at expected location." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Create portable package
Write-Host ""
Write-Host "Creating portable package..." -ForegroundColor Blue
$portableDir = "TunnelMax_VPN_Windows_Portable"
if (Test-Path $portableDir) {
    Remove-Item $portableDir -Recurse -Force
}
New-Item -ItemType Directory -Path $portableDir | Out-Null

# Copy all necessary files
Copy-Item "build\windows\x64\runner\Release\*" $portableDir -Recurse -Force

if ($LASTEXITCODE -eq 0 -or $?) {
    Write-Host "Portable package created: $portableDir\" -ForegroundColor Green
    
    # Create ZIP archive if available
    try {
        $zipPath = "TunnelMax_VPN_Windows_v1.0.0_Portable.zip"
        Compress-Archive -Path "$portableDir\*" -DestinationPath $zipPath -Force
        Write-Host "ZIP archive created: $zipPath" -ForegroundColor Green
    } catch {
        Write-Host "Could not create ZIP archive. You can manually compress the $portableDir folder." -ForegroundColor Yellow
    }
} else {
    Write-Host "Error: Failed to create portable package." -ForegroundColor Red
}

# Build installer if NSIS is available
Write-Host ""
Write-Host "Checking for NSIS installer..." -ForegroundColor Blue
$nsisPath = Get-Command makensis -ErrorAction SilentlyContinue
if ($nsisPath) {
    Write-Host "Building Windows installer..." -ForegroundColor Blue
    Set-Location "windows\installer"
    & makensis tunnelmax_installer.nsi
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Installer created successfully!" -ForegroundColor Green
        Move-Item "TunnelMax_VPN_Setup_1.0.0.exe" "..\..\TunnelMax_VPN_Setup_1.0.0.exe" -Force
        Write-Host "Installer location: TunnelMax_VPN_Setup_1.0.0.exe" -ForegroundColor Yellow
    } else {
        Write-Host "Error: Installer creation failed." -ForegroundColor Red
    }
    Set-Location "..\..\"
} else {
    Write-Host "NSIS not found. Skipping installer creation." -ForegroundColor Yellow
    Write-Host "Install NSIS from https://nsis.sourceforge.io/ to create installers." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Windows build completed!" -ForegroundColor Green
Write-Host ""
Write-Host "Files created:" -ForegroundColor Cyan
if (Test-Path $portableDir) { Write-Host "- $portableDir\ (Portable application folder)" -ForegroundColor White }
if (Test-Path "TunnelMax_VPN_Windows_v1.0.0_Portable.zip") { Write-Host "- TunnelMax_VPN_Windows_v1.0.0_Portable.zip (Portable ZIP)" -ForegroundColor White }
if (Test-Path "TunnelMax_VPN_Setup_1.0.0.exe") { Write-Host "- TunnelMax_VPN_Setup_1.0.0.exe (Windows Installer)" -ForegroundColor White }
Write-Host ""

# Show executable information
if (Test-Path $exePath) {
    Write-Host "Executable Information:" -ForegroundColor Cyan
    try {
        $fileInfo = Get-Item $exePath
        $versionInfo = $fileInfo.VersionInfo
        Write-Host "File Version: $($versionInfo.FileVersion)" -ForegroundColor White
        Write-Host "Product Version: $($versionInfo.ProductVersion)" -ForegroundColor White
        Write-Host "Company Name: $($versionInfo.CompanyName)" -ForegroundColor White
        Write-Host "File Description: $($versionInfo.FileDescription)" -ForegroundColor White
    } catch {
        Write-Host "Could not retrieve version information." -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "Build process completed!" -ForegroundColor Green
Read-Host "Press Enter to exit"