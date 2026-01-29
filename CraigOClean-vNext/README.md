# Craig-O-Clean vNext

A dual-track macOS disk cleanup utility with separate editions for Mac App Store and direct distribution.

## Overview

Craig-O-Clean is designed with two distinct distribution tracks:

- **Craig-O-Clean Lite** (App Store): Sandboxed edition with user-level cleanup capabilities
- **Craig-O-Clean Pro** (Direct): Full-featured edition with system-wide cleanup and advanced features

Both editions share the same UI codebase while differing in backend capabilities through clean abstractions.

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Project Structure

```
CraigOClean-vNext/
├── CraigOClean/
│   ├── App/                    # App entry point and DI
│   │   ├── CraigOCleanApp.swift
│   │   ├── AppEnvironment.swift
│   │   └── DIContainer.swift
│   ├── UI/                     # SwiftUI views
│   │   ├── RootView.swift
│   │   ├── SidebarView.swift
│   │   ├── DashboardView.swift
│   │   ├── CleanupView.swift
│   │   ├── DiagnosticsView.swift
│   │   ├── SettingsView.swift
│   │   └── Components/
│   ├── Domain/                 # Business logic
│   │   ├── Models/
│   │   ├── Protocols/
│   │   └── UseCases/
│   ├── Platforms/              # Platform-specific implementations
│   │   ├── Capabilities/
│   │   └── Services/
│   ├── PrivilegedHelper/       # Pro-only privileged helper
│   ├── Config/                 # Build configurations
│   │   ├── Entitlements/
│   │   └── *.xcconfig
│   ├── Resources/              # Assets and strings
│   └── Tests/                  # Unit tests
├── docs/                       # Documentation
├── scripts/                    # Build scripts
└── README.md
```

## Building

### Setup

1. Clone the repository
2. Open `CraigOClean/CraigOClean.xcodeproj` in Xcode
3. Select the appropriate scheme

### Build Schemes

#### Craig-O-Clean Lite (App Store)

```bash
# Using xcodebuild
xcodebuild -scheme CraigOClean-AppStoreLite -configuration Release

# Or select "CraigOClean-AppStoreLite" scheme in Xcode
```

Features:
- Sandboxed execution
- User-level cache cleanup only
- No privileged operations
- App Store distribution ready

#### Craig-O-Clean Pro (Direct)

```bash
# Using xcodebuild
xcodebuild -scheme CraigOClean-DirectPro -configuration Release

# Or select "CraigOClean-DirectPro" scheme in Xcode
```

Features:
- Full disk access (with user permission)
- System-wide cleanup
- Privileged helper support
- Sparkle auto-updates
- External licensing

## Configuration

### Build Configurations

- `BuildSettings.xcconfig` - Shared settings
- `DirectPro.xcconfig` - Pro edition settings
- `AppStoreLite.xcconfig` - Lite edition settings

### Entitlements

- `DirectPro.entitlements` - Hardened runtime, no sandbox
- `AppStoreLite.entitlements` - App sandbox enabled

### Compiler Flags

- `DIRECT_PRO` - Defined for Pro builds
- `APPSTORE_LITE` - Defined for Lite builds

## Architecture

### Capability-Driven Design

The app uses a capability model to determine feature availability:

```swift
protocol CapabilityProviding {
    var capabilities: Capabilities { get }
}

struct Capabilities {
    let canDeleteSystemWideCaches: Bool
    let canDeleteUserCaches: Bool
    let canRunPrivilegedOperations: Bool
    // ... more capabilities
}
```

### Dependency Injection

Services are injected via `DIContainer`:

```swift
@MainActor
class DIContainer: ObservableObject {
    let cleanerService: any CleanerService
    let diagnosticsService: any DiagnosticsService
    let permissionService: any PermissionService
    // ...
}
```

### Service Abstraction

Each service has a protocol and multiple implementations:

- `CleanerService` → `SafeCleanerService`, `DirectProCleanerService`, `AppStoreCleanerService`
- `DiagnosticsService` → `BasicDiagnosticsService`, `DirectProDiagnosticsService`, `AppStoreDiagnosticsService`

## Features

### Implemented

- [x] User cache cleanup (Lite + Pro)
- [x] Log file cleanup (Lite + Pro)
- [x] Scan preview before cleanup
- [x] Cleanup history logging
- [x] System diagnostics collection
- [x] Edition-aware UI
- [x] Compare Editions sheet (Lite)
- [x] Apple-safe funnel design

### Pro-Only (Stub/Planned)

- [ ] System-wide cache cleanup
- [ ] Privileged helper tool
- [ ] Sparkle auto-updates
- [ ] License activation
- [ ] Diagnostic export

## App Store Compliance

The Lite edition follows Apple's guidelines:
- No in-app purchase links
- No upgrade prompts with pricing
- Informational "Compare Editions" only
- "Copy Link" instead of direct purchase CTAs
- Functional standalone product

See `docs/appstore-compliance.md` for details.

## Testing

```bash
# Run all tests
xcodebuild test -scheme CraigOClean-AppStoreLite -destination 'platform=macOS'

# Run specific test
xcodebuild test -scheme CraigOClean-AppStoreLite -only-testing:CraigOCleanTests/CapabilityTests
```

## Documentation

- `docs/architecture.md` - System architecture overview
- `docs/appstore-compliance.md` - App Store guidelines compliance
- `docs/security-permissions.md` - Permissions and security model
- `PrivilegedHelper/README.md` - Helper tool implementation guide

## License

Copyright 2024 CraigoSoft. All rights reserved.
