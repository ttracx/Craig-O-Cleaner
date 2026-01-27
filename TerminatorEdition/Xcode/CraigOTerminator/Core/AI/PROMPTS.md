# AI System Prompts Documentation

## Overview

This document contains all system prompts used in the Craig-O-Clean AI orchestration system. These prompts define how the AI agents behave and ensure safe, consistent operation.

## PlannerAgent System Prompt

### Purpose
Converts natural language queries into structured workflows using the capability catalog.

### Full Prompt

```
You are a system maintenance planner for macOS. Given a user request and a catalog of available capabilities, create a workflow plan in JSON format.

RULES:
1. Only use capability IDs from the provided catalog
2. Order operations logically (e.g., analysis before cleanup)
3. Avoid destructive operations unless explicitly requested
4. Return JSON only, no explanation or markdown formatting
5. Use the exact capability IDs from the catalog
6. Provide a reason for each step
7. Limit workflows to 10 steps maximum

Output format:
{
  "workflow": [
    {
      "capabilityId": "exact.capability.id",
      "arguments": {},
      "reason": "Brief explanation"
    }
  ],
  "summary": "Brief description of what this workflow does"
}

Available capability categories:
- diagnostics: System information and analysis
- quickClean: Safe, non-destructive cleanup
- deepClean: More aggressive cleanup (requires confirmation)
- browsers: Browser tab management and cleanup
- disk: Disk space analysis and management
- memory: Memory management
- devTools: Developer tool cleanup (Xcode, npm, etc.)
- system: System maintenance and repairs
```

### Example Interactions

#### Example 1: System Status

**User Input:**
```
Check my system status
```

**Expected Output:**
```json
{
  "workflow": [
    {"capabilityId": "diag.mem.pressure", "arguments": {}, "reason": "Check memory pressure"},
    {"capabilityId": "diag.disk.free", "arguments": {}, "reason": "Check available disk space"},
    {"capabilityId": "diag.cpu.top", "arguments": {}, "reason": "Identify CPU-intensive processes"}
  ],
  "summary": "Analyzes system memory, disk, and CPU usage"
}
```

#### Example 2: System Cleanup

**User Input:**
```
Clean up my Mac
```

**Expected Output:**
```json
{
  "workflow": [
    {"capabilityId": "diag.disk.free", "arguments": {}, "reason": "Check available space"},
    {"capabilityId": "quick.temp.user", "arguments": {}, "reason": "Clear temporary files"},
    {"capabilityId": "quick.ql.reset", "arguments": {}, "reason": "Reset Quick Look cache"},
    {"capabilityId": "disk.trash.size", "arguments": {}, "reason": "Check trash size"}
  ],
  "summary": "Performs safe cleanup of temporary files and caches"
}
```

#### Example 3: Presentation Preparation

**User Input:**
```
Prepare for presentation
```

**Expected Output:**
```json
{
  "workflow": [
    {"capabilityId": "quick.mem.purge", "arguments": {}, "reason": "Free up RAM"},
    {"capabilityId": "browser.heavy.list", "arguments": {}, "reason": "Identify memory-heavy browser tabs"},
    {"capabilityId": "quick.restart.notifications", "arguments": {}, "reason": "Restart notifications to prevent interruptions"}
  ],
  "summary": "Optimizes performance and reduces distractions for presentations"
}
```

### Design Rationale

**Why these rules?**

1. **Capability-only constraint**: Prevents arbitrary command execution
2. **Logical ordering**: Ensures workflows make sense (analyze before cleanup)
3. **Avoid destructive ops**: Requires explicit user intent for safety
4. **JSON-only output**: Enables reliable parsing
5. **Exact IDs**: Prevents typos and invalid capabilities
6. **Reasons**: Provides transparency for user review
7. **10 step limit**: Keeps workflows focused and manageable

**Temperature Setting:** 0.3
- Low enough for consistent JSON output
- High enough for creative workflow composition

## SafetyAgent System Prompt

### Purpose
Validates workflows for safety and identifies potential risks.

### Full Prompt

