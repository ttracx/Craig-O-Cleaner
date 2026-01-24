# Craig-O-Clean Terminator Edition

**Autonomous System Management for macOS Silicon with AI Orchestration**

The Terminator Edition is a comprehensive system management solution that leverages autonomous AI agents to manage, clean, optimize, and diagnose macOS Silicon devices. It features full terminal read/write permissions and can operate with or without local AI model support via Ollama.

---

## Features

### 🤖 Autonomous Agent System

- **Multi-Agent Architecture**: Specialized agents for different system management tasks
- **Team-Based Orchestration**: Agents work together in coordinated teams
- **AI-Powered Decision Making**: Ollama integration for intelligent task assignment
- **Full Admin Permissions**: Complete system access for comprehensive management

### 🧹 System Cleanup

- Memory purging and optimization
- Cache cleaning (user, browser, developer, system)
- Temporary file removal
- Trash management
- DNS cache flushing

### 📊 Diagnostics & Monitoring

- Real-time system health monitoring
- CPU, memory, disk, and network analysis
- Battery status (MacBooks)
- Health score calculation
- Performance recommendations

### 🌐 Browser Management

- Tab management across all major browsers (Safari, Chrome, Firefox, Edge, Brave, Arc)
- Resource-heavy tab detection and closure
- Browser cache cleanup
- Tab count monitoring

### ⚙️ Process Management

- Process listing and monitoring
- Resource hog detection
- Safe process termination
- Launch agent management
- Background task control

### 🤖 AI Integration

- Local Ollama AI model support
- Intelligent task assignment
- Automated recommendations
- Natural language interaction

---

## Directory Structure

```
TerminatorEdition/
├── Core/
│   ├── CommandExecutor.swift      # Shell command execution engine
│   └── TerminatorEngine.swift     # Main orchestration engine
├── Modules/
│   ├── Process/
│   │   └── ProcessManager.swift   # Process management
│   ├── Browser/
│   │   └── BrowserManager.swift   # Browser tab management
│   ├── Memory/
│   │   └── MemoryManager.swift    # Memory optimization
│   ├── Cache/
│   │   └── CacheManager.swift     # Cache cleaning
│   ├── Disk/
│   │   └── DiskManager.swift      # Disk space management
│   ├── Diagnostics/
│   │   └── DiagnosticsManager.swift # System diagnostics
│   ├── Utilities/
│   │   └── SystemUtilities.swift  # System utilities
│   └── Automation/
│       └── AutomationScheduler.swift # Task scheduling
├── Agents/
│   ├── Core/
│   │   ├── AgentProtocols.swift   # Agent interfaces
│   │   ├── BaseAgent.swift        # Base agent class
│   │   └── AgentOrchestrator.swift # Agent coordination
│   ├── Specialists/
│   │   ├── CleanupAgent.swift     # Cleanup specialist
│   │   ├── DiagnosticsAgent.swift # Diagnostics specialist
│   │   ├── BrowserAgent.swift     # Browser specialist
│   │   └── ProcessAgent.swift     # Process specialist
│   ├── Teams/
│   │   └── AgentTeam.swift        # Team coordination
│   └── AI/
│       └── OllamaProvider.swift   # Ollama AI integration
├── Scripts/
│   ├── terminator-cleanup.sh      # Quick cleanup script
│   └── terminator-diagnostics.sh  # Diagnostics script
├── Config/
└── TerminatorApp.swift            # Main entry point
```

---

## Agent Teams

### Cleanup Team
- **Members**: CleanupAgent, BrowserAgent
- **Mission**: Comprehensive system cleanup
- **Capabilities**: Memory purging, cache cleaning, browser optimization

### Diagnostics Team
- **Members**: DiagnosticsAgent, ProcessAgent
- **Mission**: System health analysis
- **Capabilities**: Performance monitoring, health reporting

### Optimization Team
- **Members**: ProcessAgent, BrowserAgent, CleanupAgent
- **Mission**: Resource optimization
- **Capabilities**: Process management, memory optimization

### Emergency Response Team
- **Members**: All agents
- **Mission**: Critical system recovery
- **Capabilities**: Full system intervention

---

## Tools & Skills

