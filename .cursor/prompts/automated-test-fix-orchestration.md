# Automated Test Fix Orchestration Prompt Template

## Purpose

This prompt template is used by the automated UX testing system to orchestrate
specialized agents for fixing issues identified during end-to-end testing.

## Usage

After running the automated testing script (`./scripts/automated-ux-testing.sh`),
use this template with the generated test report to coordinate fixes.

---

# ORCHESTRATE: Craig-O-Clean Automated Test Fixes

## Request Type
Multi-agent coordinated fix for automated test failures

## Context
The Craig-O-Clean automated UX testing pipeline has identified issues that
require attention from multiple specialized agents.

## Test Report Location
- **Report Directory:** `test-output/reports/`
- **Agent Prompts:** `test-output/agent-prompts/`
- **Logs:** `test-output/logs/`

## Orchestration Plan

Using `@.cursor/agents/agent-orchestrator.md`, coordinate the following workflow:

### Phase 1: Analysis & Triage

**Agent:** `@.cursor/agents/code-reviewer.md`

**Tasks:**
1. Review the test failure report at `test-output/reports/test-report-*.md`
2. Analyze the root causes of each failure
3. Categorize issues by:
   - UI/SwiftUI issues
   - Performance issues
   - Security/Permission issues
   - Logic/Business rule issues
   - Test infrastructure issues
4. Create a prioritized fix list

**Output:** Categorized issue list with recommended fixes

---

### Phase 2: SwiftUI/UI Fixes

**Agent:** `@.cursor/agents/swiftui-expert.md`

**Tasks:**
1. Fix UI rendering issues identified in test failures
2. Address navigation problems
3. Fix accessibility issues
4. Resolve view state management problems
5. Optimize SwiftUI view performance

**Files to Focus On:**
- `Craig-O-Clean/UI/*.swift`
- `Craig-O-Clean/ContentView.swift`
- `Craig-O-Clean/MenuBarView.swift`

**SwiftUI Commands:**
- `VIEW [component]` - Fix specific view component
- `NAVIGATION [flow]` - Fix navigation issues
- `ACCESSIBILITY [view]` - Add accessibility support
- `REFACTOR_UIKIT [code]` - Modernize any legacy patterns

---

### Phase 3: Test Fixes & Coverage

**Agent:** `@.cursor/agents/test-generator.md`

**Tasks:**
1. Fix failing test cases in `Tests/CraigOCleanUITests/AutomatedE2ETests.swift`
2. Update test expectations if needed
3. Add missing test coverage for edge cases
4. Create regression tests for fixed issues

**Test Commands:**
- `GENERATE_TESTS [file]` - Generate comprehensive tests
- `EDGE_CASES [file]` - Focus on boundary conditions
- `COVERAGE_GAP [file] [existing_tests]` - Fill coverage gaps

---

### Phase 4: Performance Optimization

**Agent:** `@.cursor/agents/performance-optimizer.md`

**Tasks:**
1. Analyze performance bottlenecks from test logs
2. Optimize slow operations identified in E2E tests
3. Review memory usage patterns
4. Ensure app launch time is optimal

**Performance Commands:**
- `ANALYZE [file]` - Full performance analysis
- `MEMORY_AUDIT [file]` - Memory usage review
- `BENCHMARK [code_a] [code_b]` - Compare implementations

---

### Phase 5: Security Audit

**Agent:** `@.cursor/agents/security-auditor.md`

**Tasks:**
1. Review permission handling issues
2. Audit data protection
3. Check keychain usage
4. Verify secure coding practices

**Security Commands:**
- `AUDIT [file]` - Full security audit
- `AUTH_REVIEW [auth_code]` - Authentication review
- `SECRETS_SCAN [file]` - Check for hardcoded secrets

---

### Phase 6: API/Service Review

**Agent:** `@.cursor/agents/api-designer.md`

**Tasks:**
1. Review any API contract issues
2. Validate service responses
3. Check error handling
4. Ensure API consistency

**API Commands:**
- `VALIDATE_CONTRACT [spec]` - Validate API specification
- `ERROR_SCHEMA [api]` - Design error responses

---

### Phase 7: Documentation Update

**Agent:** `@.cursor/agents/doc-generator.md`

**Tasks:**
1. Update documentation for any changes made
2. Document new test cases
3. Update API documentation if changed
4. Add inline code comments where needed

**Doc Commands:**
- `DOCUMENT [file]` - Generate documentation
- `JSDOC [file]` - Add JSDoc comments (for any JS)
- `CHANGELOG [changes]` - Generate changelog entry

---

## Validation Steps

After all agents complete their tasks:

1. **Re-run Tests:**
   ```bash
   ./scripts/automated-ux-testing.sh --quick
   ```

2. **Verify All Tests Pass:**
   - All UI tests should pass
   - No new warnings introduced
   - Performance metrics maintained

3. **Code Review:**
   - Have `@.cursor/agents/code-reviewer.md` review all changes
   - Ensure no regressions

4. **Final Documentation:**
   - Update CHANGELOG.md
   - Document any architectural changes

---

## Success Criteria

- [ ] All previously failing tests now pass
- [ ] No new test failures introduced
- [ ] Code review approved
- [ ] Performance metrics equal or better
- [ ] Documentation updated
- [ ] No critical security issues

---

## Conflict Resolution

If agents provide conflicting recommendations:

1. **Prioritize by:** Security > Correctness > Performance > Style
2. **Escalate to:** code-reviewer for final decision
3. **Document:** Any trade-offs made

---

## Continuous Improvement

After fixing issues, consider:

1. Adding new E2E test cases for edge cases found
2. Updating the debug logging system
3. Enhancing the automated testing script
4. Improving agent prompts based on learnings

---

*This orchestration template is part of the Craig-O-Clean automated testing system.*
*See `/scripts/automated-ux-testing.sh` for the testing pipeline.*
