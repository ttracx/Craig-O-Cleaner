/**
 * Craig-O-Clean Command Executor
 * Maps MCP tool calls to system commands and executes them
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import type { ExecutionResult, ToolCallResponse } from './types.js';

const execAsync = promisify(exec);

// Timeout for command execution (in ms)
const DEFAULT_TIMEOUT = 30000;
const LONG_TIMEOUT = 120000;

/**
 * Command mapping from tool names to shell commands
 */
const commandMap: Record<string, {
  command: string | ((args: Record<string, unknown>) => string);
  timeout?: number;
  requiresElevation?: boolean;
  isDestructive?: boolean;
}> = {
  // Diagnostics
  'get_system_metrics': {
    command: (args) => {
      const include = args.include as string || 'all';
      switch (include) {
        case 'cpu': return 'top -l 1 -s 0 | head -15';
        case 'memory': return 'vm_stat && memory_pressure';
        case 'disk': return 'df -h /';
        case 'network': return 'networksetup -listallhardwareports';
        default: return 'echo "=== CPU ===" && top -l 1 -s 0 | grep "CPU usage" && echo "\\n=== MEMORY ===" && memory_pressure && echo "\\n=== DISK ===" && df -h / && echo "\\n=== UPTIME ===" && uptime';
      }
    }
  },
  'get_memory_pressure': {
    command: 'memory_pressure'
  },
  'get_top_processes': {
    command: (args) => {
      const sortBy = args.sortBy as string || 'memory';
      const limit = args.limit as string || '15';
      if (sortBy === 'cpu') {
        return `ps aux --sort=-%cpu | head -${limit}`;
      }
      return `ps -eo pid,rss,comm | sort -k2 -rn | head -${limit}`;
    }
  },
  'get_disk_usage': {
    command: (args) => {
      const type = args.type as string || 'overview';
      switch (type) {
        case 'home': return 'du -sh ~/* 2>/dev/null | sort -hr | head -15';
        case 'library': return 'du -sh ~/Library/* 2>/dev/null | sort -hr | head -15';
        case 'large_files': return 'find ~ -type f -size +100M -print0 2>/dev/null | xargs -0 ls -lh 2>/dev/null | head -20';
        default: return 'df -h / && echo "\\n=== DISK LIST ===" && diskutil list';
      }
    },
    timeout: LONG_TIMEOUT
  },
  'get_system_info': {
    command: (args) => {
      const type = args.type as string || 'all';
      switch (type) {
        case 'version': return 'sw_vers';
        case 'hardware': return 'system_profiler SPHardwareDataType';
        case 'uptime': return 'uptime';
        case 'battery': return 'pmset -g batt';
        default: return 'echo "=== macOS ===" && sw_vers && echo "\\n=== UPTIME ===" && uptime && echo "\\n=== BATTERY ===" && pmset -g batt 2>/dev/null || echo "No battery"';
      }
    }
  },
  'get_network_info': {
    command: 'networksetup -listallhardwareports && echo "\\n=== Wi-Fi ===" && networksetup -getinfo Wi-Fi 2>/dev/null'
  },

  // Memory Management
  'purge_memory': {
    command: (args) => {
      const syncFirst = args.syncFirst !== 'false';
      return syncFirst ? 'sync && sudo purge' : 'sudo purge';
    },
    requiresElevation: true
  },
  'get_cleanup_candidates': {
    command: 'ps -eo pid,rss,comm | sort -k2 -rn | head -20'
  },

  // Quick Clean
  'flush_dns_cache': {
    command: 'dscacheutil -flushcache && sudo killall -HUP mDNSResponder',
    requiresElevation: true
  },
  'clear_temp_files': {
    command: 'rm -rf ~/Library/Caches/TemporaryItems/* 2>/dev/null; echo "Temporary files cleared"'
  },
  'reset_quick_look': {
    command: 'qlmanage -r cache'
  },
  'restart_system_ui': {
    command: (args) => {
      const component = args.component as string;
      const commands: Record<string, string> = {
        'finder': 'killall Finder',
        'dock': 'killall Dock',
        'menubar': 'killall SystemUIServer',
        'controlcenter': 'killall ControlCenter',
        'notifications': 'killall NotificationCenter'
      };
      return commands[component] || 'echo "Unknown component"';
    }
  },

  // Deep Clean
  'clear_user_caches': {
    command: (args) => {
      const type = args.type as string || 'old_only';
      switch (type) {
        case 'all': return 'rm -rf ~/Library/Caches/*; echo "All user caches cleared"';
        case 'apple_only': return 'rm -rf ~/Library/Caches/com.apple.*; echo "Apple caches cleared"';
        default: return 'find ~/Library/Caches -type f -atime +7 -delete 2>/dev/null; echo "Old caches (7+ days) cleared"';
      }
    },
    timeout: LONG_TIMEOUT
  },
  'clear_logs': {
    command: (args) => {
      const type = args.type as string || 'old_only';
      switch (type) {
        case 'user': return 'rm -rf ~/Library/Logs/*; echo "User logs cleared"';
        case 'crash_reports': return 'rm -rf ~/Library/Application\\ Support/CrashReporter/*; echo "Crash reports cleared"';
        default: return 'find ~/Library/Logs -type f -mtime +7 -delete 2>/dev/null; echo "Old logs (7+ days) cleared"';
      }
    }
  },
  'clear_saved_app_state': {
    command: 'rm -rf ~/Library/Saved\\ Application\\ State/*; echo "Saved app states cleared"'
  },

  // Browser Management
  'get_browser_tabs': {
    command: (args) => {
      const browser = args.browser as string || 'all';
      const info = args.info as string || 'count';

      if (browser === 'safari' || browser === 'all') {
        if (info === 'list') {
          return `osascript -e 'tell application "Safari"
set urlList to {}
repeat with w in windows
repeat with t in tabs of w
set end of urlList to URL of t
end repeat
end repeat
return urlList
end tell'`;
        }
        return `osascript -e 'tell application "Safari"
set tabCount to 0
repeat with w in windows
set tabCount to tabCount + (count of tabs of w)
end repeat
return "Safari: " & tabCount & " tabs"
end tell'`;
      }
      if (browser === 'chrome') {
        if (info === 'list') {
          return `osascript -e 'tell application "Google Chrome"
set urlList to {}
repeat with w in windows
repeat with t in tabs of w
set end of urlList to URL of t
end repeat
end repeat
return urlList
end tell'`;
        }
        return `osascript -e 'tell application "Google Chrome"
set tabCount to 0
repeat with w in windows
set tabCount to tabCount + (count of tabs of w)
end repeat
return "Chrome: " & tabCount & " tabs"
end tell'`;
      }
      return 'echo "Browser not specified"';
    }
  },
  'close_browser_tabs': {
    command: (args) => {
      const browser = args.browser as string;
      if (browser === 'safari') {
        return `osascript -e 'tell application "Safari"
repeat with w in windows
try
tell w to close (tabs)
end try
end repeat
end tell'`;
      }
      if (browser === 'chrome') {
        return `osascript -e 'tell application "Google Chrome"
repeat with w in windows
try
close tabs of w
end try
end repeat
end tell'`;
      }
      return 'echo "Browser not specified"';
    },
    isDestructive: true
  },
  'quit_browser': {
    command: (args) => {
      const browser = args.browser as string;
      const force = args.force === 'true';
      const browsers: Record<string, { quit: string; forceQuit: string }> = {
        'safari': { quit: 'osascript -e \'tell application "Safari" to quit\'', forceQuit: 'killall -9 Safari' },
        'chrome': { quit: 'osascript -e \'tell application "Google Chrome" to quit\'', forceQuit: 'killall -9 "Google Chrome"' },
        'firefox': { quit: 'osascript -e \'tell application "Firefox" to quit\'', forceQuit: 'killall -9 Firefox' },
        'edge': { quit: 'osascript -e \'tell application "Microsoft Edge" to quit\'', forceQuit: 'killall -9 "Microsoft Edge"' },
        'brave': { quit: 'osascript -e \'tell application "Brave Browser" to quit\'', forceQuit: 'killall -9 "Brave Browser"' },
        'arc': { quit: 'osascript -e \'tell application "Arc" to quit\'', forceQuit: 'killall -9 Arc' },
        'all': {
          quit: 'osascript -e \'tell application "Safari" to quit\' -e \'tell application "Google Chrome" to quit\' -e \'tell application "Firefox" to quit\' -e \'tell application "Microsoft Edge" to quit\' -e \'tell application "Brave Browser" to quit\' -e \'tell application "Arc" to quit\' 2>/dev/null',
          forceQuit: 'killall Safari "Google Chrome" Firefox "Microsoft Edge" "Brave Browser" Arc 2>/dev/null'
        }
      };
      const b = browsers[browser];
      return b ? (force ? b.forceQuit : b.quit) : 'echo "Unknown browser"';
    }
  },
  'clear_browser_cache': {
    command: (args) => {
      const browser = args.browser as string;
      if (browser === 'safari') {
        return 'rm -rf ~/Library/Caches/com.apple.Safari/*; echo "Safari cache cleared"';
      }
      if (browser === 'chrome') {
        return 'rm -rf ~/Library/Caches/Google/Chrome/* ~/Library/Application\\ Support/Google/Chrome/Default/Cache/* ~/Library/Application\\ Support/Google/Chrome/Default/Code\\ Cache/*; echo "Chrome cache cleared"';
      }
      return 'echo "Browser not specified"';
    }
  },
  'find_heavy_browser_processes': {
    command: 'ps aux | grep -E "Helper|Web Content" | grep -E "Safari|Chrome|Edge|Brave|Firefox" | sort -k4 -rn | head -20'
  },

  // Developer Tools
  'clear_xcode_data': {
    command: (args) => {
      const type = args.type as string || 'derived_data';
      switch (type) {
        case 'derived_data': return 'rm -rf ~/Library/Developer/Xcode/DerivedData/*; echo "Xcode Derived Data cleared"';
        case 'archives': return 'rm -rf ~/Library/Developer/Xcode/Archives/*; echo "Xcode Archives cleared"';
        case 'device_support': return 'rm -rf ~/Library/Developer/Xcode/iOS\\ DeviceSupport/*; echo "iOS Device Support cleared"';
        case 'simulator_caches': return 'rm -rf ~/Library/Developer/CoreSimulator/Caches/*; echo "Simulator caches cleared"';
        default: return 'echo "Unknown type"';
      }
    },
    timeout: LONG_TIMEOUT,
    isDestructive: true
  },
  'manage_simulators': {
    command: (args) => {
      const action = args.action as string || 'delete_unavailable';
      if (action === 'erase_all') {
        return 'xcrun simctl erase all; echo "All simulators erased"';
      }
      return 'xcrun simctl delete unavailable; echo "Unavailable simulators deleted"';
    },
    isDestructive: true
  },
  'clear_package_cache': {
    command: (args) => {
      const manager = args.manager as string;
      const commands: Record<string, string> = {
        'cocoapods': 'rm -rf ~/Library/Caches/CocoaPods/*; echo "CocoaPods cache cleared"',
        'npm': 'npm cache clean --force',
        'swiftpm': 'rm -rf ~/Library/Caches/org.swift.swiftpm; echo "Swift PM cache cleared"',
        'homebrew': 'brew cleanup -s'
      };
      return commands[manager] || 'echo "Unknown package manager"';
    }
  },
  'docker_cleanup': {
    command: (args) => {
      const action = args.action as string || 'info';
      switch (action) {
        case 'info': return 'docker system df';
        case 'prune': return 'docker system prune -f';
        case 'prune_all': return 'docker system prune -af --volumes';
        default: return 'echo "Unknown action"';
      }
    },
    isDestructive: true
  },

  // Disk Management
  'get_trash_size': {
    command: 'du -sh ~/.Trash 2>/dev/null || echo "Trash is empty"'
  },
  'empty_trash': {
    command: (args) => {
      if (args.confirm === 'yes') {
        return 'rm -rf ~/.Trash/*; echo "Trash emptied"';
      }
      return 'echo "Confirmation required. Set confirm to yes to proceed."';
    },
    isDestructive: true
  },
  'get_downloads_size': {
    command: 'du -sh ~/Downloads 2>/dev/null'
  },

  // System Maintenance
  'restart_audio_service': {
    command: 'sudo killall coreaudiod; echo "Audio service restarting..."',
    requiresElevation: true
  },
  'restart_preferences_daemon': {
    command: 'killall cfprefsd; echo "Preferences daemon restarted"'
  },
  'run_maintenance_scripts': {
    command: (args) => {
      const type = args.type as string || 'daily';
      if (type === 'full') {
        return 'sudo periodic daily weekly monthly; echo "Full maintenance completed"';
      }
      return 'sudo periodic daily; echo "Daily maintenance completed"';
    },
    requiresElevation: true,
    timeout: LONG_TIMEOUT
  },
  'spotlight_management': {
    command: (args) => {
      const action = args.action as string || 'status';
      if (action === 'rebuild') {
        return 'sudo mdutil -E /; echo "Spotlight index rebuild initiated"';
      }
      return 'sudo mdutil -s /';
    },
    requiresElevation: true
  },
  'list_launch_agents': {
    command: (args) => {
      const type = args.type as string || 'user_only';
      if (type === 'all') {
        return 'launchctl list | head -30';
      }
      return 'ls -la ~/Library/LaunchAgents/ 2>/dev/null || echo "No user launch agents"';
    }
  },

  // Process Management
  'list_processes': {
    command: (args) => {
      const filter = args.filter as string || 'user_only';
      switch (filter) {
        case 'all': return 'ps aux | head -30';
        case 'high_memory': return 'ps -eo pid,rss,comm | awk \'$2 > 100000\' | sort -k2 -rn | head -20';
        default: return 'ps aux -U $USER | head -30';
      }
    }
  },
  'terminate_process': {
    command: (args) => {
      const pid = args.pid as string;
      const force = args.force === 'true';
      if (!pid || !/^\d+$/.test(pid)) {
        return 'echo "Invalid PID"';
      }
      return force ? `kill -9 ${pid}; echo "Process ${pid} force terminated"` : `kill ${pid}; echo "Process ${pid} terminated"`;
    }
  }
};

