#!/usr/bin/env pwsh
# Setup script for sing-box binaries
# Downloads and sets up sing-box binaries for Android and Windows

param(
    [string]$Version = "1.8.10",
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

# URLs for sing-box releases
$BaseUrl = "https://github.com/SagerNet/sing-box/releases/download/v$Version"
$AndroidUrl = "$BaseUrl/sing-box-$Version-android-arm64.tar.gz"
$AndroidArmUrl = "$BaseUrl/sing-box-$Version-android-arm.tar.gz"
$WindowsUrl = "$BaseUrl/sing-box-$Version-windows-amd64.zip"

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$AndroidLibDir = Join-Path $ProjectRoot "android/app/src/main/jniLibs"
$WindowsBinDir = Join-Path $ProjectRoot "windows/sing-box"
$TempDir = Join-Path $ProjectRoot "temp_singbox"

Write-Host "Setting up sing-box binaries v$Version..." -ForegroundColor Green

# Create temp directory
if (Test-Path $TempDir) {
    if ($Force) {
        Remove-Item -Recurse -Force $TempDir
    } else {
        Write-Host "Temp directory exists. Use -Force to overwrite." -ForegroundColor Yellow
        exit 1
    }
}
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

try {
    # Download Android ARM64 binary
    Write-Host "Downloading Android ARM64 binary..." -ForegroundColor Cyan
    $AndroidArm64File = Join-Path $TempDir "sing-box-android-arm64.tar.gz"
    Invoke-WebRequest -Uri $AndroidUrl -OutFile $AndroidArm64File -UseBasicParsing
    
    # Download Android ARM binary
    Write-Host "Downloading Android ARM binary..." -ForegroundColor Cyan
    $AndroidArmFile = Join-Path $TempDir "sing-box-android-arm.tar.gz"
    Invoke-WebRequest -Uri $AndroidArmUrl -OutFile $AndroidArmFile -UseBasicParsing
    
    # Download Windows binary
    Write-Host "Downloading Windows binary..." -ForegroundColor Cyan
    $WindowsFile = Join-Path $TempDir "sing-box-windows.zip"
    Invoke-WebRequest -Uri $WindowsUrl -OutFile $WindowsFile -UseBasicParsing
    
    # Extract Android ARM64 binary
    Write-Host "Extracting Android ARM64 binary..." -ForegroundColor Cyan
    $AndroidArm64ExtractDir = Join-Path $TempDir "android-arm64"
    New-Item -ItemType Directory -Path $AndroidArm64ExtractDir -Force | Out-Null
    
    # Use tar to extract (available on Windows 10+)
    Set-Location $AndroidArm64ExtractDir
    tar -xzf $AndroidArm64File
    
    # Find the sing-box binary and copy it
    $SingboxBinary = Get-ChildItem -Recurse -Name "sing-box" -File | Select-Object -First 1
    if ($SingboxBinary) {
        $SourcePath = Join-Path $AndroidArm64ExtractDir $SingboxBinary
        $DestPath = Join-Path $AndroidLibDir "arm64-v8a/libsing-box.so"
        Copy-Item $SourcePath $DestPath -Force
        Write-Host "Copied ARM64 binary to $DestPath" -ForegroundColor Green
    } else {
        Write-Error "Could not find sing-box binary in ARM64 archive"
    }
    
    # Extract Android ARM binary
    Write-Host "Extracting Android ARM binary..." -ForegroundColor Cyan
    $AndroidArmExtractDir = Join-Path $TempDir "android-arm"
    New-Item -ItemType Directory -Path $AndroidArmExtractDir -Force | Out-Null
    
    Set-Location $AndroidArmExtractDir
    tar -xzf $AndroidArmFile
    
    # Find the sing-box binary and copy it
    $SingboxBinary = Get-ChildItem -Recurse -Name "sing-box" -File | Select-Object -First 1
    if ($SingboxBinary) {
        $SourcePath = Join-Path $AndroidArmExtractDir $SingboxBinary
        $DestPath = Join-Path $AndroidLibDir "armeabi-v7a/libsing-box.so"
        Copy-Item $SourcePath $DestPath -Force
        Write-Host "Copied ARM binary to $DestPath" -ForegroundColor Green
    } else {
        Write-Error "Could not find sing-box binary in ARM archive"
    }
    
    # Extract Windows binary
    Write-Host "Extracting Windows binary..." -ForegroundColor Cyan
    $WindowsExtractDir = Join-Path $TempDir "windows"
    New-Item -ItemType Directory -Path $WindowsExtractDir -Force | Out-Null
    
    Expand-Archive -Path $WindowsFile -DestinationPath $WindowsExtractDir -Force
    
    # Find the sing-box.exe and copy it
    $SingboxExe = Get-ChildItem -Recurse -Name "sing-box.exe" -File | Select-Object -First 1
    if ($SingboxExe) {
        $SourcePath = Join-Path $WindowsExtractDir $SingboxExe
        $DestPath = Join-Path $WindowsBinDir "sing-box.exe"
        Copy-Item $SourcePath $DestPath -Force
        Write-Host "Copied Windows binary to $DestPath" -ForegroundColor Green
    } else {
        Write-Error "Could not find sing-box.exe in Windows archive"
    }
    
    Write-Host "sing-box binaries setup completed successfully!" -ForegroundColor Green
    Write-Host "Android ARM64: $(Join-Path $AndroidLibDir 'arm64-v8a/libsing-box.so')" -ForegroundColor Yellow
    Write-Host "Android ARM: $(Join-Path $AndroidLibDir 'armeabi-v7a/libsing-box.so')" -ForegroundColor Yellow
    Write-Host "Windows: $(Join-Path $WindowsBinDir 'sing-box.exe')" -ForegroundColor Yellow
    
} catch {
    Write-Error "Failed to setup sing-box binaries: $_"
    exit 1
} finally {
    # Cleanup temp directory
    Set-Location $ProjectRoot
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir
    }
}

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Run the Android build to include the native libraries" -ForegroundColor White
Write-Host "2. The Windows executable will be bundled automatically" -ForegroundColor White
Write-Host "3. Test the VPN connection functionality" -ForegroundColor White