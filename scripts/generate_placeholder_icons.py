#!/usr/bin/env python3
"""
Generate placeholder icons for TunnelMax VPN
This script creates basic placeholder icons that can be replaced with proper branding later.
"""

import os
from PIL import Image, ImageDraw, ImageFont
import sys

def create_placeholder_icon(size, filename, text="VPN"):
    """Create a placeholder icon with specified size and text."""
    # Create image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw background circle
    margin = size // 10
    draw.ellipse([margin, margin, size - margin, size - margin], 
                fill=(33, 150, 243, 255), outline=(25, 118, 210, 255), width=2)
    
    # Try to load a font, fallback to default if not available
    try:
        font_size = size // 4
        font = ImageFont.truetype("arial.ttf", font_size)
    except:
        try:
            font = ImageFont.load_default()
        except:
            font = None
    
    # Draw text
    if font:
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        x = (size - text_width) // 2
        y = (size - text_height) // 2
        draw.text((x, y), text, fill=(255, 255, 255, 255), font=font)
    
    # Save image
    img.save(filename, 'PNG')
    print(f"Created: {filename} ({size}x{size})")

def create_ico_file(png_file, ico_file):
    """Convert PNG to ICO with multiple sizes."""
    try:
        img = Image.open(png_file)
        sizes = [(16, 16), (32, 32), (48, 48), (256, 256)]
        
        # Create images for each size
        images = []
        for size in sizes:
            resized = img.resize(size, Image.Resampling.LANCZOS)
            images.append(resized)
        
        # Save as ICO
        images[0].save(ico_file, format='ICO', sizes=[(img.width, img.height) for img in images])
        print(f"Created: {ico_file}")
    except Exception as e:
        print(f"Error creating ICO file: {e}")

def main():
    # Create directories if they don't exist
    os.makedirs('assets/icons', exist_ok=True)
    os.makedirs('assets/images', exist_ok=True)
    os.makedirs('windows/installer/assets', exist_ok=True)
    
    # Create main app icon (1024x1024)
    create_placeholder_icon(1024, 'assets/icons/app_icon.png', 'VPN')
    
    # Create Android adaptive icon foreground (432x432)
    create_placeholder_icon(432, 'assets/icons/app_icon_foreground.png', 'VPN')
    
    # Create Windows ICO file
    create_ico_file('assets/icons/app_icon.png', 'assets/icons/app_icon.ico')
    create_ico_file('assets/icons/app_icon.png', 'windows/installer/assets/icon.ico')
    
    # Create status icons
    status_icons = [
        ('connected', '#4CAF50', '●'),
        ('connecting', '#FF9800', '◐'),
        ('disconnected', '#F44336', '○')
    ]
    
    for status, color, symbol in status_icons:
        img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        # Convert hex color to RGB
        color_rgb = tuple(int(color[i:i+2], 16) for i in (1, 3, 5))
        
        # Draw status symbol
        try:
            font = ImageFont.truetype("arial.ttf", 48)
        except:
            font = ImageFont.load_default()
        
        if font:
            bbox = draw.textbbox((0, 0), symbol, font=font)
            text_width = bbox[2] - bbox[0]
            text_height = bbox[3] - bbox[1]
            x = (64 - text_width) // 2
            y = (64 - text_height) // 2
            draw.text((x, y), symbol, fill=color_rgb + (255,), font=font)
        
        filename = f'assets/images/connection_status_{status}.png'
        img.save(filename, 'PNG')
        print(f"Created: {filename}")
    
    # Create splash logo
    create_placeholder_icon(512, 'assets/images/splash_logo.png', 'TunnelMax')
    
    print("\nPlaceholder icons created successfully!")
    print("Replace these with your actual branding assets.")
    print("\nTo generate Flutter launcher icons, run:")
    print("flutter packages pub run flutter_launcher_icons:main")

if __name__ == "__main__":
    try:
        main()
    except ImportError:
        print("Error: PIL (Pillow) is required to generate icons.")
        print("Install it with: pip install Pillow")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)