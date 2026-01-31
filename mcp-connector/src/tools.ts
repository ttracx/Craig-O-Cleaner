/**
 * Craig-O-Clean MCP Tool Definitions
 * Maps Craig-O-Clean capabilities to MCP tools
 */

import type { MCPTool } from './types.js';

/**
 * System diagnostics and monitoring tools
 */
export const diagnosticsTools: MCPTool[] = [
  {
    name: 'get_system_metrics',
    description: 'Get comprehensive system metrics including CPU usage, memory status, disk space, and system information. Returns real-time data about your Mac\'s performance.',
    inputSchema: {
      type: 'object',
      properties: {
        include: {
          type: 'string',
          description: 'Which metrics to include: "all", "cpu", "memory", "disk", or "network"',
          enum: ['all', 'cpu', 'memory', 'disk', 'network'],
          default: 'all'
        }
      }
    }
  },
  {
    name: 'get_memory_pressure',
    description: 'Check the current memory pressure level on the system. Useful for diagnosing memory-related performance issues.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'get_top_processes',
    description: 'List the top processes by resource usage (CPU or memory). Helps identify resource-hungry applications.',
    inputSchema: {
      type: 'object',
      properties: {
        sortBy: {
          type: 'string',
          description: 'Sort processes by "cpu" or "memory"',
          enum: ['cpu', 'memory'],
          default: 'memory'
        },
        limit: {
          type: 'string',
          description: 'Number of processes to return (default: 15)',
          default: '15'
        }
      }
    }
  },
  {
    name: 'get_disk_usage',
    description: 'Get detailed disk usage information including free space, home directory breakdown, and large files.',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          description: 'Type of disk info: "overview", "home", "library", or "large_files"',
          enum: ['overview', 'home', 'library', 'large_files'],
          default: 'overview'
        }
      }
    }
  },
  {
    name: 'get_system_info',
    description: 'Get macOS version, hardware overview, uptime, and other system information.',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          description: 'Info type: "version", "hardware", "uptime", "battery", or "all"',
          enum: ['version', 'hardware', 'uptime', 'battery', 'all'],
          default: 'all'
        }
      }
    }
  },
  {
    name: 'get_network_info',
    description: 'Get network interface information and Wi-Fi connection details.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  }
];

/**
 * Memory management tools
 */
export const memoryTools: MCPTool[] = [
  {
    name: 'purge_memory',
    description: 'Release inactive memory back to the system. This can help when your Mac feels sluggish due to memory pressure. Requires elevated privileges.',
    inputSchema: {
      type: 'object',
      properties: {
        syncFirst: {
          type: 'string',
          description: 'Sync disks before purging (recommended): "true" or "false"',
          enum: ['true', 'false'],
          default: 'true'
        }
      }
    }
  },
  {
    name: 'get_cleanup_candidates',
    description: 'Analyze running processes and identify memory cleanup candidates (background apps, inactive apps, heavy memory users).',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  }
];

/**
 * Quick cleanup tools (safe, instant operations)
 */
export const quickCleanTools: MCPTool[] = [
  {
    name: 'flush_dns_cache',
    description: 'Flush the DNS resolver cache to fix name resolution issues or force DNS refresh.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'clear_temp_files',
    description: 'Remove temporary files from user caches to free up space.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'reset_quick_look',
    description: 'Reset Quick Look preview cache to fix preview rendering issues.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'restart_system_ui',
    description: 'Restart system UI components to fix display glitches.',
    inputSchema: {
      type: 'object',
      properties: {
        component: {
          type: 'string',
          description: 'Component to restart: "finder", "dock", "menubar", "controlcenter", or "notifications"',
          enum: ['finder', 'dock', 'menubar', 'controlcenter', 'notifications']
        }
      },
      required: ['component']
    }
  }
];

/**
 * Deep cleanup tools (more thorough, use with caution)
 */
