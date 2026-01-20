#!/usr/bin/env python3
"""
Fully Automated Screenshot Capture for Craig-O-Clean
Uses timed delays and AppleScript automation
"""

import subprocess
import time
import os
from datetime import datetime
from pathlib import Path


def capture_screen(filepath, delay=0):
    """Capture the entire screen"""
    if delay > 0:
        time.sleep(delay)
    subprocess.run(["screencapture", "-x", filepath], check=True)
    print(f"✓ Captured: {os.path.basename(filepath)}")


def get_app_path():
    """Get the path to the built app"""
    return "/Users/knightdev/Library/Developer/Xcode/DerivedData/Craig-O-Clean-dpvmereinewabibedxiucpgcsyxm/Build/Products/Debug/Craig-O-Clean.app"


def is_app_running():
    """Check if app is running"""
    result = subprocess.run(
        ["pgrep", "-x", "Craig-O-Clean"],
        capture_output=True
    )
    return result.returncode == 0


def launch_app():
    """Launch the Craig-O-Clean app"""
    if not is_app_running():
        print("Launching Craig-O-Clean...")
        subprocess.run(["open", get_app_path()])
        time.sleep(3)


def click_menu_bar():
    """Click the menu bar icon using AppleScript"""
    script = '''
    tell application "System Events"
        tell process "Craig-O-Clean"
            try
                -- Try to find and click the menu bar extra
                set menuItems to menu bar items of menu bar 1
                repeat with anItem in menuItems
                    if (exists menu bar item 1 of menu bar 1) then
                        click last item of menuItems
                        exit repeat
                    end if
                end repeat
            end try
        end tell
    end tell
    '''
    try:
        subprocess.run(["osascript", "-e", script], check=True, capture_output=True)
        time.sleep(1)
        return True
    except:
        return False


def main():
    screenshot_dir = f"Screenshots/app-screenshots-{datetime.now().strftime('%Y%m%d')}"
    Path(screenshot_dir).mkdir(parents=True, exist_ok=True)

    print("="*60)
    print("Craig-O-Clean Automated Screenshot Capture")
    print("="*60)
    print(f"\nScreenshots will be saved to: {screenshot_dir}\n")

    # Ensure app is running
    launch_app()

    # Give user time to position windows
    print("Waiting 5 seconds for app to fully load...")
    time.sleep(5)

    # 1. Capture menu bar
    print("\n[1/8] Capturing menu bar with icon...")
    capture_screen(f"{screenshot_dir}/01-menu-bar-icon.png", delay=1)

    # 2. Try to open popover and capture
    print("\n[2/8] Attempting to open popover...")
    click_menu_bar()
    time.sleep(1)
    capture_screen(f"{screenshot_dir}/02-popover-light-mode.png")

    # 3. Close and reopen for better capture
    click_menu_bar()  # Close
    time.sleep(0.5)
    click_menu_bar()  # Reopen
    time.sleep(1)
    capture_screen(f"{screenshot_dir}/03-popover-alternate.png")

    print("\n" + "="*60)
    print("Automated capture complete!")
    print("="*60)
    print(f"\nScreenshots saved to: {screenshot_dir}")
    print("\nFor additional screenshots (alerts, search states, etc.),")
    print("please use the interactive script:")
    print("  python3 Scripts/capture_screenshots.py")
    print("\nOr the manual guide script:")
    print("  bash Scripts/capture-screenshots.sh")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
