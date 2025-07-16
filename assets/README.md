# TunnelMax VPN Assets

This directory contains the branding assets for TunnelMax VPN application.

## Icons

### Required Icon Files

To complete the branding setup, you need to add the following icon files:

#### Main Application Icon
- **File**: `icons/app_icon.png`
- **Size**: 1024x1024 pixels
- **Format**: PNG with transparency
- **Description**: Main application icon used for all platforms

#### Android Adaptive Icon Foreground
- **File**: `icons/app_icon_foreground.png`
- **Size**: 432x432 pixels (within 108x108dp safe zone)
- **Format**: PNG with transparency
- **Description**: Foreground layer for Android adaptive icons

#### Windows Installer Assets
- **File**: `icons/app_icon.ico`
- **Sizes**: 16x16, 32x32, 48x48, 256x256 pixels
- **Format**: ICO file with multiple sizes
- **Description**: Windows application icon

### Generating Icons

After adding the main `app_icon.png` file, run the following command to generate platform-specific icons:

```bash
flutter packages pub run flutter_launcher_icons:main
```

## Images

### Application Images
- **splash_logo.png**: Logo for splash screen (512x512px)
- **connection_status_connected.png**: Connected status indicator
- **connection_status_connecting.png**: Connecting status indicator  
- **connection_status_disconnected.png**: Disconnected status indicator

### Installer Assets (Windows)
- **installer_header.bmp**: Header image for Windows installer (150x57px)
- **installer_welcome.bmp**: Welcome page image for Windows installer (164x314px)

## Brand Guidelines

### Colors
- **Primary**: #2196F3 (Material Blue)
- **Primary Dark**: #1976D2 (Material Blue 700)
- **Accent**: #FF4081 (Material Pink A200)
- **Success/Connected**: #4CAF50 (Material Green)
- **Warning/Connecting**: #FF9800 (Material Orange)
- **Error/Disconnected**: #F44336 (Material Red)

### Typography
- **Primary Font**: Roboto (Android), Segoe UI (Windows)
- **Logo Font**: Custom or Roboto Medium

### Icon Design Guidelines
1. Use flat design with minimal shadows
2. Maintain consistent visual style across all icons
3. Ensure icons are readable at small sizes (16x16px)
4. Use the brand color palette
5. Include VPN/security visual elements (shield, lock, tunnel)

## Usage

### In Flutter Code
```dart
// Using asset images
Image.asset('assets/images/splash_logo.png')

// Using icons in app
Icon(Icons.vpn_key) // or custom icon
```

### In Platform Code
- Android: Icons are automatically generated in `android/app/src/main/res/mipmap-*/`
- Windows: Icon is embedded in the executable during build

## File Structure
```
assets/
├── icons/
│   ├── app_icon.png          # Main 1024x1024 icon
│   ├── app_icon_foreground.png # Android adaptive foreground
│   └── app_icon.ico          # Windows ICO file
├── images/
│   ├── splash_logo.png
│   ├── connection_status_*.png
│   ├── installer_header.bmp
│   └── installer_welcome.bmp
└── README.md
```

## Notes
- All icon files should be optimized for size while maintaining quality
- Test icons on different backgrounds and screen densities
- Ensure compliance with platform-specific icon guidelines
- Consider creating dark mode variants if needed