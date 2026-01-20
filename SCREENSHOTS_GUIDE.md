# Craig-O-Clean Screenshot Capture Guide

## Important: fastlane `snapshot` for macOS

**Note:** `fastlane snapshot` only works for iOS/tvOS apps. For macOS apps, we need alternative approaches.

## Method 1: Manual UI Test Screenshot Capture (Recommended)

Your UI tests already have `snapshot()` calls integrated in `Tests/CraigOCleanUITests/AutomatedE2ETests.swift`:

- `snapshot("0Launch")` - App launch
- `snapshot("1Dashboard")` - Dashboard view
- `snapshot("2Processes")` - Processes view
- `snapshot("3MemoryCleanup")` - Memory cleanup view
- `snapshot("4AutoCleanup")` - Auto-cleanup view
- `snapshot("5BrowserTabs")` - Browser tabs view
- `snapshot("6Settings")` - Settings view

### Steps to Capture Screenshots:

1. **Fix Build Errors First**:
   Open the project in Xcode and resolve any compilation errors (TrialManager scope issues):
   ```bash
   open Craig-O-Clean.xcodeproj
   ```

2. **Run UI Tests in Xcode**:
   - Select the `Craig-O-Clean` scheme
   - Select Product → Test (⌘U)
   - Or run only UI tests: Product → Perform Action → Run "Craig-O-CleanUITests"

3. **Extract Screenshots from Test Results**:
   After tests run, find the `.xcresult` bundle:
   ```bash
   # Find the latest test result
   ls -lt ~/Library/Developer/Xcode/DerivedData/Craig-O-Clean-*/Logs/Test/

   # Extract screenshots
   xcrun xcresulttool get --path ~/Library/Developer/Xcode/DerivedData/Craig-O-Clean-*/Logs/Test/*.xcresult \
     --format json > test_results.json
   ```

## Method 2: xcodebuild Command Line

Once build errors are fixed, run tests from command line:

```bash
# Run UI tests
xcodebuild test \
  -scheme Craig-O-Clean \
  -destination 'platform=macOS' \
  -only-testing:Craig-O-CleanUITests \
  -resultBundlePath ./test_output/Craig-O-Clean.xcresult

# Extract attachments (screenshots)
xcrun xcresulttool get \
  --path ./test_output/Craig-O-Clean.xcresult \
  --format json | \
  jq '.actions[].actionResult.testsRef.id._value' | \
  xargs -I {} xcrun xcresulttool get \
    --path ./test_output/Craig-O-Clean.xcresult \
    --id {} \
    --format json
```

## Method 3: Custom Script for Screenshot Extraction

Create a script to automatically extract screenshots from test results:

```bash
#!/bin/bash

RESULT_BUNDLE="./test_output/Craig-O-Clean.xcresult"
OUTPUT_DIR="./Screenshots/automated"

mkdir -p "$OUTPUT_DIR"

# Get all attachments
xcrun xcresulttool export \
  --path "$RESULT_BUNDLE" \
  --output-path "$OUTPUT_DIR" \
  --type file

echo "✅ Screenshots exported to $OUTPUT_DIR"
```

## Method 4: Simulator.app Screenshot Feature

For manual screenshot capture:

1. Run the app in Simulator or on your Mac
2. Use macOS built-in screenshot tools:
   - ⌘⇧4: Capture selected area
   - ⌘⇧5: Open screenshot toolbar
3. Save screenshots to `Screenshots/manual/`

## Method 5: Using Xcode's Screenshot API

The `snapshot()` calls in your UI tests use fastlane's SnapshotHelper, but for macOS you can also use XCTAttachment:

```swift
let screenshot = XCUIApplication().screenshot()
let attachment = XCTAttachment(screenshot: screenshot)
attachment.name = "dashboard_view"
attachment.lifetime = .keepAlways
add(attachment)
```

Your tests already capture screenshots via `captureScreenshot(name:)` method.

## Recommended Screenshot Sizes for App Store

For macOS App Store, you need these screenshot sizes:

- **1280x800** - 16:10 aspect ratio
- **1440x900** - 16:10 aspect ratio
- **2560x1600** - 16:10 aspect ratio (Retina)
- **2880x1800** - 16:10 aspect ratio (Retina)

## Current Build Issues

Before capturing screenshots, fix these build errors:

1. **TrialManager scope errors** in:
   - `UI/MenuBarContentView.swift:2024`
   - `UI/MenuBarContentView.swift:45`
   - `UI/SettingsPermissionsView.swift:16`

2. **Missing Info.plist for test targets** ✅ FIXED
   - Added `GENERATE_INFOPLIST_FILE = YES` to test targets

## Automation Once Build is Fixed

After fixing build errors, you can use the fastlane `screenshots` lane:

```bash
bundle exec fastlane screenshots
```

This will:
- Run UI tests
- Capture screenshots via `snapshot()` calls
- Save results to `./test_output/`
- Generate test report

## Uploading to App Store Connect

Once you have screenshots in the correct sizes:

```bash
# Upload metadata and screenshots
fastlane metadata

# Or use deliver directly
fastlane deliver --screenshots_path ./Screenshots/final
```

## Tips

1. **Consistent Window Size**: Ensure your app window is sized correctly before capturing
2. **Clean State**: Reset app state between screenshot captures
3. **Localization**: Create separate folders for each language (en-US, etc.)
4. **Naming**: Use descriptive names like `1_dashboard.png`, `2_processes.png`
5. **Quality**: Use PNG format for best quality
6. **Review**: Double-check all screenshots before uploading

## Next Steps

1. Open project in Xcode: `open Craig-O-Clean.xcodeproj`
2. Resolve TrialManager compilation errors
3. Run UI tests (⌘U)
4. Extract screenshots from test results
5. Resize if needed for App Store requirements
6. Upload using fastlane or App Store Connect web interface
