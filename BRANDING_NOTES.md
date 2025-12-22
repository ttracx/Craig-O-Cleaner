# Branding Notes

This document outlines the visual identity and brand guidelines for Craig-O-Clean, powered by VibeCaaS.

## Brand Overview

**Product Name**: Craig-O-Clean
**Tagline**: "A VibeCaaS-powered system cleaner and tab tamer for macOS."
**Category**: macOS System Utility
**Target Audience**: Mac power users who want control over their system resources

## Color Palette

Craig-O-Clean uses the VibeCaaS color system while maintaining macOS native appearance.

### Primary Colors

| Color Name | Hex Code | Usage |
|------------|----------|-------|
| Vibe Purple | `#6D4AFF` | Primary accent, CTAs, active states |
| Aqua Teal | `#14B8A6` | Secondary accent, success states, memory |
| Signal Amber | `#FF8C00` | Warnings, attention states, CPU alerts |

### Semantic Colors

| State | Color | Usage |
|-------|-------|-------|
| Success | Aqua Teal `#14B8A6` | Completed actions, good status |
| Warning | Signal Amber `#FF8C00` | Elevated pressure, caution |
| Error | System Red | Failures, critical pressure |
| Info | Vibe Purple `#6D4AFF` | Informational states |

### Implementation in SwiftUI

```swift
extension Color {
    // VibeCaaS Brand Colors
    static let vibePurple = Color(hex: "6D4AFF")
    static let aquaTeal = Color(hex: "14B8A6")
    static let signalAmber = Color(hex: "FF8C00")

    // Gradient
    static let brandGradient = LinearGradient(
        colors: [.vibePurple, .aquaTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
```

## Typography

Craig-O-Clean uses system fonts for optimal macOS integration.

### Primary Font
- **SF Pro**: Used for all UI elements, labels, and body text
- Leverages SwiftUI's `.body`, `.headline`, `.title` styles

### Monospace Font
- **SF Mono**: Used for technical data, metrics, and code-like information
- Process IDs, memory values, file paths

### Usage Guidelines

```swift
// Headlines and titles
.font(.title)
.font(.headline)

// Body text
.font(.body)

// Technical data and metrics
.font(.system(.body, design: .monospaced))

// Small labels
.font(.caption)
.font(.footnote)
```

## Visual Elements

### Cards

Use rounded cards for grouping related content:
- Corner radius: 12-16 points
- Light mode: White background with subtle shadow
- Dark mode: Elevated surface color
- Padding: 16-20 points

```swift
.background(Color(.windowBackgroundColor))
.clipShape(RoundedRectangle(cornerRadius: 12))
.shadow(color: .black.opacity(0.1), radius: 4, y: 2)
```

### Shadows

Keep shadows subtle and consistent:
- Color: Black with 5-10% opacity
- Radius: 4-8 points
- Y offset: 2-4 points

### Gradients

Use the brand gradient for hero sections and emphasis:
- Direction: 135 degrees (top-left to bottom-right)
- Colors: Vibe Purple to Aqua Teal

```swift
LinearGradient(
    gradient: Gradient(colors: [
        Color(hex: "6D4AFF"),
        Color(hex: "14B8A6")
    ]),
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```

## Theme Support

### Automatic Adaptation
- Respect system Light/Dark mode automatically
- Use semantic colors (`.primary`, `.secondary`, `.background`)
- Test all UI in both modes

### High Contrast Support
- Honor `accessibilityReduceTransparency`
- Use higher contrast borders when needed
- Ensure all text meets WCAG contrast requirements

```swift
@Environment(\.colorScheme) var colorScheme
@Environment(\.accessibilityReduceTransparency) var reduceTransparency
```

## Icons

### Menu Bar Icon
- Use SF Symbols or template image
- Must work as template for macOS tinting
- Size: 18x18 points
- Symbol: Custom or appropriate SF Symbol

