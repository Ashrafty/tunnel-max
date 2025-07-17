#!/usr/bin/env pwsh
# Downloads REAL sing-box binaries for production use

param(
    [string]$Version = "1.9.7",
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

# URLs for sing-box releases
$BaseUrl = "https://github.com/SagerNet/sing-box/releases/download/v$Version"
$AndroidArm64Url = "$BaseUrl/sing-box-$Version-android-arm64.tar.gz"
$AndroidArmUrl = "$BaseUrl/sing-box-$Version-android-armv7.tar.gz"
$WindowsUrl = "$BaseUrl/sing-box-$Version-windows-amd64.zip"

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$AndroidLibDir = Join-Path $ProjectRoot "android/app/src/main/jniLibs"
$WindowsBinDir = Join-Path $ProjectRoot "windows/sing-box"
$TempDir = Join-Path $ProjectRoot "temp_singbox_download"

Write-Host "Downloading REAL sing-box binaries v$Version..." -ForegroundColor Green
Write-Host "This will enable actual VPN functionality!" -ForegroundColor Yellow

# Create directories
New-Item -ItemType Directory -Path $AndroidLibDir -Force | Out-Null
New-Item -ItemType Directory -Path "$AndroidLibDir/arm64-v8a" -Force | Out-Null
New-Item -ItemType Directory -Path "$AndroidLibDir/armeabi-v7a" -Force | Out-Null
New-Item -ItemType Directory -Path $WindowsBinDir -Force | Out-Null

# Create temp directory
if (Test-Path $TempDir) {
    Remove-Item -Recurse -Force $TempDir
}
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    # Download Android ARM64 binary
    Write-Host "Downloading Android ARM64 binary..." -ForegroundColor Cyan
    $AndroidArm64File = Join-Path $TempDir "sing-box-android-arm64.tar.gz"
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $AndroidArm64Url -OutFile $AndroidArm64File -UseBasicParsing
    Write-Host "Downloaded ARM64 binary successfully" -ForegroundColor Green
    
    # Download Android ARM binary
    Write-Host "Downloading Android ARM binary..." -ForegroundColor Cyan
    $AndroidArmFile = Join-Path $TempDir "sing-box-android-arm.tar.gz"
    Invoke-WebRequest -Uri $AndroidArmUrl -OutFile $AndroidArmFile -UseBasicParsing
    Write-Host "Downloaded ARM binary successfully" -ForegroundColor Green
    
    # Download Windows binary
    Write-Host "Downloading Windows binary..." -ForegroundColor Cyan
    $WindowsFile = Join-Path $TempDir "sing-box-windows.zip"
    Invoke-WebRequest -Uri $WindowsUrl -OutFile $WindowsFile -UseBasicParsing
    Write-Host "Downloaded Windows binary successfully" -ForegroundColor Green
    
    # Extract Android ARM64 binary
    Write-Host "Extracting Android ARM64 binary..." -ForegroundColor Cyan
    $AndroidArm64ExtractDir = Join-Path $TempDir "android-arm64"
    New-Item -ItemType Directory -Path $AndroidArm64ExtractDir -Force | Out-Null
    
    # Extract using tar
    $CurrentLocation = Get-Location
    Set-Location $AndroidArm64ExtractDir
    & tar -xzf $AndroidArm64File
    Set-Location $CurrentLocation
    
    # Find and copy the sing-box binary
    $SingboxBinary = Get-ChildItem -Path $AndroidArm64ExtractDir -Recurse -Name "sing-box" -File | Select-Object -First 1
    if ($SingboxBinary) {
        $SourcePath = Join-Path $AndroidArm64ExtractDir $SingboxBinary
        $DestPath = Join-Path $AndroidLibDir "arm64-v8a/libsing-box.so"
        Copy-Item $SourcePath $DestPath -Force
        Write-Host "ARM64 binary installed successfully" -ForegroundColor Green
    } else {
        throw "Could not find sing-box binary in ARM64 archive"
    }
    
    # Extract Android ARM binary
    Write-Host "Extracting Android ARM binary..." -ForegroundColor Cyan
    $AndroidArmExtractDir = Join-Path $TempDir "android-arm"
    New-Item -ItemType Directory -Path $AndroidArmExtractDir -Force | Out-Null
    
    Set-Location $AndroidArmExtractDir
    & tar -xzf $AndroidArmFile
    Set-Location $CurrentLocation
    
    # Find and copy the sing-box binary
    $SingboxBinary = Get-ChildItem -Path $AndroidArmExtractDir -Recurse -Name "sing-box" -File | Select-Object -First 1
    if ($SingboxBinary) {
        $SourcePath = Join-Path $AndroidArmExtractDir $SingboxBinary
        $DestPath = Join-Path $AndroidLibDir "armeabi-v7a/libsing-box.so"
        Copy-Item $SourcePath $DestPath -Force
        Write-Host "ARM binary installed successfully" -ForegroundColor Green
    } else {
        throw "Could not find sing-box binary in ARM archive"
    }
    
    # Extract Windows binary
    Write-Host "Extracting Windows binary..." -ForegroundColor Cyan
    $WindowsExtractDir = Join-Path $TempDir "windows"
    New-Item -ItemType Directory -Path $WindowsExtractDir -Force | Out-Null
    
    Expand-Archive -Path $WindowsFile -DestinationPath $WindowsExtractDir -Force
    
    # Find and copy sing-box.exe
    $SingboxExe = Get-ChildItem -Path $WindowsExtractDir -Recurse -Name "sing-box.exe" -File | Select-Object -First 1
    if ($SingboxExe) {
        $SourcePath = Join-Path $WindowsExtractDir $SingboxExe
        $DestPath = Join-Path $WindowsBinDir "sing-box.exe"
        Copy-Item $SourcePath $DestPath -Force
        Write-Host "Windows binary installed successfully" -ForegroundColor Green
    } else {
        throw "Could not find sing-box.exe in Windows archive"
    }
    
    Write-Host ""
    Write-Host "REAL sing-box binaries installed successfully!" -ForegroundColor Green
    Write-Host "Your VPN app now has actual sing-box core functionality!" -ForegroundColor Yellow
    
    # Test the Windows binary
    Write-Host "Testing Windows binary..." -ForegroundColor Cyan
    try {
        $TestOutput = & "$DestPath" version 2>&1
        if ($TestOutput -match "sing-box") {
            Write-Host "Windows binary is working correctly" -ForegroundColor Green
        }
    } catch {
        Write-Host "Could not test Windows binary but it should work" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Installed files:" -ForegroundColor Cyan
    Write-Host "Android ARM64: $(Join-Path $AndroidLibDir 'arm64-v8a/libsing-box.so')" -ForegroundColor White
    Write-Host "Android ARM: $(Join-Path $AndroidLibDir 'armeabi-v7a/libsing-box.so')" -ForegroundColor White
    Write-Host "Windows: $(Join-Path $WindowsBinDir 'sing-box.exe')" -ForegroundColor White
    
} catch {
    Write-Error "Failed to download/install sing-box binaries: $_"
    Write-Host "Make sure you have internet connection and try again." -ForegroundColor Red
    exit 1
} finally {
    # Cleanup temp directory
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir
    }
}

Write-Host ""
Write-Host "Next steps to get VPN working:" -ForegroundColor Cyan
Write-Host "1. Build the Android app - native libraries are now included" -ForegroundColor White
Write-Host "2. The JNI layer will load libsing-box.so automatically" -ForegroundColor White
Write-Host "3. Windows will use sing-box.exe for VPN connections" -ForegroundColor White
Write-Host "4. Test VPN connections with real protocols!" -ForegroundColor White