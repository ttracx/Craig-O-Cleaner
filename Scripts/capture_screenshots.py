#!/usr/bin/env python3
"""
Automated Screenshot Capture for Craig-O-Clean
This script helps capture UI states with better automation
"""

import subprocess
import time
import os
from datetime import datetime
from pathlib import Path


class ScreenshotCapture:
    def __init__(self):
        self.screenshot_dir = f"Screenshots/app-screenshots-{datetime.now().strftime('%Y%m%d')}"
        Path(self.screenshot_dir).mkdir(parents=True, exist_ok=True)
        self.app_name = "Craig-O-Clean"

    def is_app_running(self):
        """Check if Craig-O-Clean is running"""
        result = subprocess.run(
            ["pgrep", "-x", self.app_name],
            capture_output=True,
            text=True
        )
        return result.returncode == 0

    def capture_screen(self, filename, delay=0):
        """Capture the entire screen"""
        if delay > 0:
            print(f"Waiting {delay} seconds before capture...")
            time.sleep(delay)

        filepath = os.path.join(self.screenshot_dir, filename)
        subprocess.run(["screencapture", "-x", filepath])
        print(f"✓ Captured: {filename}")
        return filepath

    def capture_window_interactive(self, filename):
        """Capture a window interactively (user clicks on window)"""
        filepath = os.path.join(self.screenshot_dir, filename)
        print(f"Click on the window you want to capture...")
        subprocess.run(["screencapture", "-W", filepath])
        print(f"✓ Captured: {filename}")
        return filepath

    def send_keystroke(self, key, modifiers=None):
        """Send a keystroke using AppleScript"""
        if modifiers:
            modifier_str = " using {" + ", ".join([f"{m} down" for m in modifiers]) + "}"
        else:
            modifier_str = ""

        script = f'''
        tell application "System Events"
            tell process "{self.app_name}"
                keystroke "{key}"{modifier_str}
            end tell
        end tell
        '''
        subprocess.run(["osascript", "-e", script])

    def click_menu_bar_icon(self):
        """Attempt to click the menu bar icon"""
        script = '''
        tell application "System Events"
            tell process "Craig-O-Clean"
                -- Get all menu bar items
                set allItems to menu bar items of menu bar 1
                -- Click the last item (usually the app's menu bar icon)
                click last item of allItems
            end tell
        end tell
        '''
        try:
            subprocess.run(["osascript", "-e", script], check=True)
            return True
        except subprocess.CalledProcessError:
            return False

    def get_appearance_mode(self):
        """Get current macOS appearance mode (Light or Dark)"""
        result = subprocess.run(
            ["defaults", "read", "-g", "AppleInterfaceStyle"],
            capture_output=True,
            text=True
        )
        return "Dark" if result.returncode == 0 else "Light"

    def set_appearance_mode(self, mode="Dark"):
        """Set macOS appearance mode"""
        script = f'''
        tell application "System Events"
            tell appearance preferences
                set dark mode to {"true" if mode == "Dark" else "false"}
            end tell
        end tell
        '''
        subprocess.run(["osascript", "-e", script])
        time.sleep(2)  # Wait for UI to update

    def interactive_prompt(self, message):
        """Show an interactive prompt to the user"""
        print(f"\n{'='*60}")
        print(message)
        print('='*60)
        input("Press ENTER when ready...")

    def run_capture_sequence(self):
        """Run the full screenshot capture sequence"""
        print(f"""
╔════════════════════════════════════════════════════════════╗
║     Craig-O-Clean Screenshot Capture Tool                  ║
║     Automated + Interactive Mode                            ║
╚════════════════════════════════════════════════════════════╝

Screenshots will be saved to: {self.screenshot_dir}
""")

        # Check if app is running
        if not self.is_app_running():
            print("❌ Craig-O-Clean is not running!")
            print("   Starting the app now...")
            subprocess.run([
                "open",
                "/Users/knightdev/Library/Developer/Xcode/DerivedData/Craig-O-Clean-dpvmereinewabibedxiucpgcsyxm/Build/Products/Debug/Craig-O-Clean.app"
            ])
            time.sleep(3)

        current_mode = self.get_appearance_mode()
        print(f"Current appearance mode: {current_mode}")

        # 1. Menu Bar Icon
        print("\n[1/8] Capturing Menu Bar Icon...")
        self.interactive_prompt(
            "Make sure the Craig-O-Clean icon is visible in the menu bar.\n"
            "The icon should be a brain symbol in the top-right menu bar."
        )
        self.capture_screen("01-menu-bar-icon.png", delay=2)

        # 2. Popover - Light Mode
        print("\n[2/8] Capturing Popover (Light Mode)...")
        if current_mode == "Dark":
            print("Switching to Light Mode...")
            self.set_appearance_mode("Light")

        self.interactive_prompt(
            "Click the Craig-O-Clean menu bar icon to open the popover.\n"
            "Ensure the popover is fully visible."
        )
        self.capture_screen("02-popover-light-mode.png", delay=1)

        # 3. Popover - Dark Mode
        print("\n[3/8] Capturing Popover (Dark Mode)...")
        print("Switching to Dark Mode...")
        self.set_appearance_mode("Dark")

        self.interactive_prompt(
            "Click the Craig-O-Clean menu bar icon again.\n"
            "Ensure the popover is fully visible in dark mode."
        )
        self.capture_screen("03-popover-dark-mode.png", delay=1)

        # 4. Search Active State
        print("\n[4/8] Capturing Search Active State...")
        self.interactive_prompt(
            "In the main window or popover:\n"
            "1. Click on the search field\n"
            "2. Type something to show the active state\n"
            "3. Make sure the search field is clearly visible"
        )
        self.capture_screen("04-search-active.png", delay=1)

        # 5. Alert Dialog - Quit Confirmation
        print("\n[5/8] Capturing Alert Dialog (Quit Confirmation)...")
        self.interactive_prompt(
            "To show the quit confirmation dialog:\n"
            "1. Open the main window (click 'Open Full App' in popover)\n"
            "2. Go to Process Manager\n"
            "3. Select a user app (like Safari, Notes, etc.)\n"
            "4. Click the 'Terminate' button\n"
            "5. Position the dialog so it's clearly visible"
        )
        self.capture_screen("05-alert-quit-confirmation.png", delay=1)

        # 6. Alert Dialog - Force Quit Warning
        print("\n[6/8] Capturing Alert Dialog (Force Quit Warning)...")
        self.interactive_prompt(
            "To show the force quit warning:\n"
            "1. In Process Manager, select a system process\n"
            "2. Click the 'Force Quit' button\n"
            "3. Position the warning dialog clearly"
        )
        self.capture_screen("06-alert-force-quit-warning.png", delay=1)

        # 7. Process List
        print("\n[7/8] Capturing Process List...")
        self.interactive_prompt(
            "In the Process Manager view:\n"
            "1. Ensure several apps are running\n"
            "2. Scroll to show a good variety of processes\n"
            "3. Make sure columns are visible (Name, CPU, Memory, etc.)"
        )
        self.capture_screen("07-process-list.png", delay=1)

        # 8. Main Dashboard
        print("\n[8/8] Capturing Main Dashboard...")
        self.interactive_prompt(
            "Switch to the Dashboard tab:\n"
            "1. Show CPU, Memory, Disk metrics\n"
            "2. Ensure all gauges and charts are visible"
        )
        self.capture_screen("08-dashboard-view.png", delay=1)

        # Restore original appearance mode
        if current_mode != self.get_appearance_mode():
            print(f"\nRestoring original appearance mode: {current_mode}")
            self.set_appearance_mode(current_mode)

        print(f"""
╔════════════════════════════════════════════════════════════╗
║     Screenshot Capture Complete!                            ║
╚════════════════════════════════════════════════════════════╝

All screenshots have been saved to:
    {self.screenshot_dir}

Files captured:
""")
        # List all captured files
        for file in sorted(os.listdir(self.screenshot_dir)):
            if file.endswith('.png'):
                print(f"    ✓ {file}")


if __name__ == "__main__":
    try:
        capturer = ScreenshotCapture()
        capturer.run_capture_sequence()
    except KeyboardInterrupt:
        print("\n\nCapture cancelled by user.")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
