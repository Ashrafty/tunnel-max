@echo off
REM Build script for TunnelMax VPN Windows application
REM This script builds the Windows executable and creates an installer

echo Building TunnelMax VPN for Windows...
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Flutter is not installed or not in PATH.
    echo Please install Flutter from https://flutter.dev/
    pause
    exit /b 1
)

REM Check if Visual Studio Build Tools are available
where msbuild >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Warning: MSBuild not found in PATH.
    echo Make sure Visual Studio Build Tools are installed.
    echo Continuing with Flutter build...
)

REM Clean previous builds
echo Cleaning previous builds...
flutter clean
flutter pub get

REM Generate launcher icons
echo Generating launcher icons...
flutter packages pub run flutter_launcher_icons:main

REM Build Windows release
echo.
echo Building Windows release...
flutter build windows --release

if %ERRORLEVEL% NEQ 0 (
    echo Error: Windows build failed.
    pause
    exit /b 1
)

echo Windows build completed successfully!
echo Location: build\windows\x64\runner\Release\

REM Check if executable exists
if not exist "build\windows\x64\runner\Release\tunnel_max.exe" (
    echo Error: Executable not found at expected location.
    pause
    exit /b 1
)

REM Create portable package
echo.
echo Creating portable package...
set PORTABLE_DIR=TunnelMax_VPN_Windows_Portable
if exist "%PORTABLE_DIR%" rmdir /s /q "%PORTABLE_DIR%"
mkdir "%PORTABLE_DIR%"

REM Copy all necessary files
xcopy "build\windows\x64\runner\Release\*" "%PORTABLE_DIR%\" /E /I /H /Y

if %ERRORLEVEL% EQU 0 (
    echo Portable package created: %PORTABLE_DIR%\
    
    REM Create ZIP archive if 7-Zip is available
    where 7z >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        echo Creating ZIP archive...
        7z a -tzip "TunnelMax_VPN_Windows_v1.0.0_Portable.zip" "%PORTABLE_DIR%\*"
        echo ZIP archive created: TunnelMax_VPN_Windows_v1.0.0_Portable.zip
    ) else (
        echo 7-Zip not found. Skipping ZIP creation.
        echo You can manually compress the %PORTABLE_DIR% folder.
    )
) else (
    echo Error: Failed to create portable package.
)

REM Build installer if NSIS is available
echo.
echo Checking for NSIS installer...
where makensis >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo Building Windows installer...
    cd windows\installer
    makensis tunnelmax_installer.nsi
    
    if %ERRORLEVEL% EQU 0 (
        echo Installer created successfully!
        move "TunnelMax_VPN_Setup_1.0.0.exe" "..\..\TunnelMax_VPN_Setup_1.0.0.exe"
        echo Installer location: TunnelMax_VPN_Setup_1.0.0.exe
    ) else (
        echo Error: Installer creation failed.
    )
    cd ..\..
) else (
    echo NSIS not found. Skipping installer creation.
    echo Install NSIS from https://nsis.sourceforge.io/ to create installers.
)

echo.
echo Windows build completed!
echo.
echo Files created:
if exist "%PORTABLE_DIR%" echo - %PORTABLE_DIR%\ (Portable application folder)
if exist "TunnelMax_VPN_Windows_v1.0.0_Portable.zip" echo - TunnelMax_VPN_Windows_v1.0.0_Portable.zip (Portable ZIP)
if exist "TunnelMax_VPN_Setup_1.0.0.exe" echo - TunnelMax_VPN_Setup_1.0.0.exe (Windows Installer)
echo.

REM Show executable information
if exist "build\windows\x64\runner\Release\tunnel_max.exe" (
    echo Executable Information:
    powershell -Command "(Get-Item 'build\windows\x64\runner\Release\tunnel_max.exe').VersionInfo | Select-Object FileVersion, ProductVersion, CompanyName, FileDescription"
    echo.
)

echo Build process completed!
pause