# Craig-O-Clean Suite Architecture

This document describes the technical architecture and design patterns shared across all Craig-O-Clean Suite platforms.

## Overview

Craig-O-Clean Suite is a family of native applications for system monitoring and process management, built with platform-specific technologies while sharing core concepts and business logic patterns.

## Monorepo Structure

```
craig-o-clean-suite/
├── shared/                    # Cross-platform shared definitions
│   ├── schemas/               # JSON schemas for data models
│   │   ├── system-metrics.schema.json
│   │   ├── process-info.schema.json
│   │   └── entitlement.schema.json
│   ├── branding/              # Design tokens and assets
│   │   └── design-tokens.json
│   ├── entitlement/           # Feature gating configuration
│   │   └── feature-config.json
│   └── telemetry/             # Analytics event definitions
│       └── events.json
├── android/                   # Android app (Kotlin + Jetpack Compose)
├── windows/                   # Windows 11 app (C# + WinUI 3)
├── linux/                     # Linux app (Flutter)
├── backend/                   # Stripe billing backend (Node.js)
└── docs/                      # Additional documentation
```

## Shared Architectural Patterns

### 1. Service Layer Architecture

All platforms implement a consistent service layer with the following core services:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                           │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐                │
│  │  Dashboard   │ │   Process    │ │   Settings   │                │
│  │    Screen    │ │   Manager    │ │    Screen    │                │
│  └──────────────┘ └──────────────┘ └──────────────┘                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ ViewModels / State Management
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          SERVICE LAYER                               │
│  ┌────────────────────┐  ┌────────────────────┐                     │
│  │ SystemMetricsService │  │ ProcessManagerService │                │
│  │                      │  │                      │                  │
│  │ • CPU metrics        │  │ • Process list       │                  │
│  │ • Memory metrics     │  │ • End process        │                  │
│  │ • Swap metrics       │  │ • Force kill         │                  │
│  │ • Load average       │  │ • Protected list     │                  │
│  └────────────────────┘  └────────────────────┘                     │
│  ┌────────────────────┐  ┌────────────────────┐                     │
│  │ EntitlementManager  │  │  BillingProvider    │                   │
│  │                      │  │                      │                  │
│  │ • Check features     │  │ • Query products     │                  │
│  │ • Trial state        │  │ • Purchase flow      │                  │
│  │ • Subscription state │  │ • Restore purchases  │                  │
│  │ • Feature gating     │  │ • Manage subscription│                  │
│  └────────────────────┘  └────────────────────┘                     │
│  ┌────────────────────┐                                              │
│  │ DiagnosticsLogger   │                                             │
│  │                      │                                            │
│  │ • Error logging      │                                            │
│  │ • Analytics events   │                                            │
│  │ • Crash reporting    │                                            │
│  └────────────────────┘                                              │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ Platform APIs
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     PLATFORM INTEGRATION LAYER                       │
│  Android: ActivityManager, UsageStats, WorkManager                   │
│  Windows: WMI, Performance Counters, Win32 APIs                      │
│  Linux: /proc filesystem, D-Bus, polkit                              │
└─────────────────────────────────────────────────────────────────────┘
```

### 2. SystemMetricsService

Responsible for collecting system-level metrics.

#### Interface

```
interface SystemMetricsService {
    // Collected metrics
    cpuMetrics: CpuMetrics
    memoryMetrics: MemoryMetrics
    swapMetrics: SwapMetrics?
    loadAverage: LoadAverage?

    // Operations
    startMonitoring(intervalMs: number)
    stopMonitoring()
    refreshNow(): Promise<void>

    // Configuration
    setRefreshInterval(intervalMs: number)
}
```

#### Platform Implementations

| Platform | CPU Source | Memory Source | Swap Source |
|----------|-----------|---------------|-------------|
| Android | /proc/stat, Runtime | ActivityManager.MemoryInfo | ActivityManager |
| Windows | Performance Counters | GlobalMemoryStatusEx | GlobalMemoryStatusEx |
| Linux | /proc/stat | /proc/meminfo | /proc/meminfo |

### 3. ProcessManagerService

Responsible for listing and managing processes.

#### Interface

```
interface ProcessManagerService {
    // State
    processes: ProcessInfo[]
    topCpuProcess: ProcessInfo?
    topMemoryProcess: ProcessInfo?

    // Operations
    refreshProcessList(): Promise<void>
    endProcess(pid: number): Promise<Result>
    forceKillProcess(pid: number): Promise<Result>