/**
 * Execute a tool command
 */
export async function executeCommand(
  toolName: string,
  args: Record<string, unknown>,
  options: {
    allowElevated?: boolean;
    allowDestructive?: boolean;
  } = {}
): Promise<ExecutionResult> {
  const startTime = Date.now();
  const toolConfig = commandMap[toolName];

  if (!toolConfig) {
    return {
      success: false,
      capabilityId: toolName,
      output: '',
      error: `Unknown tool: ${toolName}`,
      exitCode: 1,
      executionTime: Date.now() - startTime
    };
  }

  // Check permissions
  if (toolConfig.requiresElevation && !options.allowElevated) {
    return {
      success: false,
      capabilityId: toolName,
      output: '',
      error: 'This operation requires elevated privileges. Enable elevated operations in server config.',
      exitCode: 1,
      executionTime: Date.now() - startTime
    };
  }

  if (toolConfig.isDestructive && !options.allowDestructive) {
    return {
      success: false,
      capabilityId: toolName,
      output: '',
      error: 'This is a destructive operation. Enable destructive operations in server config.',
      exitCode: 1,
      executionTime: Date.now() - startTime
    };
  }

  // Get the command
  const command = typeof toolConfig.command === 'function'
    ? toolConfig.command(args)
    : toolConfig.command;

  try {
    const { stdout, stderr } = await execAsync(command, {
      timeout: toolConfig.timeout || DEFAULT_TIMEOUT,
      shell: '/bin/bash'
    });

    return {
      success: true,
      capabilityId: toolName,
      output: stdout || stderr || 'Command completed successfully',
      exitCode: 0,
      executionTime: Date.now() - startTime
    };
  } catch (error: unknown) {
    const execError = error as { code?: number; stdout?: string; stderr?: string; message?: string };
    return {
      success: false,
      capabilityId: toolName,
      output: execError.stdout || '',
      error: execError.stderr || execError.message || 'Command execution failed',
      exitCode: execError.code || 1,
      executionTime: Date.now() - startTime
    };
  }
}

/**
 * Format execution result as MCP response
 */
export function formatResponse(result: ExecutionResult): ToolCallResponse {
  if (result.success) {
    return {
      content: [{
        type: 'text',
        text: result.output
      }]
    };
  }

  return {
    content: [{
      type: 'text',
      text: `Error: ${result.error}\n\nOutput: ${result.output}`
    }],
    isError: true
  };
}

/**
 * Get list of available commands (for documentation)
 */
export function getAvailableCommands(): string[] {
  return Object.keys(commandMap);
}

/**
 * Check if a command requires elevation
 */
export function requiresElevation(toolName: string): boolean {
  return commandMap[toolName]?.requiresElevation || false;
}

/**
 * Check if a command is destructive
 */
export function isDestructive(toolName: string): boolean {
  return commandMap[toolName]?.isDestructive || false;
}
