# AI Orchestration System

## Overview

The AI Orchestration system enables natural language system maintenance for Craig-O-Clean. Users can describe what they want in plain English, and the AI plans and executes workflows using the capability catalog.

**Key Principle:** Privacy-first, local-only AI using Ollama (no cloud, no API keys).

## Architecture

```
User Natural Language Query
         ↓
    PlannerAgent (Ollama)
         ↓
Workflow Proposal (JSON)
         ↓
    SafetyAgent (Ollama)
         ↓
Risk Assessment + Modifications
         ↓
User Approval (UI)
         ↓
WorkflowExecutor
         ↓
Sequential Execution (UserExecutor/ElevatedExecutor)
         ↓
Results Aggregation
         ↓
Natural Language Summary
```

## Components

### OllamaClient (`OllamaClient.swift`)

Local LLM client for communication with Ollama server.

**Features:**
- Connection management (localhost:11434)
- Streaming and non-streaming completion
- Model management (list, pull, check availability)
- Error handling for server not running
- Automatic connection monitoring

**Usage:**
```swift
let client = OllamaClient()

// Check server status
let isRunning = await client.checkServerStatus()

// List available models
let models = try await client.listModels()

// Generate completion
let response = try await client.generate(
    model: "llama3.2",
    prompt: "User query",
    system: "System prompt",
    temperature: 0.3
)
```

### PlannerAgent (`Agents/PlannerAgent.swift`)

Plans workflows from natural language queries using capability catalog.

**Responsibilities:**
- Parse user intent
- Map to capability IDs
- Generate logical workflow order
- Enforce capability-only constraint

**System Prompt Strategy:**
- Provides catalog context
- Shows example workflows
- Enforces JSON output format
- Limits workflow to 10 steps max

**Usage:**
```swift
let planner = PlannerAgent(
    ollamaClient: client,
    capabilityCatalog: catalog
)

let plan = try await planner.planWorkflow(from: "Clean up my system")
```

**Output Format:**
```json
{
  "workflow": [
    {
      "capabilityId": "diag.disk.free",
      "arguments": {},
      "reason": "Check available space"
    }
  ],
  "summary": "Performs safe cleanup of temporary files"
}
```

### SafetyAgent (`Agents/SafetyAgent.swift`)

Validates workflow safety and identifies risks.

**Responsibilities:**
- Assess risk level (safe/moderate/destructive)
- Identify warnings
- Suggest modifications
- Require confirmation when needed

**Assessment Strategy:**
1. Quick rule-based assessment using capability metadata
2. AI-enhanced assessment for nuanced cases
3. Combination of both for comprehensive evaluation

**Usage:**
```swift
let safety = SafetyAgent(
    ollamaClient: client,
    capabilityCatalog: catalog
)

let assessment = try await safety.assessSafety(of: plan)
```

**Output Format:**
```json
{
  "approved": true,
  "riskLevel": "safe",
  "warnings": [],
  "suggestions": ["These operations only read system information"],
  "requiresConfirmation": false
}
```

### WorkflowExecutor (`WorkflowExecutor.swift`)

Executes workflows step by step.

**Features:**
- Sequential execution
- Progress tracking (@Observable)
- Error handling with graceful degradation
- Route to appropriate executor (UserExecutor/ElevatedExecutor)
- Result aggregation

**Usage:**
```swift
let executor = WorkflowExecutor(
    capabilityCatalog: catalog,
    userExecutor: userExec,
    elevatedExecutor: elevatedExec,
    logStore: logStore
)

let result = try await executor.execute(plan: plan) { stepResult in
    // Progress callback
}
```

## UI Components

### AIChatView (`Features/AI/AIChatView.swift`)

Main chat interface with conversational AI interaction.

**Features:**
- Message history with user/assistant bubbles
- Typing indicators
- Example queries
- Workflow preview in chat
- Ollama status indicator
- Model selection
- Installation help

### WorkflowApprovalSheet (`Features/AI/WorkflowApprovalSheet.swift`)

Approval UI for reviewing workflows before execution.

**Shows:**
- Workflow summary
- Risk assessment with color coding
- Step-by-step breakdown
- Warnings and suggestions
- Approve/Cancel actions

