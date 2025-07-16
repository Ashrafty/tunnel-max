# TunnelMax VPN - Build and Distribution Guide

This guide provides comprehensive instructions for building and distributing the TunnelMax VPN application for Windows and Android platforms.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Project Setup](#project-setup)
3. [Building for Android](#building-for-android)
4. [Building for Windows](#building-for-windows)
5. [Creating Application Icons](#creating-application-icons)
6. [Distribution](#distribution)
7. [Troubleshooting](#troubleshooting)
8. [Continuous Integration](#continuous-integration)

## Prerequisites

### General Requirements

- **Flutter SDK**: Version 3.8.1 or higher
- **Dart SDK**: Included with Flutter
- **Git**: For version control
- **Code Editor**: VS Code, Android Studio, or IntelliJ IDEA

### Android Development

- **Android Studio**: Latest stable version
- **Android SDK**: API level 21 (Android 5.0) or higher
- **Java Development Kit (JDK)**: Version 11 or higher
- **Android NDK**: Version 27.0.12077973 (for native code)

### Windows Development

- **Visual Studio 2022**: Community, Professional, or Enterprise
- **Windows 10 SDK**: Latest version
- **CMake**: Version 3.14 or higher
- **NSIS** (optional): For creating installers

### Signing and Distribution Tools

- **Java keytool**: For Android keystore generation
- **7-Zip** (optional): For creating portable packages
- **Python 3** (optional): For icon generation scripts

## Project Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd tunnel_max
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Verify Flutter Installation

```bash
flutter doctor
```

Ensure all required components are installed and configured properly.

## Building for Android

### Quick Build

Use the automated build script:

```bash
# Windows Command Prompt
scripts\build_android.bat

# PowerShell
scripts\build_android.ps1
```

### Manual Build Process

#### 1. Clean and Prepare

```bash
flutter clean
flutter pub get
```

#### 2. Generate Icons

```bash
flutter packages pub run flutter_launcher_icons:main
```

#### 3. Build APK

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release
```

### Android Signing Configuration

#### 1. Generate Release Keystore

Run the keystore generation script:

```bash
# Windows
android\keystore\generate_keystore.bat

# Linux/macOS
android/keystore/generate_keystore.sh
```

Or manually create a keystore:

```bash
keytool -genkey -v -keystore android/keystore/release.keystore -alias tunnelmax -keyalg RSA -keysize 2048 -validity 10000
```

#### 2. Configure Environment Variables

Set the following environment variables or add them to `gradle.properties`:

```bash
ANDROID_KEYSTORE_PATH=path/to/keystore/release.keystore
ANDROID_KEYSTORE_PASSWORD=your_keystore_password
ANDROID_KEY_ALIAS=tunnelmax
ANDROID_KEY_PASSWORD=your_key_password
```

#### 3. Build Signed APK

```bash
flutter build apk --release
```

### Android Build Outputs

- **Debug APK**: `build/app/outputs/flutter-apk/app-debug.apk`
- **Release APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`

## Building for Windows

### Quick Build

Use the automated build script:

```bash
# Windows Command Prompt
scripts\build_windows.bat

# PowerShell
scripts\build_windows.ps1
```

### Manual Build Process

#### 1. Clean and Prepare

```bash
flutter clean
flutter pub get
```

#### 2. Generate Icons

```bash
flutter packages pub run flutter_launcher_icons:main
```

#### 3. Build Windows Application

```bash
flutter build windows --release
```

### Creating Windows Installer

#### 1. Install NSIS

Download and install NSIS from [https://nsis.sourceforge.io/](https://nsis.sourceforge.io/)

#### 2. Build Installer

```bash
cd windows/installer
makensis tunnelmax_installer.nsi
```

### Windows Build Outputs

- **Executable**: `build/windows/x64/runner/Release/tunnel_max.exe`
- **Portable Package**: `TunnelMax_VPN_Windows_Portable/`
- **Installer**: `TunnelMax_VPN_Setup_1.0.0.exe`

## Creating Application Icons

### Using Python Script (Recommended)

1. Install Python and Pillow:
   ```bash
   pip install Pillow
   ```

2. Generate placeholder icons:
   ```bash
   python scripts/generate_placeholder_icons.py
   ```

### Manual Icon Creation

1. Create the following icon files in `assets/icons/`:
   - `app_icon.png` (1024x1024px) - Main application icon
   - `app_icon_foreground.png` (432x432px) - Android adaptive icon foreground
   - `app_icon.ico` - Windows icon file

2. Generate Flutter launcher icons:
   ```bash
   flutter packages pub run flutter_launcher_icons:main
   ```

### Icon Requirements

- **Format**: PNG with transparency (ICO for Windows)
- **Main Icon**: 1024x1024 pixels minimum
- **Android Adaptive**: 432x432 pixels (within 108dp safe zone)
- **Windows ICO**: Multiple sizes (16x16, 32x32, 48x48, 256x256)

## Distribution

### Android Distribution

#### Google Play Store

1. Build signed App Bundle:
   ```bash
   flutter build appbundle --release
   ```

2. Upload `app-release.aab` to Google Play Console

3. Follow Google Play Store guidelines for VPN applications

#### Direct APK Distribution

1. Build signed APK:
   ```bash
   flutter build apk --release
   ```

2. Distribute `app-release.apk` through your website or other channels

3. Users must enable "Install from Unknown Sources"

### Windows Distribution

#### Microsoft Store

1. Package the application using MSIX:
   ```bash
   flutter build windows --release
   # Additional MSIX packaging steps required
   ```

2. Submit to Microsoft Store

#### Direct Distribution

1. **Installer**: Distribute `TunnelMax_VPN_Setup_1.0.0.exe`
2. **Portable**: Distribute `TunnelMax_VPN_Windows_v1.0.0_Portable.zip`

### Code Signing

#### Windows Code Signing

1. Obtain a code signing certificate
2. Sign the executable:
   ```bash
   signtool sign /f certificate.p12 /p password /t http://timestamp.digicert.com tunnel_max.exe
   ```

#### Android App Signing

- Use the release keystore for APK signing
- Google Play App Signing is recommended for Play Store distribution

## Troubleshooting

### Common Build Issues

#### Flutter Build Errors

```bash
# Clear Flutter cache
flutter clean
flutter pub get

# Update Flutter
flutter upgrade
```

#### Android Build Issues

1. **Gradle Build Failed**:
   - Check Android SDK installation
   - Verify NDK version compatibility
   - Clear Gradle cache: `./gradlew clean`

2. **Signing Issues**:
   - Verify keystore path and passwords
   - Check environment variables
   - Ensure keystore file exists

#### Windows Build Issues

1. **CMake Errors**:
   - Install Visual Studio Build Tools
   - Verify Windows SDK installation
   - Check CMake version compatibility

2. **Missing Dependencies**:
   - Install Visual C++ Redistributable
   - Verify all required Windows components

### Performance Optimization

#### APK Size Optimization

```bash
# Build with split APKs
flutter build apk --split-per-abi

# Enable ProGuard/R8 (already configured)
flutter build apk --release --obfuscate --split-debug-info=debug-symbols
```

#### Windows Size Optimization

- Use release build configuration
- Remove debug symbols
- Consider UPX compression for executable

## Continuous Integration

### GitHub Actions Example

Create `.github/workflows/build.yml`:

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '11'
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.8.1'
      - run: flutter pub get
      - run: flutter build apk --release
      - uses: actions/upload-artifact@v3
        with:
          name: android-apk
          path: build/app/outputs/flutter-apk/app-release.apk

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.8.1'
      - run: flutter pub get
      - run: flutter build windows --release
      - uses: actions/upload-artifact@v3
        with:
          name: windows-exe
          path: build/windows/x64/runner/Release/
```

### Build Automation Scripts

The provided build scripts can be integrated into CI/CD pipelines:

- `scripts/build_android.bat` / `scripts/build_android.ps1`
- `scripts/build_windows.bat` / `scripts/build_windows.ps1`

## Security Considerations

### Code Protection

1. **Obfuscation**: Enable code obfuscation for release builds
2. **Debug Symbols**: Remove debug symbols from production builds
3. **API Keys**: Store sensitive keys in secure environment variables
4. **Certificate Security**: Protect signing certificates and keystores

### Distribution Security

1. **HTTPS**: Always distribute over secure connections
2. **Checksums**: Provide SHA-256 checksums for downloads
3. **Code Signing**: Sign all distributed executables
4. **Update Mechanism**: Implement secure auto-update functionality

## Version Management

### Updating Version Numbers

1. Update `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2
   ```

2. Update platform-specific version files as needed

3. Tag the release:
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

### Release Notes

Maintain `CHANGELOG.md` with version history and changes.

## Support and Resources

- **Flutter Documentation**: [https://flutter.dev/docs](https://flutter.dev/docs)
- **Android Developer Guide**: [https://developer.android.com/](https://developer.android.com/)
- **Windows App Development**: [https://docs.microsoft.com/en-us/windows/apps/](https://docs.microsoft.com/en-us/windows/apps/)
- **NSIS Documentation**: [https://nsis.sourceforge.io/Docs/](https://nsis.sourceforge.io/Docs/)

For additional support, please refer to the project documentation or create an issue in the repository.