```
You are a safety validator for system maintenance workflows on macOS. Review proposed workflows and identify risks.

RISK CATEGORIES:
- SAFE: Read-only operations, no data modification, no system changes
- MODERATE: Writes temporary data, restarts services, closes applications (recoverable)
- DESTRUCTIVE: Permanent data loss, file deletion, cannot be undone

EVALUATION CRITERIA:
1. Check if operations are reversible
2. Identify potential data loss
3. Evaluate privilege level requirements
4. Consider impact on running applications
5. Assess system stability risks

Output format (JSON only):
{
  "approved": true/false,
  "riskLevel": "safe|moderate|destructive",
  "warnings": ["...", ...],
  "suggestions": ["...", ...],
  "requiresConfirmation": true/false
}
```

### Example Assessments

#### Example 1: Safe Diagnostics

**Workflow:**
```json
[
  {"capabilityId": "diag.mem.pressure"},
  {"capabilityId": "diag.disk.free"}
]
```

**Expected Assessment:**
```json
{
  "approved": true,
  "riskLevel": "safe",
  "warnings": [],
  "suggestions": ["These operations only read system information"],
  "requiresConfirmation": false
}
```

#### Example 2: Moderate Risk (Service Restarts)

**Workflow:**
```json
[
  {"capabilityId": "quick.restart.dock"},
  {"capabilityId": "quick.restart.finder"}
]
```

**Expected Assessment:**
```json
{
  "approved": true,
  "riskLevel": "moderate",
  "warnings": ["Restarting Dock and Finder will briefly interrupt your desktop"],
  "suggestions": [
    "Save any work before proceeding",
    "Both services will restart automatically"
  ],
  "requiresConfirmation": true
}
```

#### Example 3: Destructive Operations

**Workflow:**
```json
[
  {"capabilityId": "disk.trash.empty"},
  {"capabilityId": "deep.cache.user"}
]
```

**Expected Assessment:**
```json
{
  "approved": false,
  "riskLevel": "destructive",
  "warnings": [
    "Empty Trash will permanently delete all files in trash",
    "Clearing user caches may affect application performance temporarily"
  ],
  "suggestions": [
    "Review trash contents before emptying using Finder",
    "Consider running 'disk.trash.size' first to see what will be deleted",
    "Create a backup before proceeding"
  ],
  "requiresConfirmation": true
}
```

### Design Rationale

**Risk Classification:**
- **Safe**: Can execute without confirmation
- **Moderate**: Requires user confirmation but recoverable
- **Destructive**: Strong warnings + confirmation + analysis recommended

**Approval Logic:**
- `approved=false` only for destructive ops without analysis
- Suggests adding diagnostic steps before destruction
- Always requires confirmation for moderate/destructive

**Temperature Setting:** 0.2
- Very low for consistent safety assessment
- Reduces risk of false negatives

## Prompt Engineering Best Practices

### 1. Capability Catalog Context

**Strategy:**
- Limit to ~20 capabilities per category (token efficiency)
- Include capability ID, description, risk level
- Group by category for clarity

**Example Context:**
```
[diagnostics]
- diag.mem.pressure: Shows current memory pressure level ⚠️ safe
- diag.disk.free: Shows available disk space ⚠️ safe

[quickClean]
- quick.temp.user: Removes temporary files ⚠️ safe
- quick.restart.dock: Restarts the Dock ⚠️ moderate
```

### 2. JSON Output Enforcement

**Techniques:**
1. Explicit "JSON only, no markdown" instruction
2. Show exact output format
3. Provide multiple examples
4. Clean response (strip markdown code blocks)

**Parsing Strategy:**
```swift
// Remove markdown formatting
if response.hasPrefix("```json") {
    response = response
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
}

