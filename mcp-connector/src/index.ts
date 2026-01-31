/**
 * Craig-O-Clean MCP Connector Server
 *
 * A Model Context Protocol (MCP) server that exposes Craig-O-Clean's
 * macOS system maintenance capabilities to Claude and other MCP clients.
 *
 * Supports:
 * - System diagnostics and monitoring
 * - Memory optimization
 * - Browser tab management
 * - Cache and log cleanup
 * - Developer tools cleanup
 * - Process management
 */

import express, { Request, Response, NextFunction, RequestHandler } from 'express';
import cors from 'cors';
import { allTools, toolCategories } from './tools.js';
import { executeCommand, formatResponse, requiresElevation, isDestructive } from './executor.js';
import type { ServerConfig, MCPTool, MCPResource, ToolCallRequest } from './types.js';

// Server configuration
const config: ServerConfig = {
  port: parseInt(process.env.PORT || '3847', 10),
  host: process.env.HOST || '0.0.0.0',
  enableElevatedOperations: process.env.ENABLE_ELEVATED === 'true',
  enableDestructiveOperations: process.env.ENABLE_DESTRUCTIVE === 'true',
  authToken: process.env.AUTH_TOKEN
};

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Authentication middleware (optional)
const authMiddleware: RequestHandler = (req, res, next) => {
  if (config.authToken) {
    const authHeader = req.headers.authorization;
    if (!authHeader || authHeader !== `Bearer ${config.authToken}`) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
  }
  next();
};

// Apply auth to all routes
app.use(authMiddleware);

// MCP Server Info endpoint
app.get('/', (_req: Request, res: Response) => {
  res.json({
    name: 'craig-o-clean-mcp',
    version: '1.0.0',
    description: 'MCP connector for Craig-O-Clean macOS system maintenance app',
    protocol_version: '2024-11-05',
    capabilities: {
      tools: {
        listChanged: false
      },
      resources: {
        subscribe: false,
        listChanged: false
      },
      prompts: {
        listChanged: false
      }
    }
  });
});

// List available tools
app.get('/tools', (_req: Request, res: Response) => {
  // Filter tools based on config
  const availableTools = allTools.filter(tool => {
    if (requiresElevation(tool.name) && !config.enableElevatedOperations) {
      return false;
    }
    if (isDestructive(tool.name) && !config.enableDestructiveOperations) {
      return false;
    }
    return true;
  });

  res.json({
    tools: availableTools
  });
});

// List tools (MCP protocol format)
app.post('/tools/list', (_req: Request, res: Response) => {
  const availableTools = allTools.filter(tool => {
    if (requiresElevation(tool.name) && !config.enableElevatedOperations) {
      return false;
    }
    if (isDestructive(tool.name) && !config.enableDestructiveOperations) {
      return false;
    }
    return true;
  });

  res.json({
    tools: availableTools
  });
});

// Execute a tool (MCP protocol format)
app.post('/tools/call', async (req: Request, res: Response) => {
  const { name, arguments: args } = req.body as ToolCallRequest;

  if (!name) {
    res.status(400).json({
      content: [{ type: 'text', text: 'Tool name is required' }],
      isError: true
    });
    return;
  }

  // Check if tool exists
  const tool = allTools.find(t => t.name === name);
  if (!tool) {
    res.status(404).json({
      content: [{ type: 'text', text: `Unknown tool: ${name}` }],
      isError: true
    });
    return;
  }

  // Check permissions
  if (requiresElevation(name) && !config.enableElevatedOperations) {
    res.status(403).json({
      content: [{ type: 'text', text: 'This tool requires elevated privileges which are not enabled on this server.' }],
      isError: true
    });
    return;
  }

  if (isDestructive(name) && !config.enableDestructiveOperations) {
    res.status(403).json({
      content: [{ type: 'text', text: 'This is a destructive operation which is not enabled on this server.' }],
      isError: true
    });
    return;
  }

  try {
    const result = await executeCommand(name, args || {}, {
      allowElevated: config.enableElevatedOperations,
      allowDestructive: config.enableDestructiveOperations
    });

    res.json(formatResponse(result));
  } catch (error) {
    console.error(`Error executing tool ${name}:`, error);
    res.status(500).json({
      content: [{ type: 'text', text: `Internal error executing tool: ${error}` }],
      isError: true
    });
  }
});

