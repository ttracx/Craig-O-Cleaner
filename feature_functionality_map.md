# Craig-O-Clean Feature & Functionality Map

This document maps major features to their implementations, UI routes (SwiftUI views), and API endpoints (if any). The app is a native macOS utility; most functionality relies on local system APIs rather than remote services.

| Feature / Capability | Functionality & Data Flow | UI Route / View | API Endpoint(s) | Dependencies & Notes |
| --- | --- | --- | --- | --- |
| System Dashboard | Streams CPU, memory, disk, and network metrics via `SystemMetricsService` and surfaces trend gauges/cards. | `DashboardView` (accessed through `MainAppView` navigation) | None (local system APIs) | Uses low-level macOS metrics collectors; drives menu bar health icon. |
| Process & App Manager | Lists processes, filters/searches, exports CSV, and supports graceful/force termination through `ProcessManager`. | `ProcessManagerView` | None (local process APIs) | Uses `proc_*` and `NSRunningApplication`; integrates with `ProcessDetailsView`. |
| Memory Cleanup & Optimization | Categorizes high-usage/background/inactive apps, enables Smart Cleanup and targeted termination via `MemoryOptimizerService`. | `MemoryCleanupView` | None (local system APIs) | Can invoke AppleScript-based purge for advanced cleanup; respects protected process exclusions. |
| Browser Tab Management | Discovers browser windows/tabs via AppleScript, groups by domain, and issues close actions per tab/window/domain using `BrowserAutomationService`. | `BrowserTabsView` | None (local AppleScript automation) | Requires Automation permission for Safari/Chromium-based browsers; handles tab stats per domain. |
| Menu Bar Mini-App | Status item with popover showing quick stats, top processes, and quick actions (Smart Cleanup, Close Background Apps). | `MenuBarContentView` (popover launched from status item) | None (local system APIs) | Popover injected with `SystemMetricsService`, `MemoryOptimizerService`, and auth/subscription context. |
| Settings & Permissions | Controls dock visibility, launch-at-login, refresh intervals, thresholds, diagnostics, and Automation permission prompts via `PermissionsService`. | `SettingsPermissionsView` | None (local system APIs) | Provides links to System Settings; displays permission state and troubleshooting guidance. |
| Auto Cleanup Scheduling | Schedules periodic cleanup rules and background behaviors via `AutoCleanupService`. | `AutoCleanupSettingsView` | None (local system APIs) | Leverages timers and memory/process heuristics; integrates with Memory Optimizer actions. |
| Authentication | Manages Sign in with Apple session restoration/persistence using `AuthManager` + `KeychainService`. | `MenuBarContentView` (auth prompts) | None (OS-provided Sign in with Apple) | Stores `userId` in keychain; session restored at launch; drives subscription context. |
| Subscriptions & Checkout | Initiates paid plan checkout flows through `StripeCheckoutService` and `SubscriptionManager`. | `MenuBarContentView` (upgrade/purchase flows) | `POST /stripe/create-checkout-session` (base URL from `StripeBackendBaseURL` in Info.plist) | Requires backend that returns `{ "url": "https://checkout.stripe.com/..." }`; opens URL in default browser. |
| Local Profile & Preferences | Persists user preferences, plan metadata, and cached identifiers via `LocalUserStore`. | `MainAppView` scope (environment object) | None (local storage) | Uses `UserDefaults` for lightweight persistence; feeds menu bar and settings screens. |

## Integration Review
- **Local-first architecture:** All core monitoring, process management, memory optimization, and browser automation run locally without remote APIs, reducing sync risk.
- **Stripe checkout dependency:** The only remote call is `POST /stripe/create-checkout-session` on the configured backend base URL. Without `StripeBackendBaseURL` in `Info.plist`, checkout throws `backendNotConfigured`. The backend must return a JSON body containing a `url` string, otherwise `invalidResponse` is thrown.
- **Permissions gating:** Browser automation features depend on Automation permissions; the settings view surfaces permission status and links to System Settings to request access.
- **Menu bar orchestration:** The status item initializes `SystemMetricsService` for live health indicators and injects auth/subscription services into the menu bar popover to keep user state consistent across quick actions.

## Potential Issues & Resolutions
1. **Stripe backend misconfiguration** – If `StripeBackendBaseURL` is unset or the backend does not return a `url` field, checkout fails. *Resolution:* populate `StripeBackendBaseURL` in `Info.plist`, ensure backend endpoint conforms to `{ url: string }` contract, and add backend availability checks before presenting purchase CTA.
2. **Automation permission gaps** – Browser tab actions can silently fail without Automation permission. *Resolution:* keep permission status visible in `SettingsPermissionsView` and prompt users to enable Automation for each browser; optionally disable destructive tab actions until permission is granted.
3. **User experience consistency** – Menu bar quick actions rely on the same services as the main windows; ensure updates (e.g., memory cleanup state) propagate via shared environment objects. Consider adding toast/notification confirmations for background cleanups to reinforce action feedback.

## Validation & Completion Report
- **Code traceability:** Verified feature-to-view-to-service wiring (e.g., menu bar popover created in `AppDelegate` with shared services; Stripe checkout uses backend URL + `POST /stripe/create-checkout-session`).
- **Endpoint audit:** Confirmed Stripe is the only external endpoint; all other functionality uses local system or AppleScript APIs.
- **Risk review:** Identified configuration (Stripe base URL) and permission (Automation) risks with mitigation steps above.