// Find JSON bounds
guard let start = response.firstIndex(of: "{"),
      let end = response.lastIndex(of: "}") else {
    throw ParsingError.invalidJSON
}
```

### 3. Error Recovery

**Strategy:**
- Graceful fallback to rule-based assessment
- Clear error messages for users
- Suggest simpler rephrasing

**Example:**
```
"I couldn't parse that workflow plan. Try asking in simpler terms, like:
- 'Clean up my system'
- 'Check memory usage'
- 'Close heavy tabs'"
```

### 4. Example-Driven Learning

**Why it works:**
- Models learn from examples (few-shot learning)
- Shows exact format expected
- Demonstrates edge cases

**Coverage:**
- Safe workflows (auto-approved)
- Moderate workflows (confirmation)
- Destructive workflows (rejected without analysis)

## Prompt Versioning

### V1.0 (Current)

**PlannerAgent:**
- Basic workflow generation
- Capability-only constraint
- 10 step limit

**SafetyAgent:**
- Three-tier risk model
- Rule-based + AI hybrid
- Approval/rejection logic

### Future Versions

**V1.1 (Planned):**
- Multi-turn conversation support
- Context retention across queries
- Follow-up question handling

**V2.0 (Future):**
- User preference learning
- Workflow optimization suggestions
- Predictive maintenance

## Testing Prompts

### Test Cases

#### Test 1: Capability Constraint Enforcement

**Input:** "Delete all my files"

**Expected Behavior:**
- Should NOT suggest arbitrary `rm -rf` commands
- Should ONLY use catalog capabilities
- May suggest `disk.trash.empty` with warnings

#### Test 2: Ordering Logic

**Input:** "Clean caches and check disk"

**Expected Order:**
1. `diag.disk.free` (check first)
2. `deep.cache.user` (then clean)

**Not:**
1. Clean first
2. Check after

#### Test 3: Risk Assessment

**Input Workflow:** [disk.trash.empty]

**Expected:**
- Risk: Destructive
- Approved: false (no analysis step)
- Suggests: Add `disk.trash.size` first

### Validation Criteria

✅ **Pass:**
- Only uses catalog capability IDs
- Logical step ordering
- Correct risk classification
- Valid JSON output

❌ **Fail:**
- Uses arbitrary commands
- Illogical ordering
- Incorrect risk level
- Malformed JSON

## Debugging Prompts

### Enable Debug Mode

**For PlannerAgent:**
```swift
// Add verbose logging
let response = try await ollamaClient.generate(
    model: model,
    prompt: fullPrompt,
    system: systemPrompt + "\n\nDEBUG: Explain your reasoning",
    temperature: 0.3
)
```

**For SafetyAgent:**
```swift
// Request detailed analysis
system: systemPrompt + "\n\nDEBUG: List all risks considered"
```

### Common Issues

**Issue 1: Markdown in JSON**

**Symptom:** Output starts with "```json"

**Fix:** Update cleaning logic in parseWorkflowPlan()

**Issue 2: Invalid Capability IDs**

**Symptom:** IDs don't match catalog

**Fix:** Improve catalog context formatting

**Issue 3: Inconsistent Risk Levels**

**Symptom:** Same workflow gets different risks

**Fix:** Lower temperature (0.1-0.2)

## Prompt Maintenance

### When to Update Prompts

1. **New capabilities added** → Update category descriptions
2. **Risk model changes** → Revise SafetyAgent criteria
3. **User feedback** → Refine example workflows
4. **Model upgrades** → Re-test all prompts

### Testing After Changes

```bash
# Run test suite
swift test --filter AIWorkflowTests

# Manual validation
1. Try 10 diverse queries
2. Verify JSON parsing
3. Check risk assessments
4. Validate capability IDs
```

### Version Control

- Prompts stored in code (this file serves as backup)
- Changes require code review
- Test coverage required for updates

## References

- [Ollama Prompting Guide](https://github.com/ollama/ollama/blob/main/docs/prompts.md)
- [Few-Shot Learning](https://arxiv.org/abs/2005.14165)
- [JSON Mode Best Practices](https://cookbook.openai.com/examples/how_to_format_inputs_to_chatgpt_models)

---

**Version:** 1.0
**Last Updated:** January 27, 2026
**Maintained By:** NeuralQuantum.ai / VibeCaaS Team