**Risk Indicators:**
- 🟢 Safe: Green badge, read-only operations
- 🟠 Moderate: Orange badge, recoverable changes
- 🔴 Destructive: Red badge, permanent data loss

### AISettingsView (`Features/AI/AISettingsView.swift`)

Settings for AI configuration.

**Options:**
- Connection status
- Model selection
- Model pulling interface
- Privacy notice
- Installation guide

## Security & Privacy

### Privacy-First Design

**All processing is local:**
- No cloud API calls
- No data sent to external servers
- No API keys or credentials required
- Works completely offline

**Data Flow:**
```
User Query → Local Ollama → PlannerAgent → WorkflowExecutor → Results
(all on Mac)                    ↓
                         SafetyAgent
                       (validation layer)
```

### Safety Constraints

**Capability-Only Execution:**
- AI can ONLY suggest capabilities from catalog
- No arbitrary shell commands
- No hardcoded command templates
- All operations go through UserExecutor/ElevatedExecutor

**Safety Layers:**
1. **Planning**: Only valid capability IDs accepted
2. **Safety Assessment**: Risk evaluation required
3. **User Approval**: Confirmation for moderate/destructive ops
4. **Execution**: Standard security checks apply

## Ollama Configuration

### Recommended Models

**llama3.2** (3B parameters)
- Fast inference on Apple Silicon
- Good for planning and safety assessment
- Low memory usage (~2GB)
- Install: `ollama pull llama3.2`

**mistral** (7B parameters)
- Balanced performance
- Better reasoning
- Moderate memory usage (~4GB)
- Install: `ollama pull mistral`

**qwen2.5** (7B parameters)
- Good for technical tasks
- Strong JSON output
- Install: `ollama pull qwen2.5`

### Installation

1. **Download Ollama**: https://ollama.com/download
2. **Install**: Run the installer
3. **Start Server**: `ollama serve` or use menu bar app
4. **Pull Model**: `ollama pull llama3.2`

### Configuration

Default settings work for most cases:
- Server URL: http://localhost:11434
- Temperature: 0.3 (planning), 0.2 (safety)
- Max tokens: default (no limit)
- Timeout: 120 seconds

## Example Workflows

### Example 1: System Diagnostics

**User:** "Check my system status"

**Generated Workflow:**
```json
{
  "workflow": [
    {"capabilityId": "diag.mem.pressure", "reason": "Check memory pressure"},
    {"capabilityId": "diag.disk.free", "reason": "Check available disk space"},
    {"capabilityId": "diag.cpu.top", "reason": "Identify CPU-intensive processes"}
  ],
  "summary": "Analyzes system memory, disk, and CPU usage"
}
```

**Safety Assessment:**
- Risk: Safe
- Approval: Auto-approved (no confirmation needed)

### Example 2: System Cleanup

**User:** "Clean up my Mac"

**Generated Workflow:**
```json
{
  "workflow": [
    {"capabilityId": "diag.disk.free", "reason": "Check available space"},
    {"capabilityId": "quick.temp.user", "reason": "Clear temporary files"},
    {"capabilityId": "quick.ql.reset", "reason": "Reset Quick Look cache"},
    {"capabilityId": "disk.trash.size", "reason": "Check trash size"}
  ],
  "summary": "Performs safe cleanup of temporary files and caches"
}
```

**Safety Assessment:**
- Risk: Safe
- Approval: Auto-approved

### Example 3: Presentation Prep

**User:** "Prepare for presentation"

**Generated Workflow:**
```json
{
  "workflow": [
    {"capabilityId": "quick.mem.purge", "reason": "Free up RAM"},
    {"capabilityId": "browser.heavy.list", "reason": "Identify memory-heavy tabs"},
    {"capabilityId": "quick.restart.notifications", "reason": "Restart notifications"}
  ],
  "summary": "Optimizes performance and prevents interruptions"
}
```

**Safety Assessment:**
- Risk: Moderate (restarts services)
- Approval: Requires confirmation

## Error Handling

### Ollama Not Running

**Detection:**
- Connection monitoring every 30 seconds
- Status indicator in UI
- Alert on first interaction

**Recovery:**
1. Show installation instructions
2. Provide "Open Website" button
3. Fallback to manual capability selection

### Model Not Found

**Detection:**
- 404 error from Ollama API
- Model list check on startup

