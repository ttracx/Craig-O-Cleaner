# Craig-O-Clean

A production-grade macOS menu bar utility for Apple Silicon Macs that provides safe system cleanup, diagnostics, browser tab management, and memory optimization.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Optimized-green)

## Features

### System Dashboard
- Real-time CPU monitoring with per-core breakdown and load averages
- Memory metrics: used/free RAM, active/inactive/wired/compressed, swap usage
- Memory pressure indicator (Normal/Warning/Critical)
- Disk usage with percentage
- Network activity with download/upload speeds

### Process & App Manager
- Complete process list with CPU and memory usage
- Sort by CPU, memory, name, or PID
- Force quit and graceful termination
- Search and filter processes

### Browser Tab Management
- Safari, Chrome, Edge, Brave, Arc tab counting and listing
- Close tabs by URL pattern (user-configurable)
- Close all tabs (with confirmation)
- Heavy tab heuristic (browser helper memory + tab count)

### Memory Optimization
- Safe memory purge via privileged helper
- Cleanup candidate analysis
- Background app detection

### Capability-Driven Cleanup System
- 60+ curated capabilities in a single catalog
- Allowlist-only execution (no arbitrary commands)
- Preflight permission and state checks
- Dry-run/preview for destructive operations
- Full audit trail with stdout/stderr capture

---

## Architecture Overview

Craig-O-Clean uses a **capability-driven architecture** where every operation is defined as a structured capability in `catalog.json`. This single source of truth powers both the UI and execution layer.

### Core Components

```
Craig-O-Clean/
├── Core/
│   ├── CapabilityCatalog/         # Capability model, catalog.json, validator
│   │   ├── Capability.swift       # Data model for all operations
│   │   ├── CatalogStore.swift     # Loads/queries the catalog
│   │   ├── CatalogValidator.swift # Schema validation
│   │   └── catalog.json           # 60+ capabilities (single source of truth)
│   ├── Execution/                 # Command execution layer
│   │   ├── CommandExecutor.swift  # Allowlist-only execution entry point
│   │   ├── ProcessRunner.swift    # Process-based execution with streaming
│   │   └── OutputStreamer.swift   # Live stdout/stderr for UI
│   ├── Preflight/                 # Permission & state checks
│   │   └── PreflightEngine.swift  # Runs checks before every execution
│   ├── Logging/                   # Audit trail
│   │   ├── RunRecord.swift        # Structured execution record
│   │   └── LogStore.swift         # Persistence + export
│   └── (existing services)        # SystemMetrics, Memory, Browser, Permissions, etc.
├── AI/                            # Optional local AI orchestration
│   ├── OllamaClient.swift         # HTTP client for local Ollama
│   ├── WorkflowSchema.swift       # Strict JSON schema validation
│   └── Agents/
│       └── PlannerAgent.swift     # Plan generation + safety gating
├── UI/
│   └── Views/
│       ├── PermissionCenterView.swift  # Permission status + remediation
│       └── CapabilityLogView.swift     # Run log viewer with filtering
├── CraigOCleanHelper/            # Privileged XPC helper (SMJobBless)
└── Tests/                        # Unit + integration tests
```

## Build & Run

### Requirements
- Xcode 15+
- macOS 14.0+ (Sonoma)
- Apple Silicon recommended (Intel compatible)

### Steps
1. Open `Craig-O-Clean.xcodeproj` in Xcode
2. Select the `Craig-O-Clean` scheme
3. Build and Run (Cmd+R)

The app runs as a menu bar utility (no Dock icon). Look for the icon in the macOS menu bar.

### Code Signing
The app and helper must be signed with the same team ID. Update the signing settings in Xcode if building locally.

## Permissions

### Required
- **Automation**: Control browser tabs via AppleScript. Enabled per-browser in System Settings > Privacy & Security > Automation.

### Optional
- **Accessibility**: Advanced window management. System Settings > Privacy & Security > Accessibility.
- **Full Disk Access**: Read system logs and protected directories. System Settings > Privacy & Security > Full Disk Access.

### Privileged Helper
Elevated operations (memory purge, DNS flush, system maintenance) use a privileged helper installed via SMJobBless. The helper:
- Communicates via XPC with the main app
- Validates caller signature before executing
- Only accepts capability IDs from the allowlist
- Logs all operations for audit

## Capability System