// List resources
app.get('/resources', (_req: Request, res: Response) => {
  const resources: MCPResource[] = [
    {
      uri: 'craig-o-clean://system/metrics',
      name: 'System Metrics',
      description: 'Real-time system metrics including CPU, memory, disk, and network',
      mimeType: 'application/json'
    },
    {
      uri: 'craig-o-clean://system/processes',
      name: 'Process List',
      description: 'List of running processes with resource usage',
      mimeType: 'application/json'
    },
    {
      uri: 'craig-o-clean://browser/tabs',
      name: 'Browser Tabs',
      description: 'Open browser tabs across all supported browsers',
      mimeType: 'application/json'
    },
    {
      uri: 'craig-o-clean://tools/catalog',
      name: 'Tool Catalog',
      description: 'Complete catalog of available cleanup and maintenance operations',
      mimeType: 'application/json'
    }
  ];

  res.json({ resources });
});

// List resources (MCP protocol format)
app.post('/resources/list', (_req: Request, res: Response) => {
  const resources: MCPResource[] = [
    {
      uri: 'craig-o-clean://system/metrics',
      name: 'System Metrics',
      description: 'Real-time system metrics including CPU, memory, disk, and network',
      mimeType: 'application/json'
    },
    {
      uri: 'craig-o-clean://system/processes',
      name: 'Process List',
      description: 'List of running processes with resource usage',
      mimeType: 'application/json'
    },
    {
      uri: 'craig-o-clean://browser/tabs',
      name: 'Browser Tabs',
      description: 'Open browser tabs across all supported browsers',
      mimeType: 'application/json'
    },
    {
      uri: 'craig-o-clean://tools/catalog',
      name: 'Tool Catalog',
      description: 'Complete catalog of available cleanup and maintenance operations',
      mimeType: 'application/json'
    }
  ];

  res.json({ resources });
});

// Read resource
app.post('/resources/read', async (req: Request, res: Response) => {
  const { uri } = req.body;

  if (!uri) {
    res.status(400).json({ error: 'Resource URI is required' });
    return;
  }

  try {
    let content: object;

    switch (uri) {
      case 'craig-o-clean://system/metrics':
        const metricsResult = await executeCommand('get_system_metrics', { include: 'all' }, {
          allowElevated: config.enableElevatedOperations,
          allowDestructive: config.enableDestructiveOperations
        });
        content = { raw: metricsResult.output };
        break;

      case 'craig-o-clean://system/processes':
        const processResult = await executeCommand('list_processes', { filter: 'user_only' }, {
          allowElevated: config.enableElevatedOperations,
          allowDestructive: config.enableDestructiveOperations
        });
        content = { raw: processResult.output };
        break;

      case 'craig-o-clean://browser/tabs':
        const tabsResult = await executeCommand('get_browser_tabs', { browser: 'all', info: 'count' }, {
          allowElevated: config.enableElevatedOperations,
          allowDestructive: config.enableDestructiveOperations
        });
        content = { raw: tabsResult.output };
        break;

      case 'craig-o-clean://tools/catalog':
        content = {
          categories: toolCategories,
          tools: allTools.map(t => ({
            name: t.name,
            description: t.description,
            requiresElevation: requiresElevation(t.name),
            isDestructive: isDestructive(t.name)
          }))
        };
        break;

      default:
        res.status(404).json({ error: `Unknown resource: ${uri}` });
        return;
    }

    res.json({
      contents: [{
        uri,
        mimeType: 'application/json',
        text: JSON.stringify(content, null, 2)
      }]
    });
  } catch (error) {
    console.error(`Error reading resource ${uri}:`, error);
    res.status(500).json({ error: `Failed to read resource: ${error}` });
  }
});

