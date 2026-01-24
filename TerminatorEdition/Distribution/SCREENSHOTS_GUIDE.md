# App Store Screenshots Guide

## Craig-O Clean Terminator Edition

This guide outlines the requirements and recommendations for App Store screenshots.

---

## Screenshot Requirements

### macOS App Store Requirements

#### Required Sizes (macOS)
1. **13.3" Display (2560 x 1600 pixels)**
2. **12.9" Display (2048 x 2732 pixels)** - Optional but recommended

#### Number of Screenshots
- **Minimum**: 1 screenshot
- **Recommended**: 5-10 screenshots
- **Maximum**: 10 screenshots

#### File Format
- PNG or JPEG
- sRGB color space
- No transparency
- No alpha channels

---

## Screenshot Plan

### Screenshot 1: Main Dashboard
**Filename**: `01-dashboard.png`
**Size**: 2560 x 1600 pixels
**Description**: "Real-time system monitoring with health score"

**Content**:
- Dashboard view showing:
  - Health score: 95/100
  - CPU usage: 15%
  - Memory usage: 45%
  - Disk usage: 62%
- Clean, modern interface
- Menu bar visible with Craig-O icon

**Overlay Text**:
- Title: "Monitor Your Mac's Health"
- Subtitle: "Real-time system metrics at a glance"

---

### Screenshot 2: Cleanup Results
**Filename**: `02-cleanup.png`
**Size**: 2560 x 1600 pixels
**Description**: "Quick cleanup results showing freed memory and disk space"

**Content**:
- Cleanup view with results:
  - Memory freed: 2.5 GB
  - Disk space freed: 4.8 GB
  - Processes terminated: 8
  - Tabs closed: 45
  - Caches cleared: 12
- Success animation/checkmarks
- Before/after comparison

**Overlay Text**:
- Title: "Powerful Cleanup in Seconds"
- Subtitle: "Free up memory and disk space instantly"

---

### Screenshot 3: Process Management
**Filename**: `03-processes.png`
**Size**: 2560 x 1600 pixels
**Description**: "Advanced process management with sorting and filtering"

**Content**:
- Processes view showing:
  - List of processes sorted by CPU usage
  - Process details panel
  - Search/filter options
  - Color-coded resource usage
- Professional, data-rich layout

**Overlay Text**:
- Title: "Intelligent Process Management"
- Subtitle: "Identify and terminate resource hogs"

---

### Screenshot 4: Browser Tab Management
**Filename**: `04-browsers.png`
**Size**: 2560 x 1600 pixels
**Description**: "Cross-browser tab management and optimization"

**Content**:
- Browsers view showing:
  - Safari: 23 tabs
  - Chrome: 47 tabs
  - Firefox: 12 tabs
- Memory usage per browser
- Heavy tab detection
- One-click cleanup options

**Overlay Text**:
- Title: "Manage All Your Browser Tabs"
- Subtitle: "Close heavy tabs across Safari, Chrome, Firefox & more"

---

### Screenshot 5: Menu Bar Integration
**Filename**: `05-menubar.png`
**Size**: 2560 x 1600 pixels
**Description**: "Quick access from menu bar"

**Content**:
- Menu bar dropdown showing:
  - Health metrics
  - Quick cleanup buttons
  - Top processes
  - Browser stats
- Desktop background visible
- Clean, minimal interface

**Overlay Text**:
- Title: "Always Within Reach"
- Subtitle: "Access powerful tools from your menu bar"

---

### Screenshot 6: Autonomous Mode (Optional)
**Filename**: `06-autonomous.png`
**Size**: 2560 x 1600 pixels
**Description**: "AI-powered autonomous monitoring and cleanup"

**Content**:
- Settings view showing:
  - Autonomous mode enabled
  - Threshold sliders
  - AI agent status
  - Automated tasks schedule
- Futuristic, AI-themed visuals

**Overlay Text**:
- Title: "Set It and Forget It"
- Subtitle: "AI agents monitor and optimize automatically"

---

### Screenshot 7: Diagnostics & Health
**Filename**: `07-diagnostics.png`
**Size**: 2560 x 1600 pixels
**Description**: "Comprehensive system diagnostics and recommendations"

**Content**:
- Diagnostics view with:
  - CPU temperature
  - Memory pressure
  - Disk I/O
  - Network activity
  - Health recommendations
- Charts and graphs

**Overlay Text**:
- Title: "Deep System Insights"
- Subtitle: "Understand what's affecting your Mac's performance"

---

### Screenshot 8: iCloud Sync (Optional)
**Filename**: `08-sync.png`
**Size**: 2560 x 1600 pixels
**Description**: "Seamless settings sync across all your Macs"

**Content**:
- Account settings showing:
  - User profile with avatar
  - iCloud sync status
  - Multiple devices connected
  - Settings synchronized
- Apple Sign In integration

**Overlay Text**:
- Title: "Sync Across All Your Macs"
- Subtitle: "Sign in with Apple and sync your settings via iCloud"

---

## Design Guidelines

### Color Scheme
- **Primary**: Red/Orange gradient (matching app icon)
- **Accent**: Blue for interactive elements
- **Background**: System default (light/dark mode support)
- **Text**: High contrast for readability

### Typography
- **Overlay Titles**: SF Pro Display, 48-60pt, Bold
- **Overlay Subtitles**: SF Pro Text, 24-32pt, Regular
- **In-App Text**: System fonts, appropriate sizes

