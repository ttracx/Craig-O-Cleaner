#!/usr/bin/env python3
"""
Craig-O-Clean App Store Screenshot Helper

This script provides utilities for taking and processing screenshots
for Apple App Store submission.

Requirements:
    pip install Pillow

Usage:
    python screenshot_helper.py [command] [options]

Commands:
    capture     - Take screenshots of the app
    resize      - Resize screenshots for different devices
    frame       - Add device frames to screenshots
    optimize    - Optimize screenshots for upload
    all         - Run all steps
"""

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not installed. Install with: pip install Pillow")
    sys.exit(1)


# App Store screenshot dimensions for Mac
SCREENSHOT_DIMENSIONS = {
    "mac_1280x800": (1280, 800),
    "mac_1440x900": (1440, 900),
    "mac_2560x1600": (2560, 1600),
    "mac_2880x1800": (2880, 1800),
}

# Screenshot descriptions for App Store
SCREENSHOT_METADATA = {
    "01_menubar": {
        "title": "Quick Access Menu Bar",
        "description": "Monitor your system at a glance from the menu bar",
    },
    "02_dashboard": {
        "title": "System Dashboard",
        "description": "Real-time CPU, Memory, Disk, and Network monitoring",
    },
    "03_processes": {
        "title": "Process Manager",
        "description": "View and manage all running applications",
    },
    "04_memory": {
        "title": "Memory Optimizer",
        "description": "Smart cleanup to free up system memory",
    },
    "05_browser": {
        "title": "Browser Tab Manager",
        "description": "Control tabs across Safari, Chrome, and more",
    },
    "06_settings": {
        "title": "Settings & Subscription",
        "description": "Customize your experience with flexible plans",
    },
    "07_paywall": {
        "title": "Pro Features",
        "description": "Unlock all features with a 7-day free trial",
    },
}


class ScreenshotCapture:
    """Handle screenshot capture using macOS screencapture."""

    def __init__(self, output_dir: str = "./Screenshots"):
        self.output_dir = Path(output_dir)
        self.timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.session_dir = self.output_dir / self.timestamp

    def setup(self):
        """Create output directories."""
        for device in SCREENSHOT_DIMENSIONS.keys():
            (self.session_dir / device).mkdir(parents=True, exist_ok=True)
        print(f"Created output directory: {self.session_dir}")

    def capture_window(self, name: str, window_title: str = None):
        """Capture a specific window or interactive selection."""
        print(f"Capturing: {name}")

        # Capture at highest resolution, then resize
        output_path = self.session_dir / "mac_2880x1800" / f"{name}.png"

        if window_title:
            # Use AppleScript to get window bounds and capture
            script = f'''
            tell application "System Events"
                tell process "Craig-O-Clean"
                    set frontWindow to first window
                    set windowPos to position of frontWindow
                    set windowSize to size of frontWindow
                end tell
            end tell
            return (item 1 of windowPos) & "," & (item 2 of windowPos) & "," & (item 1 of windowSize) & "," & (item 2 of windowSize)
            '''
            try:
                result = subprocess.run(
                    ["osascript", "-e", script],
                    capture_output=True,
                    text=True
                )
                if result.returncode == 0:
                    x, y, w, h = result.stdout.strip().split(",")
                    subprocess.run([
                        "screencapture",
                        "-R", f"{x},{y},{w},{h}",
                        str(output_path)
                    ])
            except Exception as e:
                print(f"Error capturing window: {e}")
                # Fallback to interactive capture
                subprocess.run(["screencapture", "-w", str(output_path)])
        else:
            # Interactive window capture
            subprocess.run(["screencapture", "-w", str(output_path)])

        return output_path

    def capture_screen(self, name: str):
        """Capture the entire screen."""
        output_path = self.session_dir / "mac_2880x1800" / f"{name}.png"
        subprocess.run(["screencapture", str(output_path)])
        return output_path

    def capture_region(self, name: str, x: int, y: int, width: int, height: int):
        """Capture a specific region of the screen."""
        output_path = self.session_dir / "mac_2880x1800" / f"{name}.png"
        subprocess.run([
            "screencapture",
            "-R", f"{x},{y},{width},{height}",
            str(output_path)
        ])
        return output_path