// Health check
app.get('/health', (_req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    uptime: process.uptime(),
    config: {
      elevatedOperationsEnabled: config.enableElevatedOperations,
      destructiveOperationsEnabled: config.enableDestructiveOperations,
      authRequired: !!config.authToken
    }
  });
});

// Tool categories endpoint (for documentation)
app.get('/categories', (_req: Request, res: Response) => {
  res.json({ categories: toolCategories });
});

// MCP message handler (for SSE transport)
app.post('/mcp', async (req: Request, res: Response) => {
  const { jsonrpc, method, params, id } = req.body;

  if (jsonrpc !== '2.0') {
    res.status(400).json({
      jsonrpc: '2.0',
      error: { code: -32600, message: 'Invalid JSON-RPC version' },
      id
    });
    return;
  }

  try {
    let result: unknown;

    switch (method) {
      case 'initialize':
        result = {
          protocolVersion: '2024-11-05',
          capabilities: {
            tools: { listChanged: false },
            resources: { subscribe: false, listChanged: false }
          },
          serverInfo: {
            name: 'craig-o-clean-mcp',
            version: '1.0.0'
          }
        };
        break;

      case 'tools/list':
        const availableTools = allTools.filter(tool => {
          if (requiresElevation(tool.name) && !config.enableElevatedOperations) {
            return false;
          }
          if (isDestructive(tool.name) && !config.enableDestructiveOperations) {
            return false;
          }
          return true;
        });
        result = { tools: availableTools };
        break;

      case 'tools/call':
        const { name, arguments: args } = params;
        const execResult = await executeCommand(name, args || {}, {
          allowElevated: config.enableElevatedOperations,
          allowDestructive: config.enableDestructiveOperations
        });
        result = formatResponse(execResult);
        break;

      case 'resources/list':
        result = {
          resources: [
            {
              uri: 'craig-o-clean://system/metrics',
              name: 'System Metrics',
              description: 'Real-time system metrics',
              mimeType: 'application/json'
            },
            {
              uri: 'craig-o-clean://tools/catalog',
              name: 'Tool Catalog',
              description: 'Available operations',
              mimeType: 'application/json'
            }
          ]
        };
        break;

      case 'resources/read':
        // Handle resource read
        result = { contents: [] };
        break;

      default:
        res.status(400).json({
          jsonrpc: '2.0',
          error: { code: -32601, message: `Method not found: ${method}` },
          id
        });
        return;
    }

    res.json({
      jsonrpc: '2.0',
      result,
      id
    });
  } catch (error) {
    console.error(`Error handling MCP request:`, error);
    res.status(500).json({
      jsonrpc: '2.0',
      error: { code: -32603, message: `Internal error: ${error}` },
      id
    });
  }
});

// Start server
app.listen(config.port, config.host, () => {
  console.log(`
╔═══════════════════════════════════════════════════════════════╗
║          Craig-O-Clean MCP Connector Server                   ║
╠═══════════════════════════════════════════════════════════════╣
║  Server running at: http://${config.host}:${config.port}                     ║
║                                                               ║
║  Configuration:                                               ║
║  - Elevated operations: ${config.enableElevatedOperations ? 'ENABLED ' : 'DISABLED'}                         ║
║  - Destructive operations: ${config.enableDestructiveOperations ? 'ENABLED ' : 'DISABLED'}                      ║
║  - Authentication: ${config.authToken ? 'ENABLED ' : 'DISABLED'}                              ║
║                                                               ║
║  Endpoints:                                                   ║
║  - GET  /           Server info                               ║
║  - GET  /health     Health check                              ║
║  - GET  /tools      List available tools                      ║
║  - POST /tools/call Execute a tool                            ║
║  - GET  /resources  List available resources                  ║
║  - POST /mcp        JSON-RPC MCP endpoint                     ║
║                                                               ║
║  Total tools available: ${allTools.length.toString().padEnd(36)}║
╚═══════════════════════════════════════════════════════════════╝
`);
});

export default app;
