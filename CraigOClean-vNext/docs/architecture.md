# Craig-O-Clean Architecture

## Overview

Craig-O-Clean uses a capability-driven architecture that allows a single codebase to power two distinct product editions while maintaining clean separation of concerns.

## Design Principles

1. **Capability-Driven**: UI reads capabilities, not build flags
2. **Protocol-Oriented**: Services defined by protocols, implemented per edition
3. **Dependency Injection**: Services provided via DI container
4. **Graceful Degradation**: Lite edition shows informative messages for unavailable features

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          UI Layer                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │Dashboard │ │ Cleanup  │ │Diagnostics│ │ Settings │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
│       │            │            │            │                   │
│       └────────────┴────────────┴────────────┘                   │
│                          │                                       │
│                    ┌─────┴─────┐                                │
│                    │ DI Container │                              │
│                    └─────┬─────┘                                │
└──────────────────────────┼───────────────────────────────────────┘
                           │
┌──────────────────────────┼───────────────────────────────────────┐
│                    Domain Layer                                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ UseCases │ │ Protocols│ │  Models  │ │Capabilities│          │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
└──────────────────────────────────────────────────────────────────┘
                           │
┌──────────────────────────┼───────────────────────────────────────┐
│                   Platform Layer                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Services                              │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │    │
│  │  │ Pro Services│  │Lite Services│  │Shared Services│    │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Privileged Helper (Pro only)                │    │
│  │  ┌─────────────┐  ┌─────────────┐                       │    │
│  │  │ XPC Client  │  │ Helper Daemon│                       │    │
│  │  └─────────────┘  └─────────────┘                       │    │
│  └─────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────┘
```

## Key Components

### Capabilities System

The `Capabilities` struct defines what the app can do:

```swift
struct Capabilities {
    let canDeleteSystemWideCaches: Bool
    let canDeleteUserCaches: Bool
    let canInspectDiskUsage: Bool
    let canExportDiagnostics: Bool
    let canRunPrivilegedOperations: Bool
    let canInstallHelperTool: Bool
    let canAutoUpdate: Bool
    let canUseExternalLicensing: Bool
}
```

Two providers implement `CapabilityProviding`:
- `DirectProCapabilities` - All capabilities enabled
- `AppStoreLiteCapabilities` - Limited to sandbox-safe operations

### Service Layer

Each service follows this pattern:

```
Protocol (in Domain)
    │
    ├── Base Implementation (shared logic)
    │       │
    │       ├── Pro Implementation (full features)
    │       │
    │       └── Lite Implementation (restricted)
    │
    └── No-Op Implementation (feature disabled)
```

Example:
```
CleanerService (protocol)
    │
    ├── SafeCleanerService (base)
    │       │
    │       ├── DirectProCleanerService
    │       │
    │       └── AppStoreCleanerService
```

### Dependency Injection

`DIContainer` instantiates services based on build flags:

```swift
#if APPSTORE_LITE
    cleanerService = AppStoreCleanerService(logger: logger)
#elseif DIRECT_PRO
    cleanerService = DirectProCleanerService(logger: logger)
#endif
```

Views receive dependencies via environment:

```swift
@EnvironmentObject var container: DIContainer
```

## Data Flow

### Cleanup Flow

```
User taps Scan
    │
    ▼
CleanupView calls viewModel.scan()
    │
    ▼
ViewModel calls cleanerService.scanTargets()
    │
    ▼
Service returns [CleanupScanResult]
    │
    ▼
UI displays preview
    │
    ▼
User confirms cleanup
    │
    ▼
Service.runCleanup() executes
    │
    ▼
Logger records actions
    │
    ▼
UI shows results
```

### Permission Flow (Pro)

```
Operation requires privileges
    │
    ▼
Check capabilities.canRunPrivilegedOperations
    │
    ├── false → Show Pro feature sheet
    │
    └── true → Check helperStatus
                    │
                    ├── installed → Proceed via XPC
                    │
                    └── not installed → Prompt install
```

## Module Boundaries

### Domain Module
- Pure Swift, no framework dependencies
- Contains: Models, Protocols, UseCases
- Can be shared via Swift Package

### Platform Module
- macOS-specific implementations
- Contains: Services, Capabilities, Helper
- Conditionally compiled per edition

### UI Module
- SwiftUI views
- Reads capabilities to show/hide features
- Shared between editions

## Extension Points

### Adding a New Service

1. Define protocol in `Domain/Protocols/`
2. Add capability flags if needed
3. Create base implementation
4. Create Pro/Lite variants
5. Register in DIContainer
6. Add to AppEnvironment if needed

### Adding a New Cleanup Target

1. Add to `CleanupTarget.userCacheTargets()` or `systemCacheTargets()`
2. Set `requiresPrivileges` appropriately
3. Lite service will auto-filter privileged targets

### Adding a Pro-Only Feature

1. Add capability flag
2. Check capability in UI
3. Show `ProFeatureSheet` if unavailable
4. Implement in Pro service only

## Testing Strategy

### Unit Tests
- Capability mapping tests
- Service behavior tests
- Path validation tests

### Integration Tests
- DI container setup
- Service interactions
- End-to-end cleanup flow

### UI Tests
- Navigation
- Feature visibility per edition
- Error handling

## Performance Considerations

- Async/await for all I/O operations
- Lazy scanning (don't calculate sizes until needed)
- Cancellation support for long operations
- In-memory log store with size limit

## Security Model

See `security-permissions.md` for detailed security architecture.