export const deepCleanTools: MCPTool[] = [
  {
    name: 'clear_user_caches',
    description: 'Remove all user-level application caches. Apps will rebuild caches as needed, but may run slower initially.',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          description: 'Cache type: "all", "apple_only", or "old_only" (7+ days)',
          enum: ['all', 'apple_only', 'old_only'],
          default: 'old_only'
        }
      }
    }
  },
  {
    name: 'clear_logs',
    description: 'Remove log files to free up disk space. Old logs (7+ days) are safer to remove.',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          description: 'Log type: "user", "old_only" (7+ days), or "crash_reports"',
          enum: ['user', 'old_only', 'crash_reports'],
          default: 'old_only'
        }
      }
    }
  },
  {
    name: 'clear_saved_app_state',
    description: 'Remove saved application states (window positions, etc.). Apps will start fresh.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  }
];

/**
 * Browser management tools
 */
export const browserTools: MCPTool[] = [
  {
    name: 'get_browser_tabs',
    description: 'Get information about open browser tabs including count and URLs. Requires Automation permission for the browser.',
    inputSchema: {
      type: 'object',
      properties: {
        browser: {
          type: 'string',
          description: 'Browser to query: "safari", "chrome", or "all"',
          enum: ['safari', 'chrome', 'all'],
          default: 'all'
        },
        info: {
          type: 'string',
          description: 'Info type: "count" or "list"',
          enum: ['count', 'list'],
          default: 'count'
        }
      }
    }
  },
  {
    name: 'close_browser_tabs',
    description: 'Close browser tabs. Use with caution as this cannot be undone. Requires Automation permission.',
    inputSchema: {
      type: 'object',
      properties: {
        browser: {
          type: 'string',
          description: 'Browser: "safari" or "chrome"',
          enum: ['safari', 'chrome']
        },
        action: {
          type: 'string',
          description: 'Action: "close_all" to close all tabs',
          enum: ['close_all']
        }
      },
      required: ['browser', 'action']
    }
  },
  {
    name: 'quit_browser',
    description: 'Gracefully quit a browser application.',
    inputSchema: {
      type: 'object',
      properties: {
        browser: {
          type: 'string',
          description: 'Browser to quit: "safari", "chrome", "firefox", "edge", "brave", "arc", or "all"',
          enum: ['safari', 'chrome', 'firefox', 'edge', 'brave', 'arc', 'all']
        },
        force: {
          type: 'string',
          description: 'Force quit (may lose unsaved work): "true" or "false"',
          enum: ['true', 'false'],
          default: 'false'
        }
      },
      required: ['browser']
    }
  },
  {
    name: 'clear_browser_cache',
    description: 'Clear browser cache files. Browser must be quit first.',
    inputSchema: {
      type: 'object',
      properties: {
        browser: {
          type: 'string',
          description: 'Browser: "safari" or "chrome"',
          enum: ['safari', 'chrome']
        }
      },
      required: ['browser']
    }
  },
  {
    name: 'find_heavy_browser_processes',
    description: 'Find browser helper processes that are using excessive memory.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  }
];

/**
 * Developer tools cleanup
 */
export const devToolsCleanup: MCPTool[] = [
  {
    name: 'clear_xcode_data',
    description: 'Clear Xcode caches and build data to free up significant disk space.',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          description: 'Data to clear: "derived_data", "archives" (caution), "device_support", or "simulator_caches"',
          enum: ['derived_data', 'archives', 'device_support', 'simulator_caches'],
          default: 'derived_data'
        }
      }
    }
  },
  {
    name: 'manage_simulators',
    description: 'Manage iOS Simulators - delete unavailable or erase all.',
    inputSchema: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          description: 'Action: "delete_unavailable" (safe) or "erase_all" (destructive)',
          enum: ['delete_unavailable', 'erase_all'],
          default: 'delete_unavailable'
        }
      }
    }
  },
  {
    name: 'clear_package_cache',
    description: 'Clear package manager caches (CocoaPods, npm, Swift PM).',
    inputSchema: {
      type: 'object',
      properties: {
        manager: {
          type: 'string',
          description: 'Package manager: "cocoapods", "npm", "swiftpm", or "homebrew"',
          enum: ['cocoapods', 'npm', 'swiftpm', 'homebrew']
        }
      },
      required: ['manager']
    }
  },
  {
    name: 'docker_cleanup',
    description: 'Clean up Docker resources to free disk space.',
    inputSchema: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          description: 'Action: "info" (show usage), "prune" (unused only), or "prune_all" (everything)',
          enum: ['info', 'prune', 'prune_all'],
          default: 'info'
        }
      }
    }
  }
];

