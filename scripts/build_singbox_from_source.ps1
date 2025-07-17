#!/usr/bin/env pwsh
# Build sing-box library from source for Android and Windows
# Inspired by Hiddify's approach

param(
    [string]$Version = "main",
    [switch]$Clean = $false,
    [switch]$AndroidOnly = $false,
    [switch]$WindowsOnly = $false
)

$ErrorActionPreference = "Stop"

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BuildDir = Join-Path $ProjectRoot "build_temp"
$SingboxSrcDir = Join-Path $BuildDir "sing-box"
$AndroidLibDir = Join-Path $ProjectRoot "android/app/src/main/jniLibs"
$WindowsBinDir = Join-Path $ProjectRoot "windows/sing-box"

Write-Host "Building sing-box from source..." -ForegroundColor Green
Write-Host "Version/Branch: $Version" -ForegroundColor Cyan

# Check prerequisites
function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Check Go
    try {
        $GoVersion = & go version 2>&1
        Write-Host "✓ Go: $GoVersion" -ForegroundColor Green
    } catch {
        Write-Error "Go is not installed. Please install Go 1.20+ from https://golang.org/dl/"
        return $false
    }
    
    # Check Git
    try {
        $GitVersion = & git --version 2>&1
        Write-Host "✓ Git: $GitVersion" -ForegroundColor Green
    } catch {
        Write-Error "Git is not installed. Please install Git."
        return $false
    }
    
    # Check Android NDK (if building for Android)
    if (-not $WindowsOnly) {
        if (-not $env:ANDROID_NDK_HOME -and -not $env:NDK_ROOT) {
            Write-Warning "Android NDK not found. Set ANDROID_NDK_HOME or NDK_ROOT environment variable."
            Write-Host "You can install it via Android Studio SDK Manager or download from:"
            Write-Host "https://developer.android.com/ndk/downloads"
            return $false
        } else {
            $NdkPath = if ($env:ANDROID_NDK_HOME) { $env:ANDROID_NDK_HOME } else { $env:NDK_ROOT }
            Write-Host "✓ Android NDK: $NdkPath" -ForegroundColor Green
        }
    }
    
    return $true
}

# Clone or update sing-box source
function Get-SingboxSource {
    Write-Host "Getting sing-box source code..." -ForegroundColor Yellow
    
    if (Test-Path $SingboxSrcDir) {
        if ($Clean) {
            Write-Host "Cleaning existing source..." -ForegroundColor Cyan
            Remove-Item -Recurse -Force $SingboxSrcDir
        } else {
            Write-Host "Updating existing source..." -ForegroundColor Cyan
            Set-Location $SingboxSrcDir
            & git fetch origin
            & git checkout $Version
            & git pull origin $Version
            Set-Location $ProjectRoot
            return
        }
    }
    
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
    Set-Location $BuildDir
    
    Write-Host "Cloning sing-box repository..." -ForegroundColor Cyan
    & git clone https://github.com/SagerNet/sing-box.git
    
    Set-Location $SingboxSrcDir
    & git checkout $Version
    
    Set-Location $ProjectRoot
}

