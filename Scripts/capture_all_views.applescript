-- =============================================================================
-- Craig-O-Clean Automated Screenshot Capture
-- =============================================================================
-- This AppleScript automates capturing screenshots of all app views
-- for Apple App Store submission.
--
-- Usage:
--   osascript capture_all_views.applescript
--
-- Prerequisites:
--   - Craig-O-Clean must be installed
--   - Grant Accessibility permissions to Terminal/Script Editor
-- =============================================================================

-- Configuration
property appName : "Craig-O-Clean"
property outputFolder : (path to desktop as text) & "Craig-O-Clean Screenshots:"
property screenshotDelay : 1 -- seconds to wait between screenshots

-- Create output folder
tell application "Finder"
	try
		make new folder at desktop with properties {name:"Craig-O-Clean Screenshots"}
	end try
end tell

-- Helper function to take a screenshot
on takeScreenshot(screenshotName)
	set outputPath to outputFolder & screenshotName & ".png"
	set posixPath to POSIX path of outputPath

	do shell script "screencapture -w " & quoted form of posixPath

	return posixPath
end takeScreenshot

-- Helper function to take screenshot of specific window
on takeWindowScreenshot(screenshotName)
	set outputPath to outputFolder & screenshotName & ".png"
	set posixPath to POSIX path of outputPath

	tell application "System Events"
		tell process appName
			set frontWindow to first window
			set windowID to id of frontWindow
		end tell
	end tell

	do shell script "screencapture -l" & windowID & " " & quoted form of posixPath

	return posixPath
end takeWindowScreenshot

-- Main capture routine
on run
	display dialog "This script will capture screenshots of Craig-O-Clean for App Store submission." & return & return & "Please ensure:" & return & "1. Craig-O-Clean is running" & return & "2. You have granted Accessibility permissions" & return & return & "Click OK to begin." buttons {"Cancel", "OK"} default button "OK"

	-- Ensure app is running
	tell application appName
		activate
	end tell

	delay 2

	-- Capture Menu Bar Popover
	display dialog "Step 1: Menu Bar Popover" & return & return & "1. Click the Craig-O-Clean icon in the menu bar" & return & "2. Wait for the popover to appear" & return & "3. Click OK to capture" buttons {"Skip", "OK"} default button "OK"

	if button returned of result is "OK" then
		takeScreenshot("01_menubar_popover")
		-- Press Escape to close popover
		tell application "System Events"
			key code 53
		end tell
	end if

	delay screenshotDelay

	-- Open main window
	tell application appName
		activate
	end tell

	delay 1

	-- Capture Dashboard
	display dialog "Step 2: Dashboard View" & return & return & "Make sure the Dashboard tab is selected." & return & "Click OK to capture." buttons {"Skip", "OK"} default button "OK"

	if button returned of result is "OK" then
		takeWindowScreenshot("02_dashboard")
	end if

	delay screenshotDelay

	-- Capture Processes
	display dialog "Step 3: Process Manager" & return & return & "Click the Processes tab in the sidebar." & return & "Click OK when ready to capture." buttons {"Skip", "OK"} default button "OK"

	if button returned of result is "OK" then
		takeWindowScreenshot("03_processes")
	end if

	delay screenshotDelay

	-- Capture Memory Cleanup
	display dialog "Step 4: Memory Cleanup" & return & return & "Click the Memory Cleanup tab in the sidebar." & return & "Click OK when ready to capture." buttons {"Skip", "OK"} default button "OK"

	if button returned of result is "OK" then
		takeWindowScreenshot("04_memory_cleanup")
	end if

	delay screenshotDelay

	-- Capture Browser Tabs
	display dialog "Step 5: Browser Tabs" & return & return & "Click the Browser Tabs tab in the sidebar." & return & "Make sure you have some browser tabs open." & return & "Click OK when ready to capture." buttons {"Skip", "OK"} default button "OK"

	if button returned of result is "OK" then
		takeWindowScreenshot("05_browser_tabs")
	end if

	delay screenshotDelay

	-- Capture Settings
	display dialog "Step 6: Settings" & return & return & "Click the Settings tab in the sidebar." & return & "Click OK when ready to capture." buttons {"Skip", "OK"} default button "OK"

	if button returned of result is "OK" then
		takeWindowScreenshot("06_settings")
	end if

	delay screenshotDelay

	-- Capture Paywall (if possible)
	display dialog "Step 7: Paywall/Upgrade Screen (Optional)" & return & return & "If you can access the paywall screen:" & return & "1. Open the paywall/upgrade dialog" & return & "2. Click OK to capture" & return & return & "Otherwise, click Skip." buttons {"Skip", "OK"} default button "Skip"

	if button returned of result is "OK" then
		takeScreenshot("07_paywall")
	end if

	-- Complete
	display dialog "Screenshot capture complete!" & return & return & "Screenshots saved to:" & return & outputFolder & return & return & "Next steps:" & return & "1. Review screenshots" & return & "2. Resize for different Mac devices" & return & "3. Upload to App Store Connect" buttons {"Open Folder", "Done"} default button "Open Folder"

	if button returned of result is "Open Folder" then
		tell application "Finder"
			open folder outputFolder
			activate
		end tell
	end if
end run
