---
name: core-skills
description: Core skills library available to all agents in the NeuralQuantum.ai ecosystem
version: 2.0.0
permissions: full
---

# Core Skills Library

This file defines the core skills available to all agents in the NeuralQuantum.ai Agent Library. All skills operate with full permissions.

## Skill Categories

### 1. File Operation Skills

#### FILE_READ
```yaml
skill_name: FILE_READ
type: tool_skill
permissions: full
description: Read any file from the filesystem
parameters:
  - file_path: string (required)
  - offset: number (optional)
  - limit: number (optional)
returns: File content with line numbers
auto_approve: true
```

#### FILE_WRITE
```yaml
skill_name: FILE_WRITE
type: tool_skill
permissions: full
description: Write content to any file
parameters:
  - file_path: string (required)
  - content: string (required)
returns: Success confirmation
auto_approve: true
```

#### FILE_EDIT
```yaml
skill_name: FILE_EDIT
type: tool_skill
permissions: full
description: Edit existing files with find/replace
parameters:
  - file_path: string (required)
  - old_string: string (required)
  - new_string: string (required)
  - replace_all: boolean (optional)
returns: Updated file content
auto_approve: true
```

#### FILE_SEARCH
```yaml
skill_name: FILE_SEARCH
type: tool_skill
permissions: full
description: Search for files by pattern
parameters:
  - pattern: string (required)
  - path: string (optional)
returns: List of matching files
auto_approve: true
```

### 2. Code Execution Skills

#### BASH_EXECUTE
```yaml
skill_name: BASH_EXECUTE
type: tool_skill
permissions: full
description: Execute any bash command
parameters:
  - command: string (required)
  - timeout: number (optional)
  - background: boolean (optional)
returns: Command output
auto_approve: true
```

#### SCRIPT_RUN
```yaml
skill_name: SCRIPT_RUN
type: workflow_skill
permissions: full
description: Execute scripts (shell, python, node)
parameters:
  - script_path: string (required)
  - args: array (optional)
returns: Script output
auto_approve: true
```

### 3. Search Skills

#### GREP_SEARCH
```yaml
skill_name: GREP_SEARCH
type: tool_skill
permissions: full
description: Search file contents with regex
parameters:
  - pattern: string (required)
  - path: string (optional)
  - type: string (optional)
  - output_mode: string (optional)
returns: Search results
auto_approve: true
```

#### CODEBASE_EXPLORE
```yaml
skill_name: CODEBASE_EXPLORE
type: workflow_skill
permissions: full
description: Thoroughly explore a codebase
parameters:
  - query: string (required)
  - thoroughness: quick|medium|very_thorough
returns: Exploration report
auto_approve: true
```

### 4. Network Skills

#### WEB_FETCH
```yaml
skill_name: WEB_FETCH
type: tool_skill
permissions: full
description: Fetch and process web content
parameters:
  - url: string (required)
  - prompt: string (required)
returns: Processed content
auto_approve: true
```

#### WEB_SEARCH
```yaml
skill_name: WEB_SEARCH
type: tool_skill
permissions: full
description: Search the web for information
parameters:
  - query: string (required)
  - allowed_domains: array (optional)
returns: Search results
auto_approve: true
```

### 5. Git Skills

#### GIT_STATUS
```yaml
skill_name: GIT_STATUS
type: tool_skill
permissions: full
description: Check git repository status
parameters: none
returns: Repository status
auto_approve: true
```

#### GIT_COMMIT
```yaml
skill_name: GIT_COMMIT
type: workflow_skill
permissions: full
description: Stage and commit changes
parameters:
  - message: string (required)
  - files: array (optional)
returns: Commit confirmation
auto_approve: true
```

#### GIT_PUSH
```yaml
skill_name: GIT_PUSH
type: tool_skill
permissions: full
description: Push commits to remote
parameters:
  - branch: string (optional)
  - force: boolean (optional)
returns: Push result
auto_approve: true
```

### 6. Agent Coordination Skills

#### SPAWN_AGENT
```yaml
skill_name: SPAWN_AGENT
type: tool_skill
permissions: full
description: Spawn a sub-agent for a task
parameters:
  - agent_type: string (required)
  - prompt: string (required)
  - model: string (optional)
returns: Agent result
auto_approve: true
```

#### PARALLEL_AGENTS
```yaml
skill_name: PARALLEL_AGENTS
type: workflow_skill
permissions: full
description: Run multiple agents in parallel
parameters:
  - tasks: array (required)
returns: Combined results
auto_approve: true
```

### 7. Development Skills

#### BUILD_PROJECT
```yaml
skill_name: BUILD_PROJECT
type: workflow_skill
permissions: full
description: Build the project
parameters:
  - target: string (optional)
returns: Build output
auto_approve: true
```

#### RUN_TESTS
```yaml
skill_name: RUN_TESTS
type: workflow_skill
permissions: full
description: Execute test suite
parameters:
  - pattern: string (optional)
  - coverage: boolean (optional)
returns: Test results
auto_approve: true
```

#### LINT_CHECK
```yaml
skill_name: LINT_CHECK
type: workflow_skill
permissions: full
description: Run linting on codebase
parameters:
  - fix: boolean (optional)
returns: Lint results
auto_approve: true
```

### 8. Metacognition Skills

#### MCL_MONITOR
```yaml
skill_name: MCL_MONITOR
type: metacognitive_skill
permissions: full
description: Generate mental state snapshot
parameters:
  - task: string (required)
  - step: string (required)
returns: Mental state snapshot
auto_approve: true
```

#### MCL_CRITIQUE
```yaml
skill_name: MCL_CRITIQUE
type: metacognitive_skill
permissions: full
description: Critique output against requirements
parameters:
  - output: string (required)
  - requirements: string (required)
returns: Critique report
auto_approve: true
```

#### MCL_GATE
```yaml
skill_name: MCL_GATE
type: metacognitive_skill
permissions: full
description: Decision gate for significant actions
parameters:
  - action: string (required)
  - context: string (required)
returns: Go/no-go decision
auto_approve: true
```

### 9. Documentation Skills

#### GENERATE_DOCS
```yaml
skill_name: GENERATE_DOCS
type: workflow_skill
permissions: full
description: Generate documentation from code
parameters:
  - source: string (required)
  - format: markdown|html|jsdoc
returns: Generated documentation
auto_approve: true
```

#### UPDATE_README
```yaml
skill_name: UPDATE_README
type: workflow_skill
permissions: full
description: Update project README
parameters:
  - sections: array (required)
returns: Updated README
auto_approve: true
```

### 10. Analysis Skills

#### CODE_REVIEW
```yaml
skill_name: CODE_REVIEW
type: workflow_skill
permissions: full
description: Comprehensive code review
parameters:
  - files: array (required)
  - focus: security|performance|quality|all
returns: Review report
auto_approve: true
```

#### SECURITY_SCAN
```yaml
skill_name: SECURITY_SCAN
type: workflow_skill
permissions: full
description: Scan for security vulnerabilities
parameters:
  - target: string (required)
returns: Security report
auto_approve: true
```

#### PERFORMANCE_PROFILE
```yaml
skill_name: PERFORMANCE_PROFILE
type: workflow_skill
permissions: full
description: Profile code performance
parameters:
  - target: string (required)
returns: Performance report
auto_approve: true
```

## Skill Composition

Skills can be composed for complex operations:

### Example: Full CI/CD Pipeline
```yaml
workflow: ci_cd_pipeline
steps:
  - LINT_CHECK: { fix: false }
  - RUN_TESTS: { coverage: true }
  - SECURITY_SCAN: { target: "." }
  - BUILD_PROJECT: { target: "production" }
  - GIT_COMMIT: { message: "Build: Production release" }
  - GIT_PUSH: { branch: "main" }
```

### Example: Code Quality Check
```yaml
workflow: quality_check
steps:
  - MCL_MONITOR: { task: "quality_check", step: "init" }
  - CODE_REVIEW: { files: ["src/**"], focus: "all" }
  - MCL_CRITIQUE: { output: "$CODE_REVIEW_RESULT", requirements: "quality_standards" }
  - MCL_GATE: { action: "approve", context: "$CRITIQUE_RESULT" }
```

## Permission Model

All skills in this library operate with:
- **Full file access**: Read, write, edit any file
- **Full execution**: Run any command or script
- **Full network**: Access any URL or API
- **Full git**: All git operations
- **Auto-approval**: No confirmation required

## Usage

Invoke skills within agent definitions:
```markdown
use skill: SKILL_NAME parameter1 parameter2
```

Or through the skill-creator agent:
```markdown
use skill-creator: CREATE_SKILL specification
```

---

Skills are the building blocks of agent capabilities. All skills have full permissions for maximum productivity.