    // Helpers
    isProtectedProcess(pid: number): boolean
    canTerminate(process: ProcessInfo): boolean
}
```

#### Platform Capabilities

| Platform | List Processes | End Process | Force Kill | Notes |
|----------|---------------|-------------|------------|-------|
| Android | Limited (UsageStats) | No* | No* | *Navigate to App Info for user action |
| Windows | Full (WMI/Toolhelp) | Yes | Yes | Requires appropriate permissions |
| Linux | Full (/proc) | Yes (SIGTERM) | Yes (SIGKILL) | May require elevated permissions |

### 4. EntitlementManager

Manages subscription state and feature gating.

#### Interface

```
interface EntitlementManager {
    // State
    currentEntitlement: Entitlement
    isTrialActive: boolean
    isSubscribed: boolean
    trialDaysRemaining: number?

    // Feature checks
    canUseFeature(feature: Feature): boolean
    getFeatureGatingReason(feature: Feature): string?

    // Operations
    refreshEntitlement(): Promise<void>
    startTrial(): Promise<Result>

    // Offline support
    isOfflineGracePeriodActive: boolean
    offlineGraceExpiry: Date?
}
```

#### Feature Gating Logic

```
function canUseFeature(feature: Feature): boolean {
    // Check subscription status
    if (isSubscribed) return true

    // Check trial status
    if (isTrialActive) return true

    // Check offline grace period (for Stripe platforms)
    if (isOfflineGracePeriodActive) return true

    // Check if feature is available in free tier
    return freeFeatures.includes(feature)
}
```

### 5. BillingProvider

Abstract interface for platform-specific billing.

#### Interface

```
interface BillingProvider {
    // Products
    getProducts(): Promise<Product[]>

    // Purchase
    purchase(productId: string): Promise<PurchaseResult>

    // Restore
    restorePurchases(): Promise<RestoreResult>

    // Management
    openManageSubscription(): void

    // Events
    onPurchaseUpdated: (purchase: Purchase) => void
    onEntitlementChanged: (entitlement: Entitlement) => void
}
```

#### Platform Implementations

| Platform | Provider | Trial Support | Offline Support |
|----------|----------|---------------|-----------------|
| Android | Google Play Billing | Yes (store-managed) | Limited |
| Windows | Microsoft Store IAP | Yes | Limited |
| Windows (Direct) | Stripe | Yes (API-managed) | 72-hour grace |
| Linux | Stripe | Yes (API-managed) | 72-hour grace |

## Platform-Specific Architecture

### Android Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ANDROID APP                                │
├─────────────────────────────────────────────────────────────┤
│  UI Layer: Jetpack Compose + Material 3                       │
│  ├── DashboardScreen                                          │
│  ├── ProcessListScreen                                        │
│  ├── SettingsScreen                                           │
│  └── PaywallScreen                                            │
├─────────────────────────────────────────────────────────────┤
│  ViewModel Layer: Hilt-injected ViewModels                    │
│  ├── DashboardViewModel                                       │
│  ├── ProcessListViewModel                                     │
│  └── BillingViewModel                                         │
├─────────────────────────────────────────────────────────────┤
│  Domain Layer: Use Cases + Repositories                       │
│  ├── SystemMetricsRepository                                  │
│  ├── ProcessRepository                                        │
│  └── EntitlementRepository                                    │
├─────────────────────────────────────────────────────────────┤
│  Data Layer: Data Sources + Models                            │
│  ├── SystemMetricsDataSource (ActivityManager, /proc)         │
│  ├── ProcessDataSource (UsageStats, RunningAppProcessInfo)    │
│  └── BillingDataSource (Google Play Billing Library)          │
├─────────────────────────────────────────────────────────────┤
│  Platform Services                                            │
│  ├── NotificationService (Persistent notification)            │
│  ├── TileService (Quick Settings tile)                        │
│  └── WorkManager (Background refresh)                         │
└─────────────────────────────────────────────────────────────┘
```

