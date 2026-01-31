# Craig-O-Clean MCP Connector

A **Model Context Protocol (MCP)** server that exposes Craig-O-Clean's macOS system maintenance capabilities to Claude and other MCP-compatible clients.

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/craig-o-clean-mcp?referralCode=craig-o-clean)

## Features

Connect Claude to your Mac's system maintenance tools:

- **System Diagnostics** - CPU, memory, disk, network metrics
- **Memory Optimization** - Purge inactive memory, identify cleanup candidates
- **Browser Management** - Tab counts, close tabs, quit browsers, clear caches
- **Quick Cleanup** - DNS flush, temp files, Quick Look reset, UI restarts
- **Deep Cleanup** - User caches, logs, crash reports, saved app states
- **Developer Tools** - Xcode, simulators, CocoaPods, npm, Docker cleanup
- **Process Management** - List and terminate processes

## Quick Start

### One-Click Deploy to Railway

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/craig-o-clean-mcp)

Click the button above to deploy instantly. Configure these environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `PORT` | Server port | `3847` |
| `ENABLE_ELEVATED` | Allow sudo operations | `false` |
| `ENABLE_DESTRUCTIVE` | Allow destructive operations | `false` |
| `AUTH_TOKEN` | Bearer token for authentication | (none) |

### Local Development

```bash
# Install dependencies
npm install

# Development mode with hot reload
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

### Docker

```bash
# Build image
docker build -t craig-o-clean-mcp .

# Run container
docker run -p 3847:3847 \
  -e ENABLE_ELEVATED=false \
  -e ENABLE_DESTRUCTIVE=false \
  craig-o-clean-mcp
```

## Connecting to Claude

### Claude.ai Custom Connector

1. Go to **Settings** > **Connectors** in Claude.ai
2. Click **Add custom connector**
3. Enter:
   - **Name**: Craig-O-Clean
   - **Remote MCP server URL**: Your deployed server URL (e.g., `https://your-app.railway.app`)
4. (Optional) Add OAuth credentials if using authentication
5. Click **Add**

### Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "craig-o-clean": {
      "url": "http://localhost:3847",
      "transport": "http"
    }
  }
}
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Server info and capabilities |
| `/health` | GET | Health check |
| `/tools` | GET | List available tools |
| `/tools/call` | POST | Execute a tool |
| `/resources` | GET | List available resources |
| `/resources/read` | POST | Read a resource |
| `/mcp` | POST | JSON-RPC 2.0 MCP endpoint |

## Available Tools

### System Diagnostics
- `get_system_metrics` - Comprehensive system metrics
- `get_memory_pressure` - Memory pressure level
- `get_top_processes` - Top processes by CPU/memory
- `get_disk_usage` - Disk space analysis
- `get_system_info` - macOS version, hardware, uptime
- `get_network_info` - Network interfaces and Wi-Fi

### Memory Management
- `purge_memory` - Release inactive memory (elevated)
- `get_cleanup_candidates` - Identify memory hogs

### Quick Cleanup
- `flush_dns_cache` - Flush DNS resolver (elevated)
- `clear_temp_files` - Remove temp files
- `reset_quick_look` - Reset preview cache
- `restart_system_ui` - Restart Finder/Dock/etc.

### Deep Cleanup
- `clear_user_caches` - Remove app caches
- `clear_logs` - Remove log files
- `clear_saved_app_state` - Clear saved states

### Browser Management
- `get_browser_tabs` - Tab count/list
- `close_browser_tabs` - Close all tabs (destructive)
- `quit_browser` - Quit browser apps
- `clear_browser_cache` - Clear cache files
- `find_heavy_browser_processes` - Find memory-heavy tabs

### Developer Tools
- `clear_xcode_data` - DerivedData, archives, device support
- `manage_simulators` - Delete/erase iOS simulators
- `clear_package_cache` - CocoaPods, npm, Swift PM, Homebrew
- `docker_cleanup` - Docker prune operations

### Disk Management
- `get_trash_size` - Check Trash size
- `empty_trash` - Empty Trash (destructive)
- `get_downloads_size` - Check Downloads size

### System Maintenance
- `restart_audio_service` - Fix audio issues (elevated)
- `restart_preferences_daemon` - Fix settings sync
- `run_maintenance_scripts` - Run periodic scripts (elevated)
- `spotlight_management` - Check/rebuild Spotlight (elevated)
- `list_launch_agents` - List background jobs

### Process Management
- `list_processes` - List running processes
- `terminate_process` - Kill a process by PID

## Security

### Permission Levels

Tools are categorized by permission requirements:

- **User** - Safe, no special permissions needed
- **Elevated** - Requires `ENABLE_ELEVATED=true` (uses sudo)
- **Destructive** - Requires `ENABLE_DESTRUCTIVE=true` (data loss possible)

### Authentication

Set `AUTH_TOKEN` environment variable to require Bearer token authentication:

```bash
AUTH_TOKEN=your-secret-token npm start
```

Then include the header in requests:
```
Authorization: Bearer your-secret-token
```

### Best Practices

1. **Don't enable elevated operations** on remote deployments
2. **Use authentication** in production
3. **Run locally** for full functionality with macOS
4. **Review destructive operations** before confirming

## Example Usage

### Get System Metrics

```bash
curl -X POST http://localhost:3847/tools/call \
  -H "Content-Type: application/json" \
  -d '{"name": "get_system_metrics", "arguments": {"include": "all"}}'
```

### Clear Old Caches

```bash
curl -X POST http://localhost:3847/tools/call \
  -H "Content-Type: application/json" \
  -d '{"name": "clear_user_caches", "arguments": {"type": "old_only"}}'
```

### Get Browser Tab Count

```bash
curl -X POST http://localhost:3847/tools/call \
  -H "Content-Type: application/json" \
  -d '{"name": "get_browser_tabs", "arguments": {"browser": "all", "info": "count"}}'
```

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Claude.ai     │────▶│  MCP Connector   │────▶│  macOS System   │
│   or Desktop    │◀────│  (This Server)   │◀────│  Commands       │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                              │
                              ▼
                        ┌──────────────────┐
                        │  Tool Executor   │
                        │  - Diagnostics   │
                        │  - Cleanup       │
                        │  - Browsers      │
                        │  - Dev Tools     │
                        └──────────────────┘
```

## Development

### Project Structure

```
mcp-connector/
├── src/
│   ├── index.ts      # Express server & MCP endpoints
│   ├── types.ts      # TypeScript type definitions
│   ├── tools.ts      # MCP tool definitions
│   └── executor.ts   # Command execution engine
├── package.json
├── tsconfig.json
├── Dockerfile
├── railway.json
└── README.md
```

### Adding New Tools

1. Add tool definition in `src/tools.ts`
2. Add command mapping in `src/executor.ts`
3. Rebuild and test

## License

MIT License - See [LICENSE](../LICENSE) for details.

## Related

- [Craig-O-Clean macOS App](../) - The main macOS application
- [Model Context Protocol](https://modelcontextprotocol.io/) - MCP specification
- [Claude](https://claude.ai/) - AI assistant by Anthropic
