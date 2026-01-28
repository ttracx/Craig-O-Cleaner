# Avatar Feature Setup Instructions

## Overview
The avatar upload feature has been implemented but the Swift files need to be manually added to the Xcode project.

## Files Created
1. **Craig-O-Clean/Core/AvatarManager.swift** - Manages avatar image upload, storage, and iCloud sync
2. **Craig-O-Clean/Core/AppVersion.swift** - Helper extension for consistent app version display

## Features
- Upload profile picture with file picker (supports PNG, JPEG, HEIC)
- Automatic image compression (max 2MB)
- Local persistent storage using UserDefaults
- iCloud sync using NSUbiquitousKeyValueStore
- Automatic sync across devices
- Delete avatar functionality

## How to Enable

### Step 1: Add Files to Xcode Project
1. Open `Craig-O-Clean.xcodeproj` in Xcode
2. In the Project Navigator, locate the **Core** folder
3. Right-click on **Core** → **Add Files to "Craig-O-Clean"...**
4. Navigate to `Craig-O-Clean/Core/` and select:
   - `AvatarManager.swift`
   - `AppVersion.swift`
5. Make sure **"Copy items if needed"** is UNCHECKED (files are already in the right location)
6. Make sure **"Add to targets: Craig-O-Clean"** is CHECKED
7. Click **Add**

### Step 2: Uncomment Avatar Code in SettingsView
1. Open `Craig-O-Clean/SettingsView.swift`
2. Find all lines marked with `TODO: Avatar feature`
3. Uncomment the following sections:
   - State variables (lines ~5-8):
     ```swift
     @State private var avatarManager = AvatarManager.shared
     @State private var showingAvatarPicker = false
     @State private var showingAlert = false
     @State private var alertMessage = ""
     ```
   - User profile section call (line ~21):
     ```swift
     userProfileSection
     ```
   - Alert modifier (lines ~168-172)
   - `userProfileSection` view builder (lines ~187-260)
   - Avatar action functions (lines ~327-361)

### Step 3: Update Version Display (Optional)
1. Open `Craig-O-Clean/UI/MainAppView.swift`
2. Replace the TODO line (~147) with:
   ```swift
   Text(Bundle.main.displayVersion)
   ```

3. Open `Craig-O-Clean/SettingsView.swift`
4. Replace the TODO line (~112) with:
   ```swift
   Text(Bundle.main.displayVersion)
   ```

### Step 4: Build and Test
1. Build the project (⌘+B)
2. Run the app (⌘+R)
3. Open Settings from the menu bar or main window
4. You should see the "User Profile" section at the top
5. Click "Upload Avatar" to select an image
6. The avatar will be saved locally and synced to iCloud

## Version Number Fix
The app version is now correctly displayed as **Version 9 (2)** everywhere:
- Control Center sidebar footer
- Settings → About window
- All other locations

The version is read dynamically from the app bundle using:
- `CFBundleShortVersionString` → "9" (Marketing Version)
- `CFBundleVersion` → "2" (Build Number)

## Testing iCloud Sync
1. Upload an avatar on one device
2. Wait a few seconds for sync
3. Open the app on another device signed into the same iCloud account
4. The avatar should appear automatically

## Storage Details
- **Local**: UserDefaults key `com.craigoclean.avatar.imageData`
- **iCloud**: NSUbiquitousKeyValueStore key `avatarImageData`
- **Max Size**: 2MB (automatically compressed if larger)
- **Formats**: PNG, JPEG, HEIC

## Troubleshooting
- **Avatar not syncing**: Ensure iCloud is enabled in System Settings → Apple ID → iCloud
- **Upload fails**: Check that the image file is valid and accessible
- **Build errors**: Make sure both Swift files are added to the Xcode project target