### Windows Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   WINDOWS 11 APP                              │
├─────────────────────────────────────────────────────────────┤
│  UI Layer: WinUI 3 + Windows App SDK                          │
│  ├── MainWindow (NavigationView shell)                        │
│  ├── DashboardPage                                            │
│  ├── ProcessListPage                                          │
│  └── SettingsPage                                             │
├─────────────────────────────────────────────────────────────┤
│  ViewModel Layer: CommunityToolkit.Mvvm                       │
│  ├── DashboardViewModel                                       │
│  ├── ProcessListViewModel                                     │
│  └── TrayViewModel                                            │
├─────────────────────────────────────────────────────────────┤
│  Service Layer                                                │
│  ├── SystemMetricsService (Performance Counters, WMI)         │
│  ├── ProcessService (Process class, Toolhelp32)               │
│  └── EntitlementService (Store/Stripe)                        │
├─────────────────────────────────────────────────────────────┤
│  Platform Integration                                         │
│  ├── TrayIconService (Win32 NotifyIcon)                       │
│  ├── ToastService (Windows notifications)                     │
│  └── SingleInstanceService                                    │
└─────────────────────────────────────────────────────────────┘
```

### Linux Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     LINUX APP                                 │
├─────────────────────────────────────────────────────────────┤
│  UI Layer: Flutter + Material 3                               │
│  ├── DashboardScreen                                          │
│  ├── ProcessListScreen                                        │
│  ├── SettingsScreen                                           │
│  └── PaywallScreen                                            │
├─────────────────────────────────────────────────────────────┤
│  State Management: Riverpod                                   │
│  ├── SystemMetricsProvider                                    │
│  ├── ProcessListProvider                                      │
│  └── EntitlementProvider                                      │
├─────────────────────────────────────────────────────────────┤
│  Platform Channels: Native FFI + Method Channels              │
│  ├── ProcReader (C/FFI for /proc parsing)                     │
│  ├── ProcessManager (SIGTERM/SIGKILL)                         │
│  └── KeyringService (libsecret)                               │
├─────────────────────────────────────────────────────────────┤
│  Platform Integration                                         │
│  ├── TrayService (StatusNotifier/AppIndicator)                │
│  ├── PolkitHelper (Privileged operations)                     │
│  └── SecretStorage (GNOME Keyring/KWallet)                    │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Metrics Update Flow

```
Timer/Interval
    │
    ▼
SystemMetricsService.refresh()
    │
    ├──► Platform-specific data collection
    │       • Android: ActivityManager, /proc/stat
    │       • Windows: PerformanceCounter, GlobalMemoryStatusEx
    │       • Linux: /proc/stat, /proc/meminfo
    │
    ▼
Parse and calculate metrics
    │
    ├──► Calculate CPU percentage
    ├──► Calculate memory pressure
    └──► Identify top consumers
    │
    ▼
Update observable state
    │
    ▼
UI reacts to state changes
    │
    ├──► Update dashboard widgets
    ├──► Update tray/notification
    └──► Check alert thresholds
```

### Purchase Flow

```
User taps Subscribe
    │
    ▼
BillingProvider.purchase(productId)
    │
    ├──► [Android] Launch Google Play billing flow
    ├──► [Windows] Launch Store purchase dialog
    └──► [Linux] Open Stripe checkout in browser
    │
    ▼
User completes purchase
    │
    ▼
BillingProvider receives confirmation
    │
    ├──► [Android] Acknowledge purchase
    ├──► [Windows] Fulfill license
    └──► [Linux] Verify with backend, store token
    │
    ▼
EntitlementManager.refreshEntitlement()
    │
    ▼
Update feature gates
    │
    ▼
UI reflects new entitlement
```

## Security Considerations

### Process Termination Safety

1. **Protected Process List**: All platforms maintain a denylist of critical system processes
2. **Confirmation Dialogs**: Force kill always requires user confirmation
3. **Graceful Termination First**: Always attempt graceful termination before force kill
4. **Permission Checks**: Verify process ownership before termination

### Billing Security

1. **Server Verification**: Stripe purchases verified server-side
2. **Token Storage**: Secure storage using platform keychain/keyring
3. **Offline Grace**: Limited offline access with expiration
4. **Receipt Validation**: Store receipts validated with platform APIs

### Data Privacy

1. **No PII Collection**: No personally identifiable information collected
2. **Local Processing**: All metrics processed locally
3. **Opt-Out Analytics**: Users can disable telemetry
4. **No Process Content**: Only process metadata, never process data

## Performance Considerations

### Memory Efficiency

- Lazy loading of process details
- Pagination for large process lists
- Efficient data structures for metrics history

### Battery/Power

- Configurable refresh intervals
- Background refresh optimization
- Minimal wake locks (Android)

### Responsiveness

- Async operations off main thread
- Progressive loading for process lists
- Optimistic UI updates

## Testing Strategy

### Unit Tests

- Service layer logic
- Entitlement calculations
- Feature gating rules
- Metric parsing

### Integration Tests

- Platform API interactions
- Billing flow mocking
- Process management (sandboxed)

### UI Tests

- Navigation flows
- Paywall interactions
- Settings persistence

## Versioning

All platforms share semantic versioning:
- Major: Breaking changes to user experience
- Minor: New features
- Patch: Bug fixes and improvements

Platform-specific build numbers may vary for store requirements.