### App Icons
- Follow Apple's macOS icon guidelines
- Use subtle gradients from brand palette
- Include app-specific visual elements

### UI Icons
- Prefer SF Symbols for consistency
- Use semantic symbols that convey meaning
- Examples:
  - `memorychip` - Memory
  - `cpu` - CPU
  - `internaldrive` - Disk
  - `network` - Network
  - `xmark.circle.fill` - Close/Terminate
  - `arrow.clockwise` - Refresh

## UI Copy Guidelines

### Tone
- **Friendly**: Approachable, not condescending
- **Technical**: Accurate, uses correct terminology
- **Action-oriented**: Clear about what will happen
- **Concise**: Brief but complete

### Examples

**Good**:
- "End Task" (clear action)
- "Memory pressure is elevated" (informative)
- "Close 3 background apps to free 512 MB" (specific)

**Avoid**:
- "Kill it!" (aggressive)
- "Things are getting tight" (vague)
- "Clean up some stuff" (unclear)

### Flow/Rhythm Metaphors (Optional)
VibeCaaS uses flow and rhythm metaphors, but keep them subtle:
- "Keep your system in flow"
- "Restore your Mac's rhythm"
- Use sparingly, not in every interaction

### Confirmation Dialogs

Always be clear about consequences:

```
Are you sure you want to force quit "App Name"?

This will immediately terminate the app. Any unsaved work may be lost.

[Cancel] [Force Quit]
```

## Memory Pressure Indicators

Use color consistently for memory pressure:

| Level | Color | Label |
|-------|-------|-------|
| Normal | Aqua Teal | "Normal" or "Good" |
| Elevated | Signal Amber | "Elevated" |
| Critical | System Red | "Critical" |

## Progress and Status

### Loading States
- Use subtle animations
- Show progress when possible
- Indicate ongoing operations clearly

### Success States
- Brief, dismissible notifications
- Aqua Teal accent
- Summarize what was accomplished

### Error States
- Clear explanation of what went wrong
- Suggest next steps if applicable
- Don't blame the user

## Accessibility

### Color Independence
- Never rely solely on color to convey information
- Include text labels or icons
- Use patterns or shapes as secondary indicators

### Screen Reader Support
- All interactive elements have accessibility labels
- Use `accessibilityHint` for complex actions
- Group related elements logically

### Keyboard Navigation
- All actions available via keyboard
- Visible focus indicators
- Logical tab order

## Component Examples

### Metric Card
```
┌─────────────────────────────┐
│ CPU Usage          ▼ 2s   │
│                           │
│  ████████░░░░░  45%       │
│                           │
│ 4 cores active            │
└─────────────────────────────┘
```

### Process Row
```
┌─────────────────────────────────────────┐
│ [Icon] Safari          2.3%  512 MB  → │
└─────────────────────────────────────────┘
```

### Menu Bar Popover
```
┌─────────────────────────┐
│ Craig-O-Clean           │
├─────────────────────────┤
│ CPU: ██░░  23%          │
│ RAM: ████  68%          │
│ Pressure: Normal        │
├─────────────────────────┤
│ Top CPU                 │
│ • Safari     12%        │
│ • Xcode       8%        │
│ • Slack       4%        │
├─────────────────────────┤
│ [Memory Clean]          │
│ [Open Craig-O-Clean]    │
└─────────────────────────┘
```

## Summary

| Element | Specification |
|---------|---------------|
| Primary Color | `#6D4AFF` Vibe Purple |
| Secondary Color | `#14B8A6` Aqua Teal |
| Accent Color | `#FF8C00` Signal Amber |
| Font | SF Pro (UI), SF Mono (metrics) |
| Corner Radius | 12-16 pts |
| Shadow | Black 5-10%, 4-8pt radius |
| Gradient | 135°, Purple → Teal |

Craig-O-Clean maintains the VibeCaaS identity while respecting macOS design conventions, ensuring users feel at home on their Mac.
