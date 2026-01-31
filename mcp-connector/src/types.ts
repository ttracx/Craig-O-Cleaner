/**
 * Craig-O-Clean MCP Connector Type Definitions
 */

// Capability privilege levels
export type PrivilegeLevel = 'user' | 'elevated' | 'automation' | 'fullDiskAccess';

// Risk classification for operations
export type RiskClass = 'safe' | 'moderate' | 'destructive';

// Capability groups
export type CapabilityGroup =
  | 'diagnostics'
  | 'quickClean'
  | 'deepClean'
  | 'memory'
  | 'browsers'
  | 'devTools'
  | 'disk'
  | 'system';

// Preflight check types
export interface PreflightCheck {
  type: 'appRunning' | 'appNotRunning' | 'pathExists' | 'automationPermission';
  target: string;
  failureMessage: string;
}

// Capability definition from catalog
export interface Capability {
  id: string;
  title: string;
  description: string;
  group: CapabilityGroup;
  commandTemplate: string;
  arguments: string[];
  workingDirectory: string | null;
  timeout: number;
  privilegeLevel: PrivilegeLevel;
  riskClass: RiskClass;
  outputParser: string;
  parserPattern: string | null;
  preflightChecks: PreflightCheck[];
  requiredPaths: string[];
  requiredApps: string[];
  icon: string;
  rollbackNotes: string | null;
  estimatedDuration: number;
}

// Catalog structure
export interface CapabilityCatalog {
  version: string;
  lastUpdated: string;
  capabilities: Capability[];
}

// Execution result
export interface ExecutionResult {
  success: boolean;
  capabilityId: string;
  output: string;
  error?: string;
  exitCode: number;
  executionTime: number;
}

// System metrics types
export interface CPUMetrics {
  userUsage: number;
  systemUsage: number;
  idleUsage: number;
  totalUsage: number;
  loadAverage: {
    one: number;
    five: number;
    fifteen: number;
  };
}

export interface MemoryMetrics {
  totalRAM: number;
  usedRAM: number;
  freeRAM: number;
  pressureLevel: 'normal' | 'warning' | 'critical';
  pressurePercentage: number;
}

export interface DiskMetrics {
  totalSpace: number;
  usedSpace: number;
  freeSpace: number;
  usagePercentage: number;
}

export interface SystemMetrics {
  cpu: CPUMetrics;
  memory: MemoryMetrics;
  disk: DiskMetrics;
  uptime: string;
  macOSVersion: string;
}

// Process information
export interface ProcessInfo {
  pid: number;
  name: string;
  cpuUsage: number;
  memoryUsage: number;
  isUserProcess: boolean;
}

// Browser tab information
export interface BrowserTab {
  browser: string;
  windowIndex: number;
  tabIndex: number;
  title: string;
  url: string;
}

// MCP Tool definition
export interface MCPTool {
  name: string;
  description: string;
  inputSchema: {
    type: 'object';
    properties: Record<string, {
      type: string;
      description: string;
      enum?: string[];
      default?: unknown;
    }>;
    required?: string[];
  };
}

// MCP Resource definition
export interface MCPResource {
  uri: string;
  name: string;
  description: string;
  mimeType: string;
}

// MCP Tool call request
export interface ToolCallRequest {
  name: string;
  arguments: Record<string, unknown>;
}

// MCP Tool call response
export interface ToolCallResponse {
  content: Array<{
    type: 'text' | 'image' | 'resource';
    text?: string;
    data?: string;
    mimeType?: string;
  }>;
  isError?: boolean;
}

// Server configuration
export interface ServerConfig {
  port: number;
  host: string;
  enableElevatedOperations: boolean;
  enableDestructiveOperations: boolean;
  authToken?: string;
}