### How It Works
1. All operations are defined in `catalog.json` with metadata (ID, risk class, permissions, preflight checks)
2. `CatalogStore` loads and indexes capabilities at app launch
3. `CommandExecutor` is the single execution entry point — it validates against the allowlist
4. `PreflightEngine` checks permissions and system state before execution
5. Every execution produces a `RunRecord` stored by `LogStore`

### Adding New Capabilities

1. Add the capability definition to `catalog.json`:
```json
{
  "id": "category.action_name",
  "title": "Human Readable Title",
  "description": "What this does",
  "category": "Diagnostics",
  "executorType": "process",
  "commandTemplate": "/usr/bin/command",
  "args": ["arg1"],
  "requiredPrivileges": "user",
  "requiredPermissions": ["none"],
  "riskClass": "safe",
  "preflightChecks": [],
  "dryRunSupport": false,
  "outputParsing": "none",
  "uiHints": {}
}
```

2. Run `CatalogValidatorTests` to verify the schema
3. The capability is now available via `CommandExecutor.execute(capabilityId:)`

### Risk Classes
- **safe**: No confirmation needed, no side effects
- **moderate**: Confirmation dialog shown, reversible changes
- **destructive**: Strong warning, irreversible changes (e.g., empty trash, delete archives)

### Executor Types
- **process**: Runs via Foundation.Process (non-privileged)
- **appleEvents**: Runs via NSAppleScript (browser tab management)
- **helperXpc**: Runs via privileged XPC helper (memory purge, DNS flush)

## AI Orchestration (Optional)

Craig-O-Clean supports local AI-assisted cleanup via [Ollama](https://ollama.ai):

1. Install Ollama: `brew install ollama`
2. Start the server: `ollama serve`
3. Pull a model: `ollama pull llama3.2`

The AI planner:
- Generates structured JSON plans referencing capability IDs only
- Cannot propose actions outside the catalog
- Elevated/destructive steps require explicit user approval
- Safety gating is enforced by `SafetyAgent` before execution

## Security Model

- **No arbitrary shell execution**: Only catalog capabilities can run
- **Least privilege**: Standard user by default, per-operation escalation
- **Destructive operations**: Require confirmation + dry-run preview when available
- **XPC helper**: Validates caller signature, allowlisted commands only
- **Audit trail**: Every execution logged with stdout/stderr capture

## QA Checklist

### First Run
- [ ] App appears in menu bar (no Dock icon)
- [ ] Status section shows memory pressure + disk free
- [ ] No permission prompts appear until user initiates an action

### Permission Handling
- [ ] Running a browser tab action prompts for Automation permission on first use
- [ ] Denied Automation shows "Fix" button linking to System Settings
- [ ] Full Disk Access denial shows informational message (not blocking)
- [ ] Accessibility denial shows informational message (not blocking)

### Safe Operations
- [ ] Quick diagnostics run without sudo prompt
- [ ] Diagnostics produce visible output in the log viewer
- [ ] "Quick Clean" never prompts for admin password
- [ ] "Quick Clean" never silently fails

### Elevated Operations
- [ ] Memory purge shows confirmation dialog
- [ ] DNS flush shows confirmation dialog
- [ ] System maintenance shows confirmation dialog
- [ ] Authorization failure shows clear error message

### Browser Operations
- [ ] Safari tab count works when Safari is running
- [ ] Chrome tab close by pattern closes matching tabs only
- [ ] Browser not running shows informative error
- [ ] Automation denied shows remediation steps

### Cleanup Safety
- [ ] No cleanup action deletes files outside defined paths
- [ ] Dry run/preview works for capabilities that support it
- [ ] Trash empty shows strong warning before proceeding
- [ ] Xcode archive deletion warns about App Store submissions

### Logging
- [ ] Every run produces a RunRecord visible in the log viewer
- [ ] Failed runs show stderr and remediation hints
- [ ] Log export creates a zip file
- [ ] Logs can be filtered by category and success/failure

### AI (if Ollama running)
- [ ] AI plan only references valid capability IDs
- [ ] Destructive steps show as "Awaiting Approval"
- [ ] Rejected steps are skipped during execution
- [ ] AI unavailable shows clear message (not a crash)

## License

Copyright 2026 CraigOClean.com powered by VibeCaaS.com, a division of NeuralQuantum.ai LLC. All rights reserved.
