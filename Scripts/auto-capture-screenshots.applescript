-- Automated Screenshot Capture for Craig-O-Clean
-- This script attempts to automate the screenshot capture process

set screenshotDir to "Screenshots/app-screenshots-" & (do shell script "date +%Y%m%d")
do shell script "mkdir -p " & quoted form of screenshotDir

-- Function to capture screenshot with delay
on captureScreen(filename, delaySeconds)
    delay delaySeconds
    do shell script "screencapture -x " & quoted form of (screenshotDir & "/" & filename)
    return true
end captureScreen

-- Function to capture a specific window
on captureWindow(filename)
    do shell script "screencapture -W " & quoted form of (screenshotDir & "/" & filename)
    return true
end captureWindow

display notification "Starting automated screenshot capture" with title "Craig-O-Clean Screenshots"

tell application "System Events"
    -- Check if Craig-O-Clean is running
    if not (exists process "Craig-O-Clean") then
        display dialog "Craig-O-Clean is not running. Please start the app first." buttons {"OK"} default button "OK"
        return
    end if

    tell process "Craig-O-Clean"
        -- Capture 1: Menu bar with icon
        display notification "Capturing menu bar..." with title "Screenshot 1/8"
        my captureScreen("01-menu-bar-full.png", 1)

        -- Try to click the menu bar icon
        try
            set menuBarItems to menu bar items of menu bar 1
            repeat with anItem in menuBarItems
                if name of anItem contains "Craig" or description of anItem contains "brain" then
                    click anItem
                    exit repeat
                end if
            end repeat

            -- Wait for popover to appear
            delay 1

            -- Capture 2: Popover in current mode
            display notification "Capturing popover..." with title "Screenshot 2/8"
            my captureScreen("02-popover-current-mode.png", 1)

        on error errMsg
            display notification "Could not automate menu bar click: " & errMsg with title "Warning"
        end try

        -- Try to bring up main window
        try
            -- Look for a button or menu item to open full app
            keystroke "o" using {command down} -- Try shortcut
            delay 1

            -- Capture main window
            display notification "Capturing main window..." with title "Screenshot 3/8"
            my captureScreen("03-main-window.png", 1)

        on error errMsg
            display notification "Could not open main window: " & errMsg with title "Warning"
        end try

    end tell
end tell

-- Manual capture for dialogs and specific states
display dialog "Automated capture complete. For alert dialogs and specific states, please run the manual script: ./Scripts/capture-screenshots.sh" buttons {"OK"} default button "OK"

display notification "Screenshot capture completed" with title "Craig-O-Clean Screenshots"
