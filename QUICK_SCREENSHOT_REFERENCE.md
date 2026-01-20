# 📸 Quick Screenshot Reference Card

## 🎯 What You Need to Capture

| # | Screenshot | How to Get There | Keyboard Shortcut |
|---|------------|------------------|-------------------|
| 1 | Menu Bar Icon | Look top-right menu bar for 🧠 | `Cmd+Shift+4` → Select area |
| 2 | Popover (Light) | Click menu icon (Light mode) | `Cmd+Shift+4` `Space` → Click |
| 3 | Popover (Dark) | Click menu icon (Dark mode) | `Cmd+Shift+4` `Space` → Click |
| 4 | Search Active | Process Manager → Type in search | `Cmd+Shift+4` `Space` → Click |
| 5 | Quit Alert | Select app → Click "Terminate" | `Cmd+Shift+4` `Space` → Click |
| 6 | Force Quit Alert | Select process → "Force Quit" | `Cmd+Shift+4` `Space` → Click |
| 7 | Process List | Process Manager → Show apps | `Cmd+Shift+4` `Space` → Click |

---

## ⚡ Three Ways to Capture

### 1️⃣ Fastest: Interactive Script
```bash
python3 Scripts/capture_screenshots.py
```
- Guides you through everything
- Handles light/dark mode switching
- Perfect for beginners

### 2️⃣ Manual: macOS Built-in
```
Cmd+Shift+4 → Space → Click window
```
- Most control
- Native macOS tool
- Save to Desktop

### 3️⃣ Quick: Shell Script
```bash
bash Scripts/capture-screenshots.sh
```
- Simple prompts
- Press ENTER when ready
- 3-second countdown

---

## 🎨 Appearance Modes

### Switch to Light Mode
```
System Settings → Appearance → Light
```

### Switch to Dark Mode
```
System Settings → Appearance → Dark
```

---

## 🚀 Quick Commands

```bash
# Check if app is running
ps aux | grep Craig-O-Clean

# Launch the app
open "/Users/knightdev/Library/Developer/Xcode/DerivedData/Craig-O-Clean-dpvmereinewabibedxiucpgcsyxm/Build/Products/Debug/Craig-O-Clean.app"

# Restart the app
killall Craig-O-Clean && open [app path]

# List captured screenshots
ls -lh Screenshots/app-screenshots-20260118/

# View screenshot
open Screenshots/app-screenshots-20260118/01-menu-bar-icon.png
```

---

## 📁 Where Screenshots Go

**Default**: `Screenshots/app-screenshots-20260118/`

**macOS Default**: `~/Desktop/` (when using Cmd+Shift+4)

---

## ✅ Quick Checklist

Before each screenshot:
- [ ] UI is in the correct state
- [ ] No sensitive info visible
- [ ] Window is properly positioned
- [ ] Text is readable

After capturing:
- [ ] Open and verify quality
- [ ] Check file name is descriptive
- [ ] Ensure it's in the right directory

---

## 🔑 Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| **Capture full screen** | `Cmd+Shift+3` |
| **Capture selection** | `Cmd+Shift+4` |
| **Capture window** | `Cmd+Shift+4` then `Space` |
| **Cancel capture** | `Esc` |
| **Copy to clipboard** | Add `Ctrl` to any above |
| **Screenshot toolbar** | `Cmd+Shift+5` |

---

## 💡 Pro Tips

1. **Hidden menu bar items**: Click `>>` in menu bar if icon is hidden
2. **Steady cursor**: Hold `Space` while dragging to reposition selection
3. **Multiple shots**: Take 2-3 of each, pick the best
4. **Clean background**: Close unnecessary windows first
5. **Retina quality**: Captures are 2x resolution automatically

---

## 🆘 Common Issues

### "Craig-O-Clean not running"
```bash
open "/Users/knightdev/Library/Developer/Xcode/DerivedData/Craig-O-Clean-dpvmereinewabibedxiucpgcsyxm/Build/Products/Debug/Craig-O-Clean.app"
```

### "Menu bar icon not visible"
- Check top-right area of menu bar
- Click `>>` icon if items are hidden
- Restart the app

### "Permission denied"
- System Settings → Privacy & Security → Screen Recording
- Enable Terminal or your capture tool

### "Screenshots are blank"
- Grant Screen Recording permission
- Use window capture (`Cmd+Shift+4` + `Space`) instead
- Restart your Mac if persists

---

## 📖 Need More Help?

- **Full Guide**: `cat SCREENSHOT_CAPTURE_GUIDE.md`
- **Status**: `cat SCREENSHOT_STATUS.md`
- **Scripts**: `ls -l Scripts/capture*.sh Scripts/capture*.py`

---

**App is running and ready!** 🎉

Just choose your method and start capturing!