/**
 * Disk management tools
 */
export const diskTools: MCPTool[] = [
  {
    name: 'get_trash_size',
    description: 'Show the current size of the Trash folder.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'empty_trash',
    description: 'Permanently remove all items in the Trash. This cannot be undone.',
    inputSchema: {
      type: 'object',
      properties: {
        confirm: {
          type: 'string',
          description: 'Confirm deletion by setting to "yes"',
          enum: ['yes', 'no']
        }
      },
      required: ['confirm']
    }
  },
  {
    name: 'get_downloads_size',
    description: 'Show the current size of the Downloads folder.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  }
];

/**
 * System maintenance tools
 */
export const systemTools: MCPTool[] = [
  {
    name: 'restart_audio_service',
    description: 'Restart the Core Audio daemon to fix audio issues. Audio may cut out briefly.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'restart_preferences_daemon',
    description: 'Restart the preferences daemon to fix settings sync issues.',
    inputSchema: {
      type: 'object',
      properties: {}
    }
  },
  {
    name: 'run_maintenance_scripts',
    description: 'Execute macOS maintenance scripts (daily, weekly, monthly). These run automatically but can be triggered manually.',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          description: 'Maintenance type: "daily" (quick) or "full" (all scripts)',
          enum: ['daily', 'full'],
          default: 'daily'
        }
      }
    }
  },
  {
    name: 'spotlight_management',
    description: 'Check Spotlight status or rebuild the search index.',
    inputSchema: {
      type: 'object',
      properties: {
        action: {
          type: 'string',
          description: 'Action: "status" or "rebuild" (may take hours)',
          enum: ['status', 'rebuild'],
          default: 'status'
        }
      }
    }
  },
  {
    name: 'list_launch_agents',
    description: 'List background launch agents and jobs running on the system.',
    inputSchema: {
      type: 'object',
      properties: {
        type: {
          type: 'string',
          description: 'Type: "all" or "user_only"',
          enum: ['all', 'user_only'],
          default: 'user_only'
        }
      }
    }
  }
];

/**
 * Process management tools
 */
export const processTools: MCPTool[] = [
  {
    name: 'list_processes',
    description: 'List running processes with their resource usage.',
    inputSchema: {
      type: 'object',
      properties: {
        filter: {
          type: 'string',
          description: 'Filter: "all", "user_only", or "high_memory" (>100MB)',
          enum: ['all', 'user_only', 'high_memory'],
          default: 'user_only'
        }
      }
    }
  },
  {
    name: 'terminate_process',
    description: 'Terminate a running process by PID. Use graceful termination when possible.',
    inputSchema: {
      type: 'object',
      properties: {
        pid: {
          type: 'string',
          description: 'Process ID to terminate'
        },
        force: {
          type: 'string',
          description: 'Force kill (SIGKILL): "true" or "false"',
          enum: ['true', 'false'],
          default: 'false'
        }
      },
      required: ['pid']
    }
  }
];

/**
 * Combined tool registry
 */
export const allTools: MCPTool[] = [
  ...diagnosticsTools,
  ...memoryTools,
  ...quickCleanTools,
  ...deepCleanTools,
  ...browserTools,
  ...devToolsCleanup,
  ...diskTools,
  ...systemTools,
  ...processTools
];

/**
 * Tool category mapping for documentation
 */
export const toolCategories = {
  'System Diagnostics': diagnosticsTools.map(t => t.name),
  'Memory Management': memoryTools.map(t => t.name),
  'Quick Cleanup': quickCleanTools.map(t => t.name),
  'Deep Cleanup': deepCleanTools.map(t => t.name),
  'Browser Management': browserTools.map(t => t.name),
  'Developer Tools': devToolsCleanup.map(t => t.name),
  'Disk Management': diskTools.map(t => t.name),
  'System Maintenance': systemTools.map(t => t.name),
  'Process Management': processTools.map(t => t.name)
};