**Recovery:**
1. Show model pull interface
2. Guide user through pulling model
3. Auto-refresh model list after pull

### Invalid Workflow JSON

**Detection:**
- JSON parsing failure
- Missing required fields
- Invalid capability IDs

**Recovery:**
1. Log error for debugging
2. Ask user to rephrase request
3. Show more specific examples

### Execution Failures

**Handling:**
- Continue workflow if step non-critical
- Stop workflow if step critical (destructive)
- Collect all results for summary
- Show partial success status

## Testing Strategy

### Unit Tests (`Tests/AIWorkflowTests.swift`)

**Coverage:**
- OllamaClient: Connection, model management, generation
- PlannerAgent: Query parsing, workflow generation, validation
- SafetyAgent: Risk assessment, rule-based evaluation
- WorkflowExecutor: Step execution, error handling, progress tracking

**Mocking:**
- Mock Ollama responses for deterministic tests
- Mock capability catalog for isolated testing
- Mock executors for workflow testing

### Integration Tests

**Scenarios:**
- End-to-end workflow (query → plan → assess → execute → result)
- Ollama not running (graceful degradation)
- Model not found (pull workflow)
- Permission denied (execution fallback)

### Manual Testing

**Test Cases:**
1. Install Ollama and pull model
2. Run various queries (safe, moderate, destructive)
3. Approve/cancel workflows
4. Verify execution results
5. Test error scenarios

## Performance Considerations

### Model Inference

**llama3.2 on Apple Silicon:**
- First token: ~200ms
- Subsequent tokens: ~50ms/token
- Total workflow planning: 2-5 seconds

### Caching

**What's Cached:**
- Capability catalog (in memory)
- Model list (refreshed every 30s)
- Connection status (refreshed every 30s)

**What's Not Cached:**
- Ollama responses (always fresh)
- Workflow plans (regenerated each time)
- Safety assessments (evaluated per workflow)

### Optimization Tips

1. Use smaller models (llama3.2) for faster responses
2. Lower temperature for more consistent JSON output
3. Limit capability catalog context to avoid token overflow
4. Pre-load models on app launch

## Future Enhancements

### V2 Features (Out of Scope)

- **Workflow Templates**: Save/load common workflows
- **Multi-Turn Conversations**: Follow-up questions and refinements
- **Learning**: Adapt to user preferences over time
- **Cloud Models**: Optional OpenAI/Anthropic fallback
- **Workflow History**: Browse and rerun past workflows
- **Custom Capabilities**: User-defined actions

### Technical Improvements

- **Streaming UI Updates**: Real-time workflow generation display
- **Parallel Execution**: Run independent steps concurrently
- **Rollback Support**: Undo destructive operations
- **Dry Run Mode**: Preview without executing

## Troubleshooting

### Ollama Won't Connect

**Check:**
1. Is Ollama installed? `which ollama`
2. Is server running? `ps aux | grep ollama`
3. Is port 11434 available? `lsof -i :11434`

**Fix:**
```bash
# Start Ollama server
ollama serve

# Check status
curl http://localhost:11434/api/tags
```

### Model Pulls Fail

**Common Causes:**
- No internet connection
- Disk space full
- Corrupted download

**Fix:**
```bash
# Re-pull model
ollama pull llama3.2

# Check available space
df -h

# List installed models
ollama list
```

### Invalid JSON Output

**Symptoms:**
- "Failed to parse workflow plan" error
- Workflow contains markdown formatting

**Fix:**
1. Lower temperature (0.1-0.3)
2. Use more specific prompt examples
3. Try different model (qwen2.5 for better JSON)

### Workflows Don't Execute

**Check:**
1. Are capability IDs valid? Check catalog.json
2. Do capabilities require permissions? Check PermissionCenter
3. Is helper installed? Check ElevatedExecutor status

**Fix:**
- Validate capability catalog loaded correctly
- Run permission checks manually
- Review execution logs in SQLite database

## References

- [Ollama Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [llama3.2 Model Card](https://ollama.com/library/llama3.2)
- [Capability Catalog Specification](../Capabilities/README.md)
- [Security Model](../../HelperTool/SECURITY.md)

---

**Version:** 1.0
**Last Updated:** January 27, 2026
**Author:** NeuralQuantum.ai / VibeCaaS Team