class ScreenshotProcessor:
    """Process and resize screenshots for different devices."""

    def __init__(self, session_dir: Path):
        self.session_dir = session_dir

    def resize_for_devices(self):
        """Resize screenshots for all device sizes."""
        source_dir = self.session_dir / "mac_2880x1800"

        if not source_dir.exists():
            print(f"Source directory not found: {source_dir}")
            return

        for screenshot in source_dir.glob("*.png"):
            print(f"Processing: {screenshot.name}")

            with Image.open(screenshot) as img:
                for device, (width, height) in SCREENSHOT_DIMENSIONS.items():
                    if device == "mac_2880x1800":
                        continue  # Skip source resolution

                    output_dir = self.session_dir / device
                    output_path = output_dir / screenshot.name

                    # Resize maintaining aspect ratio
                    resized = img.resize((width, height), Image.Resampling.LANCZOS)
                    resized.save(output_path, "PNG", optimize=True)

                    print(f"  Created: {output_path}")

    def add_text_overlay(self, image_path: Path, title: str, subtitle: str = None):
        """Add text overlay to screenshot."""
        with Image.open(image_path) as img:
            draw = ImageDraw.Draw(img)

            # Try to use system font, fallback to default
            try:
                title_font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 48)
                subtitle_font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 24)
            except:
                title_font = ImageFont.load_default()
                subtitle_font = ImageFont.load_default()

            # Calculate text position (top center)
            width, height = img.size
            title_bbox = draw.textbbox((0, 0), title, font=title_font)
            title_width = title_bbox[2] - title_bbox[0]
            title_x = (width - title_width) // 2
            title_y = 40

            # Draw text with shadow
            shadow_offset = 2
            draw.text((title_x + shadow_offset, title_y + shadow_offset), title, font=title_font, fill=(0, 0, 0, 128))
            draw.text((title_x, title_y), title, font=title_font, fill=(255, 255, 255, 255))

            if subtitle:
                subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
                subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
                subtitle_x = (width - subtitle_width) // 2
                subtitle_y = title_y + 60

                draw.text((subtitle_x + shadow_offset, subtitle_y + shadow_offset), subtitle, font=subtitle_font, fill=(0, 0, 0, 128))
                draw.text((subtitle_x, subtitle_y), subtitle, font=subtitle_font, fill=(200, 200, 200, 255))

            # Save with overlay
            output_path = image_path.parent / f"{image_path.stem}_titled{image_path.suffix}"
            img.save(output_path, "PNG")

            return output_path

    def optimize_for_upload(self):
        """Optimize PNG files for App Store upload."""
        for device_dir in self.session_dir.iterdir():
            if not device_dir.is_dir():
                continue

            for screenshot in device_dir.glob("*.png"):
                print(f"Optimizing: {screenshot}")

                with Image.open(screenshot) as img:
                    # Convert to RGB if necessary (remove alpha for smaller size)
                    if img.mode == "RGBA":
                        # Create white background
                        background = Image.new("RGB", img.size, (255, 255, 255))
                        background.paste(img, mask=img.split()[3])
                        img = background

                    # Save optimized
                    img.save(screenshot, "PNG", optimize=True)


def generate_metadata(session_dir: Path):
    """Generate metadata JSON for the screenshot session."""
    metadata = {
        "app_name": "Craig-O-Clean",
        "bundle_id": "com.craigoclean.app",
        "generated_at": datetime.now().isoformat(),
        "platform": "macOS",
        "min_os_version": "14.0",
        "screenshots": {},
        "dimensions": SCREENSHOT_DIMENSIONS,
    }

    # Find all screenshots
    for device_dir in session_dir.iterdir():
        if not device_dir.is_dir():
            continue

        for screenshot in device_dir.glob("*.png"):
            base_name = screenshot.stem
            if base_name in SCREENSHOT_METADATA:
                metadata["screenshots"][base_name] = {
                    **SCREENSHOT_METADATA[base_name],
                    "filename": screenshot.name,
                    "device": device_dir.name,
                }

    # Save metadata
    metadata_path = session_dir / "metadata.json"
    with open(metadata_path, "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"Generated metadata: {metadata_path}")
    return metadata_path


def interactive_capture():
    """Run interactive screenshot capture session."""
    print("\n" + "=" * 50)
    print("  Craig-O-Clean Screenshot Capture Session")
    print("=" * 50 + "\n")

    capture = ScreenshotCapture()
    capture.setup()

    screenshots_to_capture = [
        ("01_menubar", "Menu bar popover"),
        ("02_dashboard", "Dashboard view"),
        ("03_processes", "Process manager"),
        ("04_memory", "Memory cleanup"),
        ("05_browser", "Browser tabs"),
        ("06_settings", "Settings view"),
        ("07_paywall", "Paywall/upgrade screen"),
    ]

    print("Instructions:")
    print("1. Make sure Craig-O-Clean is running")
    print("2. Navigate to each view when prompted")
    print("3. Press Enter when ready to capture")
    print("4. Click on the window to capture")
    print("\n")

    for name, description in screenshots_to_capture:
        input(f"Press Enter to capture: {description}")
        capture.capture_window(name)
        print(f"  Captured {name}\n")

    print("\nProcessing screenshots...")
    processor = ScreenshotProcessor(capture.session_dir)
    processor.resize_for_devices()
    processor.optimize_for_upload()

    generate_metadata(capture.session_dir)

    print(f"\nScreenshots saved to: {capture.session_dir}")
    print("\nDone!")

    # Open the output directory
    subprocess.run(["open", str(capture.session_dir)])


def main():
    parser = argparse.ArgumentParser(
        description="Craig-O-Clean App Store Screenshot Helper"
    )
    parser.add_argument(
        "command",
        choices=["capture", "resize", "optimize", "metadata", "all", "interactive"],
        help="Command to run"
    )
    parser.add_argument(
        "-d", "--directory",
        default="./Screenshots",
        help="Output directory for screenshots"
    )
    parser.add_argument(
        "-s", "--session",
        help="Session directory (for resize/optimize)"
    )

    args = parser.parse_args()

    if args.command == "interactive" or args.command == "all":
        interactive_capture()
    elif args.command == "capture":
        capture = ScreenshotCapture(args.directory)
        capture.setup()
        print("Ready for capture. Use interactive mode for guided capture.")
    elif args.command == "resize":
        if args.session:
            processor = ScreenshotProcessor(Path(args.session))
            processor.resize_for_devices()
        else:
            print("Please specify session directory with -s")
    elif args.command == "optimize":
        if args.session:
            processor = ScreenshotProcessor(Path(args.session))
            processor.optimize_for_upload()
        else:
            print("Please specify session directory with -s")
    elif args.command == "metadata":
        if args.session:
            generate_metadata(Path(args.session))
        else:
            print("Please specify session directory with -s")


if __name__ == "__main__":
    main()
