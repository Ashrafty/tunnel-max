#!/usr/bin/env pwsh
# Verify native sing-box integration setup

$ErrorActionPreference = "Stop"

Write-Host "=== TunnelMax Native Integration Verification ===" -ForegroundColor Green
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Function to check file existence and size
function Test-FileWithSize {
    param(
        [string]$Path,
        [string]$Description,
        [int]$MinSize = 0
    )
    
    if (Test-Path $Path) {
        $Size = (Get-Item $Path).Length
        if ($Size -gt $MinSize) {
            Write-Host "✓ $Description" -ForegroundColor Green
            Write-Host "  Path: $Path" -ForegroundColor Gray
            Write-Host "  Size: $([math]::Round($Size / 1MB, 2)) MB" -ForegroundColor Gray
            return $true
        } else {
            Write-Host "✗ $Description (file too small: $Size bytes)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "✗ $Description (not found)" -ForegroundColor Red
        Write-Host "  Expected: $Path" -ForegroundColor Gray
        return $false
    }
}

# Function to check directory structure
function Test-DirectoryStructure {
    param(
        [string]$Path,
        [string]$Description
    )
    
    if (Test-Path $Path -PathType Container) {
        Write-Host "✓ $Description" -ForegroundColor Green
        Write-Host "  Path: $Path" -ForegroundColor Gray
        return $true
    } else {
        Write-Host "✗ $Description (not found)" -ForegroundColor Red
        Write-Host "  Expected: $Path" -ForegroundColor Gray
        return $false
    }
}

$AllChecksPass = $true

Write-Host "1. Android Native Integration" -ForegroundColor Cyan
Write-Host "-----------------------------"

# Check Android JNI structure
$AndroidCppDir = Join-Path $ProjectRoot "android/app/src/main/cpp"
$AllChecksPass = (Test-DirectoryStructure $AndroidCppDir "Android C++ source directory") -and $AllChecksPass

# Check JNI source files
$JniHeader = Join-Path $AndroidCppDir "sing_box_jni.h"
$JniSource = Join-Path $AndroidCppDir "sing_box_jni.c"
$CmakeFile = Join-Path $AndroidCppDir "CMakeLists.txt"

$AllChecksPass = (Test-FileWithSize $JniHeader "JNI header file" 1000) -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $JniSource "JNI source file" 5000) -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $CmakeFile "Android CMakeLists.txt" 500) -and $AllChecksPass

# Check Android native libraries
$AndroidLibDir = Join-Path $ProjectRoot "android/app/src/main/jniLibs"
$Arm64LibDir = Join-Path $AndroidLibDir "arm64-v8a"
$ArmLibDir = Join-Path $AndroidLibDir "armeabi-v7a"

$AllChecksPass = (Test-DirectoryStructure $Arm64LibDir "ARM64 library directory") -and $AllChecksPass
$AllChecksPass = (Test-DirectoryStructure $ArmLibDir "ARM library directory") -and $AllChecksPass

$Arm64Lib = Join-Path $Arm64LibDir "libsing-box.so"
$ArmLib = Join-Path $ArmLibDir "libsing-box.so"

$AllChecksPass = (Test-FileWithSize $Arm64Lib "ARM64 sing-box library" 1000000) -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $ArmLib "ARM sing-box library" 1000000) -and $AllChecksPass

# Check Kotlin classes
$KotlinDir = Join-Path $ProjectRoot "android/app/src/main/kotlin/com/tunnelmax/vpnclient"
$SingboxManagerKt = Join-Path $KotlinDir "SingboxManager.kt"
$StatsCollectorKt = Join-Path $KotlinDir "StatsCollector.kt"
$VpnServiceKt = Join-Path $KotlinDir "TunnelMaxVpnService.kt"

$AllChecksPass = (Test-FileWithSize $SingboxManagerKt "Android SingboxManager class" 5000) -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $StatsCollectorKt "Android StatsCollector class" 3000) -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $VpnServiceKt "Android VPN Service class" 5000) -and $AllChecksPass

Write-Host ""
Write-Host "2. Windows Native Integration" -ForegroundColor Cyan
Write-Host "------------------------------"

# Check Windows native structure
$WindowsRunnerDir = Join-Path $ProjectRoot "windows/runner"
$AllChecksPass = (Test-DirectoryStructure $WindowsRunnerDir "Windows runner directory") -and $AllChecksPass

