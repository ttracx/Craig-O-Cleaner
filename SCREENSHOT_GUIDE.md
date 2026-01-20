# Screenshot Capture Guide for App Store
## Craig-O-Clean

---

## 🎯 Quick Start (Automated)

### Run the Screenshot Helper Script

```bash
cd /Volumes/VibeStore/Craig-O-Cleaner
./capture-screenshots.sh
```

**The script will:**
1. Guide you through each screenshot
2. Give you 3-second countdown before capture
3. Save screenshots to `~/Desktop/Craig-O-Clean-Screenshots/`
4. Automatically name files: `01_Dashboard.png`, `02_Memory-Cleanup.png`, etc.

---

## 📸 Manual Capture Instructions

If you prefer to capture manually:

### Step 1: Set Display Resolution

**For 13-inch Display:**
1. Open **System Settings** → **Displays**
2. Set resolution to **2560 x 1600** (Scaled - More Space)

**For 16-inch Display (Optional):**
1. Set resolution to **3456 x 2234** (Scaled - More Space)

### Step 2: Prepare the App

1. **Open Craig-O-Clean**
2. **Maximize the window** (not full screen, just large)
3. **Position nicely** on screen with some desktop visible

### Step 3: Capture Each Screenshot

**Use macOS Screenshot Tool:**
- Press **⌘⇧5** to open screenshot toolbar
- Click **"Capture Selected Window"**
- Click on Craig-O-Clean window to capture
- Screenshots save to Desktop by default

**OR use Terminal:**
```bash
# Capture frontmost window
screencapture -o -w ~/Desktop/screenshot.png
```

---

## 📋 Required Screenshots (5 total)

### Screenshot 1: Dashboard View ⭐
**File name:** `01_Dashboard.png`

**What to show:**
- Main app window with Dashboard tab selected
- System metrics visible (CPU, Memory, Disk)
- Green/healthy status indicators
- Live charts showing good performance
- Running processes list at bottom

**Setup:**
1. Launch Craig-O-Clean
2. Make sure you're on the Dashboard tab
3. Wait for metrics to load (green indicators look best)
4. Show 4-5 running processes in the list

**Tips:**
- Close memory-heavy apps first to show healthy status
- Green indicators are more appealing than red/orange
- Make sure all 3 gauges (CPU, Memory, Disk) are visible

---

### Screenshot 2: Memory Cleanup ⭐
**File name:** `02_Memory-Cleanup.png`

**What to show:**
- Memory tab selected
- Cleanup candidates listed
- Memory ring showing usage percentage
- "Smart Cleanup" and "Background" buttons visible
- Memory breakdown bar with colors

**Setup:**
1. Click **Memory** tab
2. Click **"Analyze Memory"** button (if needed)
3. Wait for cleanup candidates to appear
4. Should show 3-5 apps that can be cleaned

**Tips:**
- Open a few extra apps before capturing to show candidates
- Memory ring should show 50-75% usage (not too high, not too low)
- Candidates list makes the feature more compelling

---

### Screenshot 3: Process Manager ⭐
**File name:** `03_Process-Manager.png`

**What to show:**
- Processes tab selected
- List of running applications
- Memory usage per process
- Process icons visible
- Sortable columns (Memory, CPU)

**Setup:**
1. Click **Processes** tab
2. Open several apps (Safari, Chrome, Mail, etc.)
3. Wait for process list to populate
4. Click **Memory** column header to sort by memory usage

**Tips:**
- Show 8-10 processes for good visual
- Mix of apps with different memory usage
- Icons make it more visually appealing

---

### Screenshot 4: Browser Tab Management ⭐
**File name:** `04_Browser-Tabs.png`

**What to show:**
- Browser tab selected
- Multiple tabs from Safari/Chrome listed
- Tab selection checkboxes
- "Close Selected" button
- Tab count indicator

**Setup:**
1. **Before capturing:** Open Safari with 5-8 tabs
2. Click **Browser** tab in Craig-O-Clean
3. Wait for tabs to load
4. Select 2-3 tabs with checkboxes
5. Show the "Close Selected" button active

**Tips:**
- More tabs = more impressive feature
- Show mix of different websites
- Having some tabs selected shows interactivity

---

### Screenshot 5: Menu Bar View ⭐
**File name:** `05_Menu-Bar.png`

**What to show:**
- Menu bar icon clicked
- Dropdown menu visible
- Mini-dashboard showing metrics
- Settings tab or Dashboard tab
- Compact, elegant UI

**Setup:**
1. Click **Craig-O-Clean icon** in menu bar (top-right)
2. Dropdown will appear
3. Show Dashboard tab or Settings tab
4. Capture the dropdown window

