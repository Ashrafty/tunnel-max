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
      - "v*"

jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          distribution: "zulu"
          java-version: "11"
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.8.1"
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
          flutter-version: "3.8.1"
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

# TunnelMax VPN - Deployment Guide

This guide covers the deployment and distribution strategies for TunnelMax VPN across different platforms and channels.

## Table of Contents

1. [Deployment Overview](#deployment-overview)
2. [Android Deployment](#android-deployment)
3. [Windows Deployment](#windows-deployment)
4. [Release Management](#release-management)
5. [Distribution Channels](#distribution-channels)
6. [Security and Compliance](#security-and-compliance)
7. [Monitoring and Analytics](#monitoring-and-analytics)

## Deployment Overview

TunnelMax VPN supports multiple deployment strategies to reach users across different platforms and distribution preferences.

### Supported Platforms

- **Android**: API level 21+ (Android 5.0+)
- **Windows**: Windows 10/11 (x64)

### Distribution Methods

- **Official App Stores**: Google Play Store, Microsoft Store
- **Direct Distribution**: Website downloads, enterprise distribution
- **Sideloading**: APK installation, portable executables

## Android Deployment

### Google Play Store Deployment

#### Prerequisites

1. **Google Play Console Account**: Developer account with $25 registration fee
2. **App Signing**: Configure Google Play App Signing (recommended)
3. **Content Rating**: Complete content rating questionnaire
4. **Privacy Policy**: Required for VPN applications

#### Deployment Steps

1. **Prepare Release Build**:

   ```bash
   flutter build appbundle --release
   ```

2. **Upload to Play Console**:

   - Navigate to Google Play Console
   - Create new application or select existing
   - Upload `app-release.aab` file
   - Complete store listing information

3. **Configure Release**:

   - Set up release tracks (internal, alpha, beta, production)
   - Configure rollout percentage
   - Add release notes

4. **Review and Publish**:
   - Submit for review
   - Monitor review status
   - Publish when approved

#### Play Store Requirements for VPN Apps

- **VPN Policy Compliance**: Must comply with Google Play VPN policy
- **Privacy Policy**: Detailed privacy policy required
- **Data Safety**: Complete Data Safety section
- **Target Audience**: Appropriate age rating
- **Restricted Content**: May require additional verification

### Direct APK Distribution

#### Signed APK Creation

1. **Generate Release Keystore** (one-time setup):

   ```bash
   keytool -genkey -v -keystore release.keystore -alias tunnelmax -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **Build Signed APK**:

   ```bash
   flutter build apk --release
   ```

3. **Verify APK Signature**:
   ```bash
   jarsigner -verify -verbose -certs app-release.apk
   ```

#### Distribution Considerations

- **Website Hosting**: Secure HTTPS hosting required
- **Download Security**: Provide SHA-256 checksums
- **Installation Instructions**: Guide users through sideloading process
- **Update Mechanism**: Implement in-app update notifications

### Enterprise Distribution

#### Android Enterprise

1. **Managed Google Play**: Upload private app to managed Google Play
2. **EMM Integration**: Work with Enterprise Mobility Management providers
3. **App Wrapping**: Consider MAM (Mobile Application Management) wrapping

#### Custom Distribution

- **Internal App Sharing**: Use Google Play Console for internal testing
- **Firebase App Distribution**: Beta testing and internal distribution
- **Custom MDM**: Integration with Mobile Device Management solutions

## Windows Deployment

### Microsoft Store Deployment

#### Prerequisites

1. **Microsoft Partner Center Account**: Developer account required
2. **App Certification**: Pass Windows App Certification Kit
3. **MSIX Packaging**: Package app in MSIX format
4. **Code Signing**: Valid code signing certificate

#### Deployment Steps

1. **Create MSIX Package**:

   ```bash
   # Additional tooling required for MSIX packaging
   # This is beyond the current Flutter Windows support
   ```

2. **Submit to Store**:
   - Upload MSIX package to Partner Center
   - Complete store listing
   - Submit for certification

#### Store Requirements

- **Windows 10/11 Compatibility**: Target appropriate Windows versions
- **Security Compliance**: Pass security and privacy requirements
- **Accessibility**: Meet accessibility standards
- **Performance**: Meet performance benchmarks

### Direct Windows Distribution

#### Installer Distribution

1. **Build Windows Installer**:

   ```bash
   scripts\build_windows.bat
   ```

2. **Code Signing** (recommended):

   ```bash
   signtool sign /f certificate.p12 /p password /t http://timestamp.digicert.com TunnelMax_VPN_Setup_1.0.0.exe
   ```

3. **Distribution**:
   - Host installer on secure website
   - Provide installation instructions
   - Include system requirements

#### Portable Distribution

1. **Create Portable Package**:

   - Build release executable
   - Package with dependencies
   - Create ZIP archive

2. **Distribution Benefits**:
   - No installation required
   - Suitable for restricted environments
   - Easy to deploy in enterprise settings

### Windows Update Mechanisms

#### Auto-Update Implementation

1. **Update Server**: Host update manifests and files
2. **Version Checking**: Implement version comparison logic
3. **Download and Install**: Secure update download and installation
4. **Rollback Capability**: Ability to rollback failed updates

## Release Management

### Version Numbering

Follow semantic versioning (SemVer):

- **Major.Minor.Patch** (e.g., 1.2.3)
- **Build Number**: Increment for each build

### Release Channels

#### Android Release Tracks

1. **Internal Testing**: Internal team testing
2. **Alpha**: Limited external testing
3. **Beta**: Broader testing group
4. **Production**: Public release

#### Windows Release Channels

1. **Development**: Internal builds
2. **Beta**: Public beta testing
3. **Stable**: Production release
4. **LTS**: Long-term support versions

### Release Process

1. **Code Freeze**: Stop feature development
2. **Testing**: Comprehensive testing phase
3. **Release Candidate**: Create RC builds
4. **Final Testing**: Last-minute verification
5. **Release**: Deploy to production
6. **Post-Release**: Monitor and hotfix if needed

### Rollback Strategy

- **Staged Rollout**: Gradual release to percentage of users
- **Monitoring**: Real-time crash and performance monitoring
- **Quick Rollback**: Ability to quickly revert problematic releases
- **Hotfix Process**: Fast-track critical bug fixes

## Distribution Channels

### Primary Channels

1. **Official Website**: Primary download location
2. **App Stores**: Google Play, Microsoft Store
3. **GitHub Releases**: Open source distribution
4. **Enterprise Portals**: B2B distribution

### Alternative Channels

1. **Third-Party Stores**: F-Droid (Android), Chocolatey (Windows)
2. **Package Managers**: Winget, Scoop (Windows)
3. **Enterprise App Catalogs**: Corporate distribution
4. **OEM Partnerships**: Pre-installation agreements

### Channel-Specific Considerations

#### Google Play Store

- **Review Process**: 1-3 days typical review time
- **Policy Compliance**: Strict VPN policy requirements
- **Revenue Sharing**: 30% platform fee (15% for first $1M)
- **Global Reach**: Available in 190+ countries

#### Microsoft Store

- **Certification**: Automated and manual testing
- **Distribution**: Global availability
- **Revenue Sharing**: 30% platform fee
- **Enterprise**: Business store integration

#### Direct Distribution

- **Full Control**: Complete control over distribution
- **No Platform Fees**: Keep 100% of revenue
- **Marketing Responsibility**: Handle all marketing and discovery
- **Support Burden**: Direct customer support responsibility

## Security and Compliance

### Code Signing

#### Android APK Signing

1. **Release Keystore**: Secure storage of signing keys
2. **Key Rotation**: Plan for key rotation if compromised
3. **Google Play App Signing**: Let Google manage signing keys

#### Windows Code Signing

1. **Certificate Authority**: Obtain certificate from trusted CA
2. **Timestamping**: Include timestamp for long-term validity
3. **Hardware Security Module**: Consider HSM for key protection

### Compliance Requirements

#### Privacy Regulations

- **GDPR**: European Union privacy regulation
- **CCPA**: California Consumer Privacy Act
- **COPPA**: Children's Online Privacy Protection Act

#### VPN-Specific Regulations

- **Country Restrictions**: Some countries restrict VPN usage
- **Data Retention**: Comply with local data retention laws
- **Encryption Standards**: Meet required encryption standards

### Security Best Practices

1. **Secure Distribution**: HTTPS for all downloads
2. **Integrity Verification**: Provide checksums and signatures
3. **Update Security**: Secure update mechanisms
4. **Vulnerability Management**: Regular security assessments

## Monitoring and Analytics

### Deployment Metrics

1. **Download Statistics**: Track download numbers and sources
2. **Installation Success**: Monitor installation completion rates
3. **Update Adoption**: Track update installation rates
4. **Geographic Distribution**: Understand user distribution

### Performance Monitoring

1. **Crash Reporting**: Firebase Crashlytics, Sentry
2. **Performance Metrics**: App startup time, memory usage
3. **Network Performance**: Connection success rates, speed tests
4. **User Engagement**: Feature usage, session duration

### Analytics Tools

#### Mobile Analytics

- **Firebase Analytics**: Comprehensive mobile analytics
- **Google Analytics**: Web and app analytics
- **Mixpanel**: Event-based analytics

#### Windows Analytics

- **Application Insights**: Microsoft's analytics platform
- **Custom Analytics**: Build custom analytics solution
- **Telemetry**: Windows telemetry integration

### Privacy-Compliant Analytics

1. **Data Minimization**: Collect only necessary data
2. **User Consent**: Obtain proper consent for data collection
3. **Anonymization**: Anonymize personal data
4. **Opt-Out Options**: Provide analytics opt-out mechanisms

## Deployment Automation

### CI/CD Pipeline

#### GitHub Actions Example

```yaml
name: Deploy Release

on:
  push:
    tags:
      - "v*"

jobs:
  deploy-android:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Play Store
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.GOOGLE_PLAY_SERVICE_ACCOUNT }}
          packageName: com.tunnelmax.vpnclient
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: production

  deploy-windows:
    runs-on: windows-latest
    steps:
      - name: Build and Deploy
        run: |
          scripts/build_windows.ps1
          # Upload to distribution server
```

### Automated Testing

1. **Unit Tests**: Automated unit test execution
2. **Integration Tests**: End-to-end testing
3. **UI Tests**: Automated UI testing
4. **Performance Tests**: Automated performance benchmarks

### Deployment Verification

1. **Smoke Tests**: Basic functionality verification
2. **Health Checks**: Service availability monitoring
3. **Rollback Triggers**: Automated rollback conditions
4. **Success Metrics**: Define deployment success criteria

## Troubleshooting Deployment Issues

### Common Android Issues

1. **Play Console Rejection**: Review policy violations
2. **APK Upload Errors**: Check file format and signing
3. **Version Conflicts**: Ensure version code increments
4. **Permission Issues**: Review permission declarations

### Common Windows Issues

1. **Code Signing Errors**: Verify certificate validity
2. **Installer Issues**: Test on clean Windows installations
3. **Antivirus False Positives**: Submit to antivirus vendors
4. **Compatibility Issues**: Test on different Windows versions

### Resolution Strategies

1. **Documentation**: Maintain troubleshooting guides
2. **Support Channels**: Provide multiple support options
3. **Community Forums**: Enable community support
4. **Escalation Process**: Clear escalation procedures

## Post-Deployment Activities

### Launch Activities

1. **Announcement**: Coordinate launch announcements
2. **Press Release**: Prepare media communications
3. **Social Media**: Social media campaign
4. **Documentation**: Update user documentation

### Ongoing Maintenance

1. **Regular Updates**: Schedule regular feature updates
2. **Security Patches**: Rapid security update deployment
3. **Performance Optimization**: Continuous performance improvements
4. **User Feedback**: Collect and act on user feedback

### Success Measurement

1. **KPIs**: Define key performance indicators
2. **User Satisfaction**: Monitor user ratings and reviews
3. **Market Share**: Track competitive position
4. **Revenue Metrics**: Monitor financial performance

This deployment guide should be regularly updated as the application evolves and new deployment strategies are adopted.