### Layout
- Keep important content in the central 80% of the frame
- Leave breathing room around edges
- Ensure text overlays don't obscure important UI elements
- Use consistent positioning across screenshots

### Content
- Show realistic data (not all zeros or Lorem Ipsum)
- Display variety of usage scenarios
- Include both light and dark mode examples
- Showcase key differentiating features

---

## Screenshot Capture Process

### Step 1: Prepare App
1. Set up ideal demo data
2. Configure windows to optimal sizes
3. Close unrelated apps
4. Clean desktop background
5. Set system time to round number (10:00 AM)

### Step 2: Capture Screenshots
```bash
# Take screenshot of entire window
Command + Shift + 4, then Space, then click window

# Or use built-in screenshot tool
Command + Shift + 5
```

### Step 3: Process Images

**Using Photoshop/Pixelmator Pro:**
1. Resize to exact dimensions (2560 x 1600)
2. Add text overlays with proper fonts
3. Apply subtle shadows/glows for depth
4. Ensure file size < 5MB
5. Export as PNG (for quality) or JPEG (for file size)

**Text Overlay Template:**
- Position: Bottom third of image
- Background: Semi-transparent blur or solid color
- Text alignment: Left-aligned or centered
- Shadow: Subtle drop shadow for readability

### Step 4: Review
- Check all text for typos
- Verify all UI elements are visible
- Ensure consistent branding
- Test on actual App Store listing (TestFlight)

---

## App Preview Video (Optional but Recommended)

### Video Specifications
- **Duration**: 15-30 seconds
- **Resolution**: 1920 x 1080 or higher
- **Format**: .mov, .mp4, or .m4v
- **File Size**: < 500 MB
- **Frame Rate**: 30 fps
- **Codec**: H.264 or HEVC

### Video Outline (30 seconds)

**0-5s**: Opening
- Craig-O logo animation
- Tagline: "Autonomous Mac System Manager"

**5-10s**: Problem
- Slow Mac visualization
- High memory/CPU usage
- Cluttered tabs

**10-20s**: Solution
- Quick cleanup in action
- Metrics improving in real-time
- Process management
- Browser tab cleanup

**20-25s**: Key Features
- AI agents
- Menu bar access
- iCloud sync
- Autonomous mode

**25-30s**: Call to Action
- "Transform Your Mac Today"
- Download button animation
- NeuralQuantum.ai logo

---

## Localization Notes

### Text in Screenshots
Keep text minimal and consider:
- Creating separate screenshots for each language
- Or use text-free screenshots with App Store description
- Key features should be evident without reading text

### Recommended Approach
- Primary screenshots: English with text overlays
- International markets: Same screenshots, localized overlays
- Or: UI-only screenshots without text overlays

---

## App Icon for Screenshots

### Display Requirements
- App icon should be visible in screenshots
- Can be shown in:
  - Menu bar
  - Dock (even though app is menu bar only, show for familiarity)
  - About screen
  - Splash screen

### Icon Variations
- Full color (primary)
- Monochrome (menu bar)
- Dark mode variant

---

## Screenshot Checklist

### Before Submission
- [ ] All 5-8 screenshots captured
- [ ] Correct dimensions (2560 x 1600)
- [ ] High quality (no pixelation)
- [ ] Consistent design language
- [ ] Text overlays readable
- [ ] No copyrighted content visible
- [ ] No personal information displayed
- [ ] App name and features clearly shown
- [ ] Light and dark mode represented
- [ ] File sizes under 5MB each
- [ ] Filenames descriptive and numbered
- [ ] Preview in App Store Connect interface

### Quality Check
- [ ] Screenshots tell a story
- [ ] Features are obvious
- [ ] Benefits are clear
- [ ] Professional appearance
- [ ] Consistent branding
- [ ] Error-free text
- [ ] Compelling visuals
- [ ] Competitive differentiation shown

---

## Asset Delivery

### Folder Structure
```
Screenshots/
├── macOS/
│   ├── 01-dashboard.png
│   ├── 02-cleanup.png
│   ├── 03-processes.png
│   ├── 04-browsers.png
│   ├── 05-menubar.png
│   ├── 06-autonomous.png (optional)
│   ├── 07-diagnostics.png (optional)
│   └── 08-sync.png (optional)
├── AppPreview/
│   └── craig-o-preview.mp4 (optional)
└── README.txt
```

### Upload to App Store Connect
1. Log in to App Store Connect
2. Navigate to your app
3. Select version
4. Go to App Store tab
5. Scroll to Screenshots section
6. Upload for each required size
7. Arrange in desired order
8. Add captions (optional)
9. Save changes

---

## Tips for Great Screenshots

### Do's
✓ Show real, useful features
✓ Use high-quality, realistic data
✓ Highlight unique selling points
✓ Make text large and readable
✓ Use consistent visual language
✓ Show the app in action
✓ Include both light and dark modes
✓ Display measurable results

### Don'ts
✗ Use Lorem Ipsum or placeholder text
✗ Show empty states only
✗ Include UI bugs or glitches
✗ Use low-resolution images
✗ Overcrowd with too much information
✗ Show outdated interface designs
✗ Include competitor apps
✗ Display error messages

---

## References

- [App Store Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
- [App Preview Specifications](https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications)
- [Marketing Guidelines](https://developer.apple.com/app-store/marketing/guidelines/)

---

**Created**: January 24, 2026
**For**: Craig-O Clean Terminator Edition v1.0
**Team**: NeuralQuantum.ai LLC