**Tips:**
- Make sure desktop background is clean/professional
- Other menu bar icons can be visible
- Shows the "always accessible" feature

---

## ✅ Screenshot Quality Checklist

Before uploading, verify each screenshot:

- [ ] **Resolution:** Exactly 2560x1600 (or 3456x2234 for 16-inch)
- [ ] **Format:** PNG (not JPEG)
- [ ] **Content:** Clear, easy to read text
- [ ] **UI:** No cut-off elements or weird cropping
- [ ] **Data:** Shows realistic, appealing data (not all zeros or errors)
- [ ] **Branding:** Craig-O-Clean name visible
- [ ] **Professional:** Clean desktop background visible
- [ ] **No personal info:** No email addresses, names, etc. visible

---

## 🎨 Pro Tips for Great Screenshots

### Visual Appeal
1. **Use light mode** (looks cleaner in App Store)
2. **Clean desktop background** (default macOS wallpaper works great)
3. **Healthy metrics** (green indicators, 50-70% usage)
4. **Multiple items** (processes, tabs, candidates) for visual interest

### Avoid These Mistakes
- ❌ Empty states ("No processes running")
- ❌ Error messages or warnings
- ❌ Critical/red status (unless showing before/after)
- ❌ Personal information (email, names)
- ❌ Wrong resolution (App Store will reject)
- ❌ Dark mode with dark background (hard to see edges)

### Make Features Obvious
- ✅ Show buttons and controls clearly
- ✅ Have data populated (not empty)
- ✅ Show interactive elements (checkboxes selected)
- ✅ Include some visual variety (different apps, tabs)

---

## 📏 Verify Resolution

After capturing, verify resolution:

```bash
# Check resolution of all screenshots
cd ~/Desktop/Craig-O-Clean-Screenshots
sips -g pixelWidth -g pixelHeight *.png
```

**Should output:**
```
01_Dashboard.png
  pixelWidth: 2560
  pixelHeight: 1600

02_Memory-Cleanup.png
  pixelWidth: 2560
  pixelHeight: 1600
...
```

---

## 🔄 Retake Instructions

If you need to retake a screenshot:

### Using the script:
```bash
./capture-screenshots.sh
# Press Q to skip screenshots you don't want to retake
# Press SPACE for the one you want to recapture
```

### Manually:
1. Delete the old screenshot from `~/Desktop/Craig-O-Clean-Screenshots/`
2. Set up the view in Craig-O-Clean
3. Capture new screenshot
4. Name it with same convention: `01_Dashboard.png`

---

## 📤 Upload to App Store Connect

Once you have all 5 screenshots:

1. **Go to App Store Connect**
2. **Select Craig-O-Clean** → **Version 3.0**
3. **Scroll to Screenshots** section
4. **Select "13-inch Display (2560 x 1600)"**
5. **Drag and drop** your screenshots in order:
   - 01_Dashboard.png
   - 02_Memory-Cleanup.png
   - 03_Process-Manager.png
   - 04_Browser-Tabs.png
   - 05_Menu-Bar.png
6. **Rearrange** if needed (drag to reorder)
7. **Click Save**

### Optional: 16-inch Display
8. **Change display resolution** to 3456 x 2234
9. **Re-run script** or manually recapture
10. **Upload to 16-inch section** in App Store Connect

---

## 🎬 Alternative: Screen Recording

You can also create a **preview video** (optional):

```bash
# Record 30-second demo
screencapture -v ~/Desktop/craig-o-clean-preview.mov

# Or use QuickTime Player:
# File → New Screen Recording
```

**What to show in video:**
1. Launch app (2 sec)
2. Dashboard with live metrics (5 sec)
3. Click to Memory tab, analyze (5 sec)
4. Click Smart Cleanup, show before/after (8 sec)
5. Show Browser tabs management (5 sec)
6. Click menu bar, show mini-dashboard (5 sec)

**Video specs:**
- Length: 15-30 seconds
- Format: .mov or .mp4
- Resolution: 1920x1080 or higher
- Max size: 500 MB

---

## 📞 Need Help?

If screenshots aren't turning out right:

1. **Check display resolution:** `system_profiler SPDisplaysDataType | grep Resolution`
2. **Verify app is open and functioning:** Make sure no errors showing
3. **Try different window sizes:** Not full screen, but large enough
4. **Use built-in screenshot tool:** ⌘⇧5 is easiest

---

**Ready to capture? Run the script:**

```bash
cd /Volumes/VibeStore/Craig-O-Cleaner
./capture-screenshots.sh
```

Good luck! 🚀
