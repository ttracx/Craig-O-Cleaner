# Craig-O-Clean Screenshots

This document describes the visual appearance and user interface of Craig-O-Clean.

## Menu Bar Icon

The app appears as a memory chip icon (📟) in the macOS menu bar:

```
┌─────────────────────────────────────┐
│  🔋 📶 🔍  [📟]  🔔 🎵  ⏰  🗓️  │  ← Menu Bar
└─────────────────────────────────────┘
                 ↑
          Craig-O-Clean Icon
```

**Icon Details**:
- System SF Symbol: "memorychip"
- Location: Menu bar (top-right area)
- Style: Matches system appearance (light/dark mode)
- Always visible when app is running

## Main Interface (Popover)

When you click the menu bar icon, a popover window appears:

```
┌─────────────────────────────────────────────┐
│  📟 Craig-O-Clean                      ↻    │  ← Header
│                                              │
│  Memory Usage          Processes            │
│  2.45 GB               23                   │
│  Last updated: 3:41 PM                      │
├──────────────────────────────────────────────┤
│  🔍 Search processes...                 ✕   │  ← Search Bar
├──────────────────────────────────────────────┤
│  Google Chrome         1.24 GB  [Force Quit]│
│  PID: 1234                                  │
│                                              │
│  Safari                  892 MB  [Force Quit]│
│  PID: 5678                                  │
│                                              │
│  Xcode                   687 MB  [Force Quit]│
│  PID: 9012                                  │
│                                              │
│  Slack                   543 MB  [Force Quit]│  ← Process List
│  PID: 3456                                  │
│                                              │
│  Finder                  234 MB  [Force Quit]│
│  PID: 7890                                  │
│                                              │
│  [More processes...]                        │
│                                              │
├──────────────────────────────────────────────┤
│  [🗑️ Purge Memory (sync && sudo purge)]    │  ← Footer
│                                              │
│  This will flush inactive memory and may    │
│  require admin privileges                   │
└──────────────────────────────────────────────┘
```

**Dimensions**: 400px wide × 500px tall

## Interface Sections

### 1. Header Section

```
┌─────────────────────────────────────────────┐
│  📟 Craig-O-Clean                      ↻    │
│                                              │
│  Memory Usage          Processes            │
│  2.45 GB               23                   │
│  Last updated: 3:41 PM                      │
└──────────────────────────────────────────────┘
```

**Elements**:
- App icon (blue memory chip)
- App name in bold
- Refresh button (circular arrow)
- Memory usage total (in GB)
- Process count
- Last update timestamp

