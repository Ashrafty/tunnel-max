@echo off
echo ===================================
echo Native Library Configuration Test
echo ===================================
echo.

echo Checking application directory...
if exist "%~dp0tunnel_max.exe" (
    echo [OK] Application executable found
) else (
    echo [WARNING] Application executable not found
)

echo.
echo Checking sing-box executable...
if exist "%~dp0sing-box.exe" (
    echo [OK] sing-box.exe found in application directory
    for %%A in ("%~dp0sing-box.exe") do echo     Size: %%~zA bytes
) else (
    echo [INFO] sing-box.exe not found in application directory
    echo Checking alternative locations...
    
    if exist "%~dp0bin\sing-box.exe" (
        echo [OK] sing-box.exe found in bin directory
        for %%A in ("%~dp0bin\sing-box.exe") do echo     Size: %%~zA bytes
    ) else if exist "%~dp0sing-box\sing-box.exe" (
        echo [OK] sing-box.exe found in sing-box directory
        for %%A in ("%~dp0sing-box\sing-box.exe") do echo     Size: %%~zA bytes
    ) else if exist "%~dp0native\sing-box.exe" (
        echo [OK] sing-box.exe found in native directory
        for %%A in ("%~dp0native\sing-box.exe") do echo     Size: %%~zA bytes
    ) else (
        echo [ERROR] sing-box.exe not found in any expected location
        echo.
        echo Expected locations:
        echo   - %~dp0sing-box.exe
        echo   - %~dp0bin\sing-box.exe
        echo   - %~dp0sing-box\sing-box.exe
        echo   - %~dp0native\sing-box.exe
        echo.
        echo Please run setup_singbox_binaries.ps1 to download sing-box
    )
)

echo.
echo Checking required system libraries...
powershell -Command "try { [System.Reflection.Assembly]::LoadWithPartialName('System.Net.NetworkInformation') | Out-Null; Write-Host '[OK] Network libraries available' } catch { Write-Host '[ERROR] Network libraries not available' }"

echo.
echo Checking Windows version compatibility...
for /f "tokens=2 delims=[]" %%G in ('ver') do set winver=%%G
echo Windows version: %winver%

echo.
echo Native library configuration validation complete.
echo ===================================
pause