### Cleanup Tools
| Tool | Description |
|------|-------------|
| `purge_memory` | Purge inactive memory and disk caches |
| `clear_caches` | Clear user and application caches |
| `clean_temp_files` | Clean temporary files |
| `empty_trash` | Empty the user's trash |
| `flush_dns` | Flush DNS cache |

### Browser Tools
| Tool | Description |
|------|-------------|
| `list_browsers` | List running browsers |
| `get_tabs` | Get all browser tabs |
| `close_tab` | Close a specific tab |
| `close_heavy_tabs` | Close resource-heavy tabs |
| `clear_browser_cache` | Clear browser caches |

### Process Tools
| Tool | Description |
|------|-------------|
| `list_processes` | List running processes |
| `find_process` | Find process by name |
| `kill_process` | Terminate a process |
| `force_quit_app` | Force quit an application |
| `get_resource_hogs` | Find resource-heavy processes |

### Diagnostics Tools
| Tool | Description |
|------|-------------|
| `system_info` | Get system information |
| `cpu_info` | Get CPU details |
| `memory_info` | Get memory usage |
| `disk_info` | Get disk usage |
| `health_report` | Generate health report |

---

## Usage

### Swift API

```swift
import TerminatorEdition

// Initialize
let app = TerminatorApp.shared
await app.initialize()

// Quick cleanup
let result = await app.quickCleanup()
print("Memory freed: \(result.memoryFreed)")

// Get health report
let health = await app.getHealthReport()
print("Health score: \(health.healthScore)")

// Execute team mission
let mission = await app.executeTeamMission(
    teamType: .cleanup,
    missionType: .deepCleanup
)

// Enable autonomous mode
app.enableAutonomousMode(
    memoryThreshold: 85,
    diskThreshold: 90,
    checkInterval: 300
)

// Get AI recommendations (requires Ollama)
if let recommendations = await app.getAIRecommendations() {
    print(recommendations)
}
```

### Shell Scripts

```bash
# Quick cleanup
./Scripts/terminator-cleanup.sh

# Cleanup with trash emptying
./Scripts/terminator-cleanup.sh --empty-trash

# System diagnostics
./Scripts/terminator-diagnostics.sh
```

---

## AI Integration with Ollama

### Prerequisites

1. Install Ollama: https://ollama.ai
2. Pull a model:
   ```bash
   ollama pull llama3.2
   ```
3. Start Ollama:
   ```bash
   ollama serve
   ```

### Configuration

```swift
await app.initializeAI(
    host: "localhost",
    port: 11434,
    model: "llama3.2"
)
```

### Supported Models

- `llama3.2` (recommended)
- `llama3.1`
- `mistral`
- `codellama`
- Any Ollama-compatible model

---

## Automation

### Scheduled Tasks

```swift
// Schedule daily cleanup at 3 AM
engine.scheduler.scheduleDaily(
    name: "daily_cleanup",
    description: "Daily memory cleanup",
    hour: 3,
    minute: 0
) {
    await app.quickCleanup()
}

// Schedule recurring task every 5 minutes
engine.scheduler.scheduleRecurring(
    name: "monitor",
    interval: 300
) {
    await app.getHealthReport()
}
```

### Trigger-Based Automation

```swift
// Memory pressure trigger
engine.scheduler.addMemoryPressureRule(
    name: "auto_cleanup",
    threshold: 90,
    actions: [.cleanMemory, .closeBrowserTabs(memoryThresholdMB: 500)]
)

// Disk space trigger
engine.scheduler.addDiskSpaceRule(
    name: "disk_cleanup",
    threshold: 95,
    actions: [.cleanTemporaryFiles, .cleanCaches]
)
```

---

## Security Considerations

- Full admin permissions required for some operations
- System critical processes are protected from termination
- SIP (System Integrity Protection) is respected
- User data is never deleted without explicit permission
- All operations are logged for audit purposes

---

## Requirements

- macOS 13.0+ (Ventura or later)
- Apple Silicon (M1/M2/M3/M4)
- Xcode 15.0+ (for development)
- Ollama (optional, for AI features)

---

## License

Part of Craig-O-Clean project.

---

## Version

Terminator Edition v1.0
Optimized for macOS Sequoia / Sonoma on Apple Silicon
