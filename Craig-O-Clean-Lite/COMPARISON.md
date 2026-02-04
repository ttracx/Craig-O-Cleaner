# Craig-O-Clean: Lite vs. Full Version Comparison

Choose the right version for your needs.

## Quick Decision Guide

**Choose Lite if you:**
- Want simple system monitoring
- Don't need browser control
- Prefer minimalist apps
- Are new to system utilities
- Want the smallest footprint

**Choose Full if you:**
- Manage many browser tabs
- Need advanced process control
- Want detailed system insights
- Require customizable settings
- Are a power user

## Feature Comparison

### System Monitoring

| Feature | Lite | Full |
|---------|------|------|
| CPU Usage | ✅ Total | ✅ Per-core + Total |
| Memory Usage | ✅ Basic | ✅ Detailed (Active/Inactive/Wired/Compressed) |
| Memory Pressure | ❌ | ✅ Visual Indicator |
| Disk Usage | ✅ Basic | ✅ Detailed with % |
| Network Monitoring | ❌ | ✅ Upload/Download speeds |
| Refresh Rate | ⚙️ Fixed 5s | ⚙️ Configurable 1-10s |

### Process Management

| Feature | Lite | Full |
|---------|------|------|
| Process List | ✅ Top 10 | ✅ All processes |
| Process Search | ❌ | ✅ By name or bundle ID |
| Filter Options | ❌ | ✅ User apps/System/Heavy apps |
| Sort Options | ⚙️ Memory only | ⚙️ Name/CPU/Memory/PID |
| Process Details | ❌ | ✅ PID, args, path, creation time |
| Force Quit | ❌ | ✅ With safety checks |
| CSV Export | ❌ | ✅ Process list export |

### Memory Cleanup

| Feature | Lite | Full |
|---------|------|------|
| Quick Cleanup | ✅ One-click | ✅ Multi-step workflow |
| Smart Analysis | ❌ | ✅ Categorized suggestions |
| Category Filters | ❌ | ✅ Heavy/Background/Inactive/Browser |
| Quick Actions | ✅ 1 option | ✅ 3 smart options |
| Memory Purge | ✅ Basic | ✅ Advanced with admin control |
| Cleanup Preview | ❌ | ✅ Review before executing |

### Browser Management

| Feature | Lite | Full |
|---------|------|------|
| Safari Support | ❌ | ✅ Full control |
| Chrome Support | ❌ | ✅ Full control |
| Edge Support | ❌ | ✅ Full control |
| Brave Support | ❌ | ✅ Full control |
| Arc Support | ❌ | ✅ Full control |
| Tab Listing | ❌ | ✅ All tabs with URLs |
| Close Individual Tabs | ❌ | ✅ Yes |
| Close by Domain | ❌ | ✅ Bulk domain close |
| Close Duplicates | ❌ | ✅ Smart duplicate detection |
| Domain Statistics | ❌ | ✅ Tab count by domain |
| Permission Guide | ❌ | ✅ Step-by-step setup |

### User Interface

| Feature | Lite | Full |
|---------|------|------|
| Menu Bar Icon | ✅ Brain icon | ✅ Brain icon |
| Mini Dashboard | ✅ Basic stats | ✅ Advanced stats |
| Main Window | ❌ | ✅ Full Control Center |
| Quick Actions Menu | ✅ 1 action | ✅ Multiple actions |
| Right-click Menu | ❌ | ✅ Context menu |
| Keyboard Shortcuts | ⚙️ ⌘Q only | ⚙️ ⌘O, ⌘Q, ⌘R |
| Dark Mode | ✅ Supported | ✅ Supported |

### Settings & Preferences

| Feature | Lite | Full |
|---------|------|------|
| General Settings | ❌ | ✅ Dock, Login, Notifications |
| Monitoring Config | ❌ | ✅ Refresh intervals, thresholds |
| Permission Management | ❌ | ✅ View and request permissions |
| Diagnostics | ❌ | ✅ System info, diagnostic reports |
| Privacy Controls | ✅ Local only | ✅ Local only |