**Colors**:
- Icon: Blue (#007AFF)
- Text: System primary/secondary
- Background: System control background

### 2. Search Bar

```
┌──────────────────────────────────────────────┐
│  🔍 Search processes...                 ✕   │
└──────────────────────────────────────────────┘
```

**Features**:
- Magnifying glass icon
- Placeholder text
- Clear button (X) when text is entered
- Real-time filtering
- Light gray background

### 3. Process List

```
┌──────────────────────────────────────────────┐
│  Google Chrome         1.24 GB  [Force Quit]│
│  PID: 1234                                  │
│                                              │
│  Safari                  892 MB  [Force Quit]│
│  PID: 5678                                  │
└──────────────────────────────────────────────┘
```

**Each Process Row Shows**:
- Process name (monospaced font)
- Process ID (PID) in smaller gray text
- Memory usage (formatted in MB or GB)
- Force Quit button (red text)

**Interactions**:
- Click row: Selects process (blue highlight)
- Click Force Quit: Terminates process
- Hover: Subtle highlight effect
- Scroll: Smooth scrolling for long lists

### 4. Footer Section

```
┌──────────────────────────────────────────────┐
│  [🗑️ Purge Memory (sync && sudo purge)]    │
│                                              │
│  This will flush inactive memory and may    │
│  require admin privileges                   │
└──────────────────────────────────────────────┘
```

**Elements**:
- Large prominent button
- Trash icon
- Button text explaining the command
- Warning text in small gray font
- Blue button color (system accent)

## Alert Dialogs

### Success Alert

```
┌─────────────────────────────┐
│  Success                    │
├─────────────────────────────┤
│  Memory purged successfully!│
│                             │
│            [OK]             │
└─────────────────────────────┘
```

### Error Alert

```
┌─────────────────────────────┐
│  Error                      │
├─────────────────────────────┤
│  Failed to purge memory:    │
│  User cancelled operation   │
│                             │
│            [OK]             │
└─────────────────────────────┘
```

### Force Quit Confirmation

```
┌─────────────────────────────┐
│  Force Quit                 │
├─────────────────────────────┤
│  Force quit Safari          │
│  (PID: 5678)?               │
│                             │
│            [OK]             │
└─────────────────────────────┘
```

## Visual States

### Normal State
- Default appearance
- All elements visible
- Processes listed and sorted

### Refreshing State
- Refresh button appears dimmed (50% opacity)
- Refresh button disabled
- Process list updates in place

### Search Active State
- Search field has focus
- Clear (X) button visible
- Filtered results shown
- "No results" if filter matches nothing

### Process Selected State
- Selected row has blue background (10% opacity)
- Other rows remain normal

### Empty State (No Processes)
```
┌──────────────────────────────────────────────┐
│                                              │
│                                              │
│         No processes found                   │
│         using significant memory             │
│                                              │
│                                              │
└──────────────────────────────────────────────┘
```

## Color Scheme

### Light Mode
- **Background**: System background (white/light gray)
- **Text**: Black/dark gray
- **Secondary Text**: Gray
- **Accent**: Blue (#007AFF)
- **Error**: Red (#FF3B30)
- **Dividers**: Light gray

### Dark Mode
- **Background**: System background (dark gray/black)
- **Text**: White/light gray
- **Secondary Text**: Gray
- **Accent**: Blue (#0A84FF)
- **Error**: Red (#FF453A)
- **Dividers**: Dark gray

**Note**: All colors automatically adapt to system appearance settings.

## Typography

### Font Families
- **App Title**: San Francisco (System font), Bold, 18pt
- **Statistics Labels**: San Francisco, Regular, 11pt
- **Statistics Values**: San Francisco, Semibold, 15pt
- **Process Names**: San Francisco Mono, Regular, 14pt
- **Process IDs**: San Francisco, Regular, 11pt
- **Memory Values**: San Francisco, Semibold, 15pt
- **Button Text**: San Francisco, Semibold, 14pt
- **Warning Text**: San Francisco, Regular, 10pt

### Text Hierarchy
1. **Primary**: App title, memory values
2. **Secondary**: Process names, button text
3. **Tertiary**: PIDs, timestamps, warnings

## Animations

### Popover Appearance
- Smooth fade and scale animation
- Duration: 0.2 seconds
- Appears below menu bar icon

### Process List Updates
- Smooth cross-fade between states
- No jarring replacements
- Maintains scroll position when possible

### Button States
- Hover: Subtle highlight
- Click: Brief scale down effect
- Disabled: Opacity 50%

## Responsive Behavior

### Fixed Size Window
- Width: 400px (fixed)
- Height: 500px (fixed)
- Does not resize
- Optimized for this specific dimension

### Scrolling
- Process list scrolls vertically
- Header and footer remain fixed
- Smooth momentum scrolling

## Accessibility

### VoiceOver Support
- All buttons have clear labels
- Process information properly announced
- Alert dialogs are accessible
- Keyboard navigation supported

### High Contrast
- Text meets WCAG AAA standards
- Clear visual boundaries
- Sufficient color contrast

### Reduced Motion
- Respects system preference
- Minimizes animations when enabled

## Usage Examples

### Finding a Memory-Hungry App

1. **Open the app** → Click menu bar icon
2. **View the list** → Processes sorted by memory usage
3. **Identify the culprit** → Top of the list
4. **Take action** → Force quit or monitor

### Searching for a Specific Process

1. **Open the app** → Click menu bar icon
2. **Click search field** → Type process name
3. **See results** → Filtered list appears
4. **Clear search** → Click X button

### Purging Memory

1. **Open the app** → Click menu bar icon
2. **Scroll to bottom** → Find purge button
3. **Click button** → Password prompt appears
4. **Enter password** → Memory is purged
5. **See confirmation** → Success alert shown

## Platform Integration

### Menu Bar
- Standard macOS menu bar icon
- Proper spacing and alignment
- Respects system appearance

### Window Style
- Native macOS popover
- System-standard shadows
- Proper window level (above others)

### System Dialogs
- Native password prompts
- Native alerts
- Standard button styles

## Best Practices Demonstrated

1. **Native Look**: Matches macOS design language
2. **Consistent**: Uses system fonts and colors
3. **Accessible**: Full VoiceOver support
4. **Responsive**: Smooth animations and transitions
5. **Informative**: Clear labels and feedback
6. **Safe**: Confirmation for destructive actions

---

**Note**: Actual screenshots to be added when running on a Mac. This document describes the intended visual appearance and user interface design.

To add actual screenshots, build and run the app on a Mac, then capture:
1. Menu bar icon location
2. Main popover window (light mode)
3. Main popover window (dark mode)
4. Search active state
5. Alert dialogs
6. Process list with various apps