# Check Windows native files
$SingboxManagerH = Join-Path $WindowsRunnerDir "SingboxManager.h"
$SingboxManagerCpp = Join-Path $WindowsRunnerDir "SingboxManager.cpp"
$WindowsCmake = Join-Path $ProjectRoot "windows/CMakeLists.txt"

$AllChecksPass = (Test-FileWithSize $SingboxManagerH "Windows SingboxManager header" 2000) -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $SingboxManagerCpp "Windows SingboxManager implementation" 10000) -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $WindowsCmake "Windows CMakeLists.txt" 3000) -and $AllChecksPass

# Check Windows sing-box executable
$WindowsSingboxDir = Join-Path $ProjectRoot "windows/sing-box"
$WindowsSingboxExe = Join-Path $WindowsSingboxDir "sing-box.exe"

$AllChecksPass = (Test-DirectoryStructure $WindowsSingboxDir "Windows sing-box directory") -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $WindowsSingboxExe "Windows sing-box executable" 10000000) -and $AllChecksPass

Write-Host ""
Write-Host "3. Build Configuration" -ForegroundColor Cyan
Write-Host "----------------------"

# Check build files
$AndroidBuildGradle = Join-Path $ProjectRoot "android/app/build.gradle.kts"
$AndroidManifest = Join-Path $ProjectRoot "android/app/src/main/AndroidManifest.xml"
$PubspecYaml = Join-Path $ProjectRoot "pubspec.yaml"

$AllChecksPass = (Test-FileWithSize $AndroidBuildGradle "Android build.gradle.kts" 2000) -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $AndroidManifest "Android manifest" 1000) -and $AllChecksPass
$AllChecksPass = (Test-FileWithSize $PubspecYaml "Flutter pubspec.yaml" 1000) -and $AllChecksPass

Write-Host ""
Write-Host "4. Platform-Specific Dependencies" -ForegroundColor Cyan
Write-Host "----------------------------------"

# Check if sing-box executables are functional
if (Test-Path $WindowsSingboxExe) {
    try {
        $VersionOutput = & $WindowsSingboxExe version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Windows sing-box executable is functional" -ForegroundColor Green
            Write-Host "  Version: $VersionOutput" -ForegroundColor Gray
        } else {
            Write-Host "✗ Windows sing-box executable test failed" -ForegroundColor Red
            $AllChecksPass = $false
        }
    } catch {
        Write-Host "✗ Windows sing-box executable test error: $_" -ForegroundColor Red
        $AllChecksPass = $false
    }
}

# Check Android manifest for VPN permissions
if (Test-Path $AndroidManifest) {
    $ManifestContent = Get-Content $AndroidManifest -Raw
    if ($ManifestContent -match "android\.permission\.BIND_VPN_SERVICE") {
        Write-Host "✓ Android VPN permissions configured" -ForegroundColor Green
    } else {
        Write-Host "✗ Android VPN permissions missing" -ForegroundColor Red
        $AllChecksPass = $false
    }
    
    if ($ManifestContent -match "TunnelMaxVpnService") {
        Write-Host "✓ Android VPN service registered" -ForegroundColor Green
    } else {
        Write-Host "✗ Android VPN service not registered" -ForegroundColor Red
        $AllChecksPass = $false
    }
}

Write-Host ""
Write-Host "5. Integration Summary" -ForegroundColor Cyan
Write-Host "----------------------"

if ($AllChecksPass) {
    Write-Host "✓ All native integration checks passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Native sing-box integration foundation is properly set up:" -ForegroundColor White
    Write-Host "  • Android JNI wrapper implemented" -ForegroundColor White
    Write-Host "  • Windows process manager implemented" -ForegroundColor White
    Write-Host "  • Platform-specific build configurations ready" -ForegroundColor White
    Write-Host "  • Native libraries and executables in place" -ForegroundColor White
    Write-Host ""
    Write-Host "You can now proceed with building and testing the application." -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Some integration checks failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please address the issues above before proceeding." -ForegroundColor Yellow
    Write-Host "You may need to run:" -ForegroundColor Yellow
    Write-Host "  • scripts/get_singbox_latest.ps1 (to download sing-box binaries)" -ForegroundColor Yellow
    Write-Host "  • flutter clean && flutter pub get (to refresh dependencies)" -ForegroundColor Yellow
    exit 1
}