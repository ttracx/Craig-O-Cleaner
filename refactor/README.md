# Craig-O-Clean Development Prompt Package

## Overview

This package contains the improved instructional development prompt for Craig-O-Clean, a macOS menu bar application for system cleanup, diagnostics, and browser management.

## Files Included

| File | Purpose |
|------|---------|
| `CRAIG_O_CLEAN_DEVELOPMENT_PROMPT.md` | Main instructional prompt for AI coding agents |
| `COMMANDS_REFERENCE.md` | Complete command reference with capability catalog |
| `catalog.json` | JSON capability catalog for bundling with the app |

## Key Improvements Over Original

### 1. **Structured Architecture**
- Clear component diagram with data flow
- Defined protocols and interfaces
- Explicit separation of concerns

### 2. **Security Model Hardened**
- Explicit non-negotiable constraints at the top
- Privilege levels clearly defined (user/elevated/automation)
- Risk classification for UI flow decisions
- No "admin by default" patterns

### 3. **Capability Catalog System**
- Commands converted to structured metadata
- Allowlist-only execution model
- Preflight checks for each capability
- Output parser specifications

### 4. **Commands Separated**
- Complete command reference in separate document
- JSON catalog ready for bundling
- Commands organized by group with metadata

### 5. **Vertical Build Slices**
- Clear implementation order (Slices A-F)
- Each slice has defined deliverables and acceptance criteria
- Progressive capability building

### 6. **VibeCaaS Branding**
- Brand colors included
- Consistent theming specifications

## How to Use

### For AI Coding Agent

1. Provide the main prompt (`CRAIG_O_CLEAN_DEVELOPMENT_PROMPT.md`)
2. When implementing specific commands, reference `COMMANDS_REFERENCE.md`
3. Use `catalog.json` as the capability catalog to bundle

### Prompt Structure

```
[MAIN PROMPT]
CRAIG_O_CLEAN_DEVELOPMENT_PROMPT.md

[COMMAND REFERENCE - Provide when needed]
COMMANDS_REFERENCE.md

[CATALOG FILE - For implementation]
catalog.json
```

### Example Agent Instruction

```
Using the instructional prompt below and the commands reference, 
implement Slice B (Non-Privileged Executor):

[Contents of CRAIG_O_CLEAN_DEVELOPMENT_PROMPT.md]

Command Reference:
[Contents of COMMANDS_REFERENCE.md - Relevant sections only]
```

## Acceptance Criteria Summary

| Scenario | Expected |
|----------|----------|
| Quick Clean | No password prompts, completes successfully |
| Elevated command | Shows macOS auth dialog, executes after approval |
| Browser operation (granted) | Lists/closes tabs correctly |
| Browser operation (denied) | Shows remediation UI |
| First launch | Permission prompts in correct order |
| Command fails | Error with cause and remediation |
| Activity log | All runs with status, duration, details |
| Export logs | Creates readable file |

## Implementation Priority

1. **Slice A** - App Shell + Catalog (Days 1-2)
2. **Slice B** - Non-Privileged Executor (Days 3-4)
3. **Slice C** - Permission Center (Days 5-6)
4. **Slice D** - Browser Operations (Days 7-9)
5. **Slice E** - Privileged Helper (Days 10-12)
6. **Slice F** - AI Orchestration (Days 13-15, Optional)

## Notes

- Commands are Apple Silicon optimized but maintain Intel compatibility
- All destructive operations require confirmation + dry-run preview
- Browser automation uses AppleScript with proper error handling
- Privileged operations use SMJobBless + Authorization Services

---

**Author:** NeuralQuantum.ai / VibeCaaS Team  
**Version:** 2.0  
**Date:** January 2026
