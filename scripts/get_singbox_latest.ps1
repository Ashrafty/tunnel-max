#!/usr/bin/env pwsh
# Get the latest sing-box release and download it

$ErrorActionPreference = "Stop"

Write-Host "Fetching latest sing-box release information..." -ForegroundColor Green

try {
    # Get latest release info from GitHub API
    $ApiUrl = "https://api.github.com/repos/SagerNet/sing-box/releases/latest"
    $Release = Invoke-RestMethod -Uri $ApiUrl -UseBasicParsing
    
    $LatestVersion = $Release.tag_name.TrimStart('v')
    Write-Host "Latest version: $LatestVersion" -ForegroundColor Cyan
    
    # Find the assets we need
    $AndroidArm64Asset = $Release.assets | Where-Object { $_.name -like "*android-arm64*" }
    $AndroidArmAsset = $Release.assets | Where-Object { $_.name -like "*android-arm*" -and $_.name -notlike "*arm64*" }
    $WindowsAsset = $Release.assets | Where-Object { $_.name -like "*windows-amd64*" }
    
    Write-Host "Available assets:" -ForegroundColor Yellow
    foreach ($asset in $Release.assets) {
        Write-Host "  - $($asset.name)" -ForegroundColor White
    }
    
    if ($AndroidArm64Asset) {
        Write-Host "Android ARM64: $($AndroidArm64Asset.name)" -ForegroundColor Green
        Write-Host "Download URL: $($AndroidArm64Asset.browser_download_url)" -ForegroundColor Gray
    }
    
    if ($AndroidArmAsset) {
        Write-Host "Android ARM: $($AndroidArmAsset.name)" -ForegroundColor Green
        Write-Host "Download URL: $($AndroidArmAsset.browser_download_url)" -ForegroundColor Gray
    }
    
    if ($WindowsAsset) {
        Write-Host "Windows: $($WindowsAsset.name)" -ForegroundColor Green
        Write-Host "Download URL: $($WindowsAsset.browser_download_url)" -ForegroundColor Gray
    }
    
    # Now download them
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ProjectRoot = Split-Path -Parent $ScriptDir
    $AndroidLibDir = Join-Path $ProjectRoot "android/app/src/main/jniLibs"
    $WindowsBinDir = Join-Path $ProjectRoot "windows/sing-box"
    $TempDir = Join-Path $ProjectRoot "temp_singbox_download"
    
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
    
    # Download Android ARM64
    if ($AndroidArm64Asset) {
        Write-Host "Downloading Android ARM64..." -ForegroundColor Cyan
        $Arm64File = Join-Path $TempDir $AndroidArm64Asset.name
        Invoke-WebRequest -Uri $AndroidArm64Asset.browser_download_url -OutFile $Arm64File -UseBasicParsing
        
        # Extract
        $ExtractDir = Join-Path $TempDir "arm64-extract"
        New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
        
        $CurrentLocation = Get-Location
        Set-Location $ExtractDir
        & tar -xzf $Arm64File
        Set-Location $CurrentLocation
        
        # Find sing-box binary and copy it
        $SingboxBinary = Get-ChildItem -Path $ExtractDir -Recurse -Name "sing-box" -File | Select-Object -First 1
        if ($SingboxBinary) {
            $SourcePath = Join-Path $ExtractDir $SingboxBinary
            $DestPath = Join-Path $AndroidLibDir "arm64-v8a/libsing-box.so"
            Copy-Item $SourcePath $DestPath -Force
            Write-Host "ARM64 binary installed successfully" -ForegroundColor Green
        }
    }
    
    # Download Android ARM
    if ($AndroidArmAsset) {
        Write-Host "Downloading Android ARM..." -ForegroundColor Cyan
        $ArmFile = Join-Path $TempDir $AndroidArmAsset.name
        Invoke-WebRequest -Uri $AndroidArmAsset.browser_download_url -OutFile $ArmFile -UseBasicParsing
        
        # Extract
        $ExtractDir = Join-Path $TempDir "arm-extract"
        New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
        
        $CurrentLocation = Get-Location
        Set-Location $ExtractDir
        & tar -xzf $ArmFile
        Set-Location $CurrentLocation
        
        # Find sing-box binary and copy it
        $SingboxBinary = Get-ChildItem -Path $ExtractDir -Recurse -Name "sing-box" -File | Select-Object -First 1
        if ($SingboxBinary) {
            $SourcePath = Join-Path $ExtractDir $SingboxBinary
            $DestPath = Join-Path $AndroidLibDir "armeabi-v7a/libsing-box.so"
            Copy-Item $SourcePath $DestPath -Force
            Write-Host "ARM binary installed successfully" -ForegroundColor Green
        }
    }
    
    # Download Windows
    if ($WindowsAsset) {
        Write-Host "Downloading Windows..." -ForegroundColor Cyan
        $WindowsFile = Join-Path $TempDir $WindowsAsset.name
        Invoke-WebRequest -Uri $WindowsAsset.browser_download_url -OutFile $WindowsFile -UseBasicParsing
        
        # Extract
        $ExtractDir = Join-Path $TempDir "windows-extract"
        New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null
        
        Expand-Archive -Path $WindowsFile -DestinationPath $ExtractDir -Force
        
        # Find sing-box.exe and copy it
        $SingboxExe = Get-ChildItem -Path $ExtractDir -Recurse -Name "sing-box.exe" -File | Select-Object -First 1
        if ($SingboxExe) {
            $SourcePath = Join-Path $ExtractDir $SingboxExe
            $DestPath = Join-Path $WindowsBinDir "sing-box.exe"
            Copy-Item $SourcePath $DestPath -Force
            Write-Host "Windows binary installed successfully" -ForegroundColor Green
            
            # Test it
            try {
                $TestOutput = & $DestPath version 2>&1
                Write-Host "Windows binary test: $TestOutput" -ForegroundColor Green
            } catch {
                Write-Host "Windows binary installed but test failed" -ForegroundColor Yellow
            }
        }
    }
    
    Write-Host ""
    Write-Host "REAL sing-box binaries installed successfully!" -ForegroundColor Green
    Write-Host "Version: $LatestVersion" -ForegroundColor Yellow
    
} catch {
    Write-Error "Failed to download sing-box: $_"
} finally {
    # Cleanup
    if (Test-Path $TempDir) {
        Remove-Item -Recurse -Force $TempDir
    }
}