# Build Android libraries
function Build-AndroidLibraries {
    Write-Host "Building Android libraries..." -ForegroundColor Yellow
    
    $NdkPath = if ($env:ANDROID_NDK_HOME) { $env:ANDROID_NDK_HOME } else { $env:NDK_ROOT }
    
    # Create output directories
    New-Item -ItemType Directory -Path "$AndroidLibDir/arm64-v8a" -Force | Out-Null
    New-Item -ItemType Directory -Path "$AndroidLibDir/armeabi-v7a" -Force | Out-Null
    New-Item -ItemType Directory -Path "$AndroidLibDir/x86" -Force | Out-Null
    New-Item -ItemType Directory -Path "$AndroidLibDir/x86_64" -Force | Out-Null
    
    Set-Location $SingboxSrcDir
    
    # Set up Go environment for cross-compilation
    $env:CGO_ENABLED = "1"
    
    # Build for ARM64
    Write-Host "Building for Android ARM64..." -ForegroundColor Cyan
    $env:GOOS = "android"
    $env:GOARCH = "arm64"
    $env:CC = "$NdkPath/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android21-clang"
    $env:CXX = "$NdkPath/toolchains/llvm/prebuilt/windows-x86_64/bin/aarch64-linux-android21-clang++"
    
    & go build -buildmode=c-shared -o "$AndroidLibDir/arm64-v8a/libsing-box.so" ./cmd/sing-box
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ ARM64 library built successfully" -ForegroundColor Green
    } else {
        Write-Error "Failed to build ARM64 library"
    }
    
    # Build for ARM
    Write-Host "Building for Android ARM..." -ForegroundColor Cyan
    $env:GOARCH = "arm"
    $env:GOARM = "7"
    $env:CC = "$NdkPath/toolchains/llvm/prebuilt/windows-x86_64/bin/armv7a-linux-androideabi21-clang"
    $env:CXX = "$NdkPath/toolchains/llvm/prebuilt/windows-x86_64/bin/armv7a-linux-androideabi21-clang++"
    
    & go build -buildmode=c-shared -o "$AndroidLibDir/armeabi-v7a/libsing-box.so" ./cmd/sing-box
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ ARM library built successfully" -ForegroundColor Green
    } else {
        Write-Error "Failed to build ARM library"
    }
    
    # Build for x86_64 (for emulator)
    Write-Host "Building for Android x86_64..." -ForegroundColor Cyan
    $env:GOARCH = "amd64"
    $env:CC = "$NdkPath/toolchains/llvm/prebuilt/windows-x86_64/bin/x86_64-linux-android21-clang"
    $env:CXX = "$NdkPath/toolchains/llvm/prebuilt/windows-x86_64/bin/x86_64-linux-android21-clang++"
    
    & go build -buildmode=c-shared -o "$AndroidLibDir/x86_64/libsing-box.so" ./cmd/sing-box
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ x86_64 library built successfully" -ForegroundColor Green
    } else {
        Write-Warning "Failed to build x86_64 library (emulator support)"
    }
    
    Set-Location $ProjectRoot
}

# Build Windows executable
function Build-WindowsExecutable {
    Write-Host "Building Windows executable..." -ForegroundColor Yellow
    
    New-Item -ItemType Directory -Path $WindowsBinDir -Force | Out-Null
    
    Set-Location $SingboxSrcDir
    
    # Reset environment for Windows build
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    $env:CGO_ENABLED = "1"
    Remove-Item Env:CC -ErrorAction SilentlyContinue
    Remove-Item Env:CXX -ErrorAction SilentlyContinue
    
    Write-Host "Building Windows executable..." -ForegroundColor Cyan
    & go build -o "$WindowsBinDir/sing-box.exe" ./cmd/sing-box
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Windows executable built successfully" -ForegroundColor Green
        
        # Test the executable
        try {
            $TestOutput = & "$WindowsBinDir/sing-box.exe" version
            Write-Host "✓ Windows executable test: $TestOutput" -ForegroundColor Green
        } catch {
            Write-Warning "Windows executable built but version test failed"
        }
    } else {
        Write-Error "Failed to build Windows executable"
    }
    
    Set-Location $ProjectRoot
}

# Create Go wrapper for JNI integration
function Create-GoWrapper {
    Write-Host "Creating Go wrapper for JNI integration..." -ForegroundColor Yellow
    
    $WrapperDir = Join-Path $SingboxSrcDir "jni_wrapper"
    New-Item -ItemType Directory -Path $WrapperDir -Force | Out-Null
    
    # Create the JNI wrapper Go file
    $WrapperContent = @"
package main

import "C"
import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "os"
    "sync"
    
    "github.com/sagernet/sing-box"
    "github.com/sagernet/sing-box/option"
)

var (
    instance *box.Box
    mutex    sync.RWMutex
    ctx      context.Context
    cancel   context.CancelFunc
)

//export singbox_init
func singbox_init() int {
    mutex.Lock()
    defer mutex.Unlock()
    
    if instance != nil {
        return 1 // Already initialized
    }
    
    ctx, cancel = context.WithCancel(context.Background())
    log.Println("Sing-box JNI wrapper initialized")
    return 1
}

//export singbox_start
func singbox_start(configJson *C.char, tunFd C.int) int {
    mutex.Lock()
    defer mutex.Unlock()
    
    if instance != nil {
        return 0 // Already running
    }
    
    configStr := C.GoString(configJson)
    
    var options option.Options
    if err := json.Unmarshal([]byte(configStr), &options); err != nil {
        log.Printf("Failed to parse config: %v", err)
        return 0
    }
    
    // Set TUN file descriptor if provided
    if tunFd >= 0 {
        // Configure TUN interface with the provided file descriptor
        for i, inbound := range options.Inbounds {
            if inbound.Type == "tun" {
                if options.Inbounds[i].TunOptions.FileDescriptor == 0 {
                    options.Inbounds[i].TunOptions.FileDescriptor = int(tunFd)
                }
            }
        }
    }
    
    var err error
    instance, err = box.New(box.Options{
        Context: ctx,
        Options: options,
    })
    if err != nil {
        log.Printf("Failed to create sing-box instance: %v", err)
        return 0
    }
    
    err = instance.Start()
    if err != nil {
        log.Printf("Failed to start sing-box: %v", err)
        instance.Close()
        instance = nil
        return 0
    }
    
    log.Println("Sing-box started successfully")
    return 1
}

//export singbox_stop
func singbox_stop() int {
    mutex.Lock()
    defer mutex.Unlock()
    
    if instance == nil {
        return 1 // Already stopped
    }
    
    instance.Close()
    instance = nil
    
    if cancel != nil {
        cancel()
    }
    
    log.Println("Sing-box stopped")
    return 1
}

//export singbox_is_running
func singbox_is_running() int {
    mutex.RLock()
    defer mutex.RUnlock()
    
    if instance != nil {
        return 1
    }
    return 0
}

//export singbox_get_stats
func singbox_get_stats() *C.char {
    mutex.RLock()
    defer mutex.RUnlock()
    
    if instance == nil {
        return nil
    }
    
    // Get statistics from sing-box
    // This is a simplified version - you may need to implement proper stats collection
    stats := map[string]interface{}{
        "upload_bytes":     0,
        "download_bytes":   0,
        "upload_speed":     0.0,
        "download_speed":   0.0,
        "connection_time":  0,
        "packets_sent":     0,
        "packets_received": 0,
    }
    
    statsJson, _ := json.Marshal(stats)
    return C.CString(string(statsJson))
}

//export singbox_cleanup
func singbox_cleanup() {
    singbox_stop()
    log.Println("Sing-box cleanup completed")
}

func main() {
    // Required for building as shared library
}
"@
    
    Set-Content -Path "$WrapperDir/main.go" -Value $WrapperContent
    
    # Create go.mod for the wrapper
    Set-Location $WrapperDir
    & go mod init jni_wrapper
    & go mod edit -replace github.com/sagernet/sing-box=../
    & go mod tidy
    
    Set-Location $ProjectRoot
}

# Main execution
try {
    if (-not (Test-Prerequisites)) {
        exit 1
    }
    
    Get-SingboxSource
    Create-GoWrapper
    
    if (-not $WindowsOnly) {
        Build-AndroidLibraries
    }
    
    if (-not $AndroidOnly) {
        Build-WindowsExecutable
    }
    
    Write-Host ""
    Write-Host "Build completed successfully!" -ForegroundColor Green
    Write-Host "Built files:" -ForegroundColor Cyan
    
    if (-not $WindowsOnly) {
        if (Test-Path "$AndroidLibDir/arm64-v8a/libsing-box.so") {
            $Size = (Get-Item "$AndroidLibDir/arm64-v8a/libsing-box.so").Length
            Write-Host "  Android ARM64: $AndroidLibDir/arm64-v8a/libsing-box.so ($Size bytes)" -ForegroundColor White
        }
        if (Test-Path "$AndroidLibDir/armeabi-v7a/libsing-box.so") {
            $Size = (Get-Item "$AndroidLibDir/armeabi-v7a/libsing-box.so").Length
            Write-Host "  Android ARM: $AndroidLibDir/armeabi-v7a/libsing-box.so ($Size bytes)" -ForegroundColor White
        }
    }
    
    if (-not $AndroidOnly) {
        if (Test-Path "$WindowsBinDir/sing-box.exe") {
            $Size = (Get-Item "$WindowsBinDir/sing-box.exe").Length
            Write-Host "  Windows: $WindowsBinDir/sing-box.exe ($Size bytes)" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. The native libraries are now built from source" -ForegroundColor White
    Write-Host "2. Build your Android app - it will use the real libsing-box.so" -ForegroundColor White
    Write-Host "3. Test VPN connections with actual protocols!" -ForegroundColor White
    
} catch {
    Write-Error "Build failed: $_"
    exit 1
} finally {
    # Cleanup environment variables
    Remove-Item Env:GOOS -ErrorAction SilentlyContinue
    Remove-Item Env:GOARCH -ErrorAction SilentlyContinue
    Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue
    Remove-Item Env:CC -ErrorAction SilentlyContinue
    Remove-Item Env:CXX -ErrorAction SilentlyContinue
    Remove-Item Env:GOARM -ErrorAction SilentlyContinue
}