## Technical Comparison

### Code & Size

| Metric | Lite | Full |
|--------|------|------|
| Swift Files | 3 | 20+ |
| Lines of Code | ~400 | ~2,500+ |
| App Size | ~2 MB | ~5 MB |
| Memory Usage | ~15-20 MB | ~30-50 MB |
| CPU Usage (idle) | <1% | <2% |
| Dependencies | 0 | 0 |

### Architecture

| Aspect | Lite | Full |
|--------|------|------|
| Design Pattern | Simple MVVM | Advanced MVVM |
| Services Layer | 1 service | 4+ services |
| UI Components | 3 views | 10+ views |
| Test Coverage | None | Unit + UI tests |
| Documentation | Basic | Comprehensive |

### Platform Requirements

| Requirement | Lite | Full |
|-------------|------|------|
| macOS Version | 14+ | 14+ |
| Xcode Version | 15+ | 15+ |
| Swift Version | 5.9+ | 5.9+ |
| Apple Silicon | Supported | Optimized |
| Intel Macs | Supported | Supported |

## Permissions Required

### Lite
- ⚠️ Admin (for memory purge only)

### Full
- ⚠️ Admin (for memory purge)
- 🔐 Automation (for browser control)
- 🔐 Accessibility (optional, for advanced features)

## Use Cases

### Perfect for Lite

1. **Casual Users**
   - Check system health occasionally
   - Quick memory cleanup when Mac feels slow
   - Minimal UI preferred

2. **Minimalists**
   - Want only essential features
   - Dislike feature bloat
   - Prefer simple, focused tools

3. **Beginners**
   - New to system monitoring
   - Learning about Mac performance
   - Don't need advanced controls

### Perfect for Full

1. **Power Users**
   - Manage dozens of browser tabs
   - Need detailed process information
   - Want complete system control

2. **Developers**
   - Monitor resource-intensive builds
   - Need to force quit stuck processes
   - Want CSV export for analysis

3. **Professional Users**
   - Multitask heavily
   - Run memory-intensive apps
   - Need customizable settings

## Performance Impact

### Lite
- **Startup**: < 1 second
- **Memory**: 15-20 MB average
- **CPU**: Negligible (<1% idle)
- **Battery**: Minimal impact
- **Network**: None (no connections)

### Full
- **Startup**: 1-2 seconds
- **Memory**: 30-50 MB average
- **CPU**: Very low (1-2% when active)
- **Battery**: Low impact
- **Network**: None (no connections)

## Privacy & Security

Both versions:
- ✅ No network connections
- ✅ No data collection
- ✅ All processing local
- ✅ Open source code
- ✅ No third-party dependencies

## Upgrade Path

Starting with Lite? Easy upgrade:

1. Both versions can coexist
2. No settings to migrate
3. Full version in parent directory
4. Just build and run!

```bash
# From Lite directory
cd ..
open Craig-O-Clean.xcodeproj
```

## Cost Comparison

| Version | Price | Value |
|---------|-------|-------|
| Lite | Free | Essential features |
| Full | Free | Complete feature set |

Both are **completely free** and **open source**!

## Which Version to Choose?

### Start with Lite if:
- ✅ Unsure what you need
- ✅ Want to try first
- ✅ Prefer simple tools
- ✅ Only need basics

### Start with Full if:
- ✅ Know you need browser control
- ✅ Want all features available
- ✅ Are comfortable with more options
- ✅ Need advanced process management

## Bottom Line

**Lite**: Essential system monitoring in the simplest possible form.
**Full**: Complete system control with every feature you could need.

**Can't decide?** Try Lite first. You can always upgrade later!

---

Both versions are:
- 🆓 Completely free
- 🔓 Open source
- 🔒 Privacy-focused
- 💚 Made with love for macOS

**Choose the one that fits your workflow!**
