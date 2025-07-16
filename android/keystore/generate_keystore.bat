@echo off
REM Script to generate Android release keystore
REM Run this script to create a release keystore for signing APKs

echo Generating Android release keystore...
echo.
echo Please provide the following information:
echo.

set /p KEYSTORE_PASSWORD="Enter keystore password: "
set /p KEY_ALIAS="Enter key alias (default: tunnelmax): "
if "%KEY_ALIAS%"=="" set KEY_ALIAS=tunnelmax
set /p KEY_PASSWORD="Enter key password: "
set /p DNAME_CN="Enter your name or organization: "
set /p DNAME_OU="Enter organizational unit (optional): "
set /p DNAME_O="Enter organization (optional): "
set /p DNAME_L="Enter city/locality (optional): "
set /p DNAME_ST="Enter state/province (optional): "
set /p DNAME_C="Enter country code (2 letters, optional): "

REM Build the distinguished name
set DNAME="CN=%DNAME_CN%"
if not "%DNAME_OU%"=="" set DNAME=%DNAME%, OU=%DNAME_OU%
if not "%DNAME_O%"=="" set DNAME=%DNAME%, O=%DNAME_O%
if not "%DNAME_L%"=="" set DNAME=%DNAME%, L=%DNAME_L%
if not "%DNAME_ST%"=="" set DNAME=%DNAME%, ST=%DNAME_ST%
if not "%DNAME_C%"=="" set DNAME=%DNAME%, C=%DNAME_C%

echo.
echo Generating keystore with the following details:
echo Keystore: release.keystore
echo Key Alias: %KEY_ALIAS%
echo Distinguished Name: %DNAME%
echo.

keytool -genkey -v -keystore release.keystore -alias %KEY_ALIAS% -keyalg RSA -keysize 2048 -validity 10000 -storepass %KEYSTORE_PASSWORD% -keypass %KEY_PASSWORD% -dname %DNAME%

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Keystore generated successfully!
    echo.
    echo To use this keystore for release builds, set the following environment variables:
    echo set ANDROID_KEYSTORE_PATH=%CD%\release.keystore
    echo set ANDROID_KEYSTORE_PASSWORD=%KEYSTORE_PASSWORD%
    echo set ANDROID_KEY_ALIAS=%KEY_ALIAS%
    echo set ANDROID_KEY_PASSWORD=%KEY_PASSWORD%
    echo.
    echo Or add them to your gradle.properties file:
    echo ANDROID_KEYSTORE_PATH=%CD%\release.keystore
    echo ANDROID_KEYSTORE_PASSWORD=%KEYSTORE_PASSWORD%
    echo ANDROID_KEY_ALIAS=%KEY_ALIAS%
    echo ANDROID_KEY_PASSWORD=%KEY_PASSWORD%
) else (
    echo.
    echo Failed to generate keystore. Please check that Java keytool is installed and in your PATH.
)

pause