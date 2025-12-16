#!/usr/bin/env python3
"""
Test Result Analyzer for Craig-O-Clean
Analyzes test results, app logs, and generates comprehensive issue reports
"""

import json
import sys
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any, Optional
from collections import defaultdict
import re

class TestResultAnalyzer:
    def __init__(self, reports_dir: str):
        self.reports_dir = Path(reports_dir)
        self.issues: List[Dict[str, Any]] = []
        self.errors: List[Dict[str, Any]] = []
        self.warnings: List[Dict[str, Any]] = []
        self.performance_issues: List[Dict[str, Any]] = []
        self.ui_issues: List[Dict[str, Any]] = []
        
    def analyze_test_results(self, test_results_json: str) -> Dict[str, Any]:
        """Analyze xcresult JSON output"""
        try:
            with open(test_results_json, 'r') as f:
                data = json.load(f)
            
            analysis = {
                'total_tests': 0,
                'passed': 0,
                'failed': 0,
                'skipped': 0,
                'failures': []
            }
            
            # Parse xcresult structure (simplified - actual structure may vary)
            if 'actions' in data:
                for action in data.get('actions', {}).get('_values', []):
                    if 'actionResult' in action:
                        tests_ref = action.get('actionResult', {}).get('testsRef', {})
                        if tests_ref:
                            # Extract test information
                            pass
            
            return analysis
        except Exception as e:
            return {'error': str(e)}
    
    def analyze_app_logs(self, app_logs_json: str) -> Dict[str, Any]:
        """Analyze application logs"""
        try:
            with open(app_logs_json, 'r') as f:
                data = json.load(f)
            
            analysis = {
                'total_logs': len(data.get('logs', [])),
                'errors': [],
                'warnings': [],
                'critical_errors': [],
                'performance_metrics': [],
                'ui_events': [],
                'error_summary': defaultdict(int),
                'slow_operations': []
            }
            
            # Analyze logs
            for log in data.get('logs', []):
                level = log.get('level', '').upper()
                category = log.get('category', 'Unknown')
                message = log.get('message', '')
                
                if level in ['ERROR', 'CRITICAL']:
                    analysis['errors'].append({
                        'level': level,
                        'category': category,
                        'message': message,
                        'timestamp': log.get('timestamp'),
                        'error': log.get('error'),
                        'stackTrace': log.get('stackTrace')
                    })
                    analysis['error_summary'][f"{category}:{message[:50]}"] += 1
                    
                    if level == 'CRITICAL':
                        analysis['critical_errors'].append(log)
                
                elif level == 'WARNING':
                    analysis['warnings'].append({
                        'category': category,
                        'message': message,
                        'timestamp': log.get('timestamp')
                    })
            
            # Analyze performance metrics
            metrics = data.get('performanceMetrics', [])
            for metric in metrics:
                duration = metric.get('duration', 0)
                operation = metric.get('operation', 'Unknown')
                
                if duration > 1.0:  # Operations taking more than 1 second
                    analysis['slow_operations'].append({
                        'operation': operation,
                        'duration': duration,
                        'timestamp': metric.get('timestamp')
                    })
            
            analysis['performance_metrics'] = sorted(
                metrics,
                key=lambda x: x.get('duration', 0),
                reverse=True
            )[:10]  # Top 10 slowest
            
            # Analyze UI events
            analysis['ui_events'] = data.get('uiEvents', [])
            
            return analysis
        except Exception as e:
            return {'error': str(e)}
    
    def analyze_test_log(self, test_log: str) -> Dict[str, Any]:
        """Analyze test execution log"""
        try:
            with open(test_log, 'r') as f:
                content = f.read()
            
            analysis = {
                'test_failures': [],
                'build_errors': [],
                'warnings': [],
                'test_count': 0
            }
            
            # Extract test failures
            failure_pattern = r'Test Case.*failed|Assertion failed|XCTAssert.*failed'
            failures = re.findall(failure_pattern, content, re.IGNORECASE)
            analysis['test_failures'] = failures[:20]  # Limit to 20
            
            # Extract build errors
            error_pattern = r'error:.*'
            errors = re.findall(error_pattern, content, re.IGNORECASE)
            analysis['build_errors'] = errors[:20]
            
            # Count tests
            test_pattern = r'Test Case.*\[.*\]'
            tests = re.findall(test_pattern, content)
            analysis['test_count'] = len(tests)
            
            return analysis
        except Exception as e:
            return {'error': str(e)}
    
    def generate_issue_report(self, output_file: str):
        """Generate comprehensive issue report"""
        report = {
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_issues': len(self.issues),
                'errors': len(self.errors),
                'warnings': len(self.warnings),
                'performance_issues': len(self.performance_issues),
                'ui_issues': len(self.ui_issues)
            },
            'issues': self.issues,
            'errors': self.errors,
            'warnings': self.warnings,
            'performance_issues': self.performance_issues,
            'ui_issues': self.ui_issues
        }
        
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        return report
    
    def categorize_issues(self, app_analysis: Dict, test_analysis: Dict, log_analysis: Dict):
        """Categorize issues by type and severity"""
        
        # Critical errors
        for error in app_analysis.get('critical_errors', []):
            self.issues.append({
                'type': 'critical_error',
                'severity': 'critical',
                'category': error.get('category'),
                'message': error.get('message'),
                'source': 'app_logs',
                'stackTrace': error.get('stackTrace')
            })
            self.errors.append(error)
        
        # Regular errors
        for error in app_analysis.get('errors', []):
            self.issues.append({
                'type': 'error',
                'severity': 'high',
                'category': error.get('category'),
                'message': error.get('message'),
                'source': 'app_logs'
            })
            self.errors.append(error)
        
        # Test failures
        for failure in test_analysis.get('test_failures', []):
            self.issues.append({
                'type': 'test_failure',
                'severity': 'high',
                'message': failure,
                'source': 'test_execution'
            })
            self.errors.append({'message': failure, 'source': 'test'})
        
        # Performance issues
        for slow_op in app_analysis.get('slow_operations', []):
            self.issues.append({
                'type': 'performance',
                'severity': 'medium',
                'operation': slow_op.get('operation'),
                'duration': slow_op.get('duration'),
                'source': 'app_logs'
            })
            self.performance_issues.append(slow_op)
        
        # Warnings
        for warning in app_analysis.get('warnings', []):
            self.issues.append({
                'type': 'warning',
                'severity': 'low',
                'category': warning.get('category'),
                'message': warning.get('message'),
                'source': 'app_logs'
            })
            self.warnings.append(warning)
    
    def generate_orchestrator_prompt(self, output_file: str):
        """Generate detailed orchestrator prompt"""
        
        prompt = f"""# Agent Orchestrator Task: Fix Issues from E2E Testing Analysis

## Context

This task is generated from automated analysis of E2E testing results for the Craig-O-Clean macOS application.
The analysis has identified specific issues that need to be addressed by specialized agents.

## Analysis Summary

- **Total Issues Found:** {len(self.issues)}
- **Critical Errors:** {len([i for i in self.issues if i.get('severity') == 'critical'])}
- **High Severity Issues:** {len([i for i in self.issues if i.get('severity') == 'high'])}
- **Medium Severity Issues:** {len([i for i in self.issues if i.get('severity') == 'medium'])}
- **Low Severity Issues:** {len([i for i in self.issues if i.get('severity') == 'low'])}

## Critical Issues (Priority 1)

"""
        
        critical_issues = [i for i in self.issues if i.get('severity') == 'critical']
        for idx, issue in enumerate(critical_issues[:10], 1):
            prompt += f"""
### Critical Issue #{idx}

- **Type:** {issue.get('type')}
- **Category:** {issue.get('category', 'N/A')}
- **Message:** {issue.get('message', 'N/A')}
- **Source:** {issue.get('source')}
"""
            if issue.get('stackTrace'):
                prompt += f"\n**Stack Trace:**\n```\n{issue.get('stackTrace')[:500]}\n```\n"
        
        prompt += "\n## High Severity Issues (Priority 2)\n\n"
        
        high_issues = [i for i in self.issues if i.get('severity') == 'high']
        for idx, issue in enumerate(high_issues[:10], 1):
            prompt += f"""
### High Priority Issue #{idx}

- **Type:** {issue.get('type')}
- **Category:** {issue.get('category', 'N/A')}
- **Message:** {issue.get('message', 'N/A')}
- **Source:** {issue.get('source')}
"""
        
        if self.performance_issues:
            prompt += "\n## Performance Issues\n\n"
            for idx, issue in enumerate(self.performance_issues[:5], 1):
                prompt += f"""
### Performance Issue #{idx}

- **Operation:** {issue.get('operation')}
- **Duration:** {issue.get('duration', 0):.3f}s
- **Recommendation:** Optimize this operation to reduce latency
"""
        
        prompt += """
## Required Agent Actions

Please use the agent orchestrator (@.cursor/agents/agent-orchestrator.md) to coordinate the following agents:

1. **@.cursor/agents/code-reviewer.md** - Review and fix code issues
   - Focus on critical and high severity errors
   - Review stack traces for root causes
   - Ensure proper error handling

2. **@.cursor/agents/swiftui-expert.md** - Fix UI/UX issues
   - Address any UI-related errors
   - Fix SwiftUI view issues
   - Improve user experience

3. **@.cursor/agents/test-generator.md** - Fix and improve tests
   - Fix failing test cases
   - Add tests for uncovered scenarios
   - Improve test reliability

4. **@.cursor/agents/performance-optimizer.md** - Optimize performance
   - Address slow operations identified
   - Optimize memory usage
   - Improve app responsiveness

5. **@.cursor/agents/doc-generator.md** - Update documentation
   - Document fixes applied
   - Update API documentation if needed
   - Add troubleshooting guides

6. **@.cursor/agents/api-designer.md** - Review service layer
   - Fix API/service issues
   - Improve error handling
   - Optimize service calls

7. **@.cursor/agents/security-auditor.md** - Security review
   - Review error handling for security implications
   - Ensure no sensitive data in logs
   - Verify permission handling

## Orchestration Command

```
@agent-orchestrator

Task: Fix issues identified in E2E testing analysis

Context:
- Analysis timestamp: {datetime.now().isoformat()}
- Total issues: {len(self.issues)}
- Critical issues: {len(critical_issues)}
- High priority issues: {len(high_issues)}

Requirements:
1. Prioritize critical and high severity issues
2. Coordinate agents to fix issues systematically
3. Ensure fixes are properly tested
4. Update documentation
5. Perform security review

Expected Output:
- Fixed code with detailed explanations
- Updated tests with improved coverage
- Performance optimizations
- Documentation updates
- Security audit results
```

## Issue Details

For detailed issue information, see the generated issue report JSON file.

## Next Steps

1. Review this orchestrator prompt
2. Execute the orchestration command in Cursor
3. Review agent outputs and apply fixes
4. Re-run automated tests to verify fixes
5. Iterate until all critical and high priority issues are resolved
"""
        
        with open(output_file, 'w') as f:
            f.write(prompt)
        
        return prompt


def main():
    if len(sys.argv) < 2:
        print("Usage: analyze_test_results.py <reports_directory>")
        sys.exit(1)
    
    reports_dir = sys.argv[1]
    analyzer = TestResultAnalyzer(reports_dir)
    
    reports_path = Path(reports_dir)
    
    # Find latest test files
    test_results = list(reports_path.glob("test_results_*.json"))
    app_logs = list(reports_path.glob("logs/app_logs_*.json"))
    test_logs = list(reports_path.glob("logs/test_*.log"))
    
    if not test_results and not app_logs:
        print(f"No test results or app logs found in {reports_dir}")
        sys.exit(1)
    
    # Analyze available files
    app_analysis = {}
    test_analysis = {}
    log_analysis = {}
    
    if app_logs:
        latest_app_logs = max(app_logs, key=os.path.getctime)
        print(f"Analyzing app logs: {latest_app_logs}")
        app_analysis = analyzer.analyze_app_logs(str(latest_app_logs))
    
    if test_results:
        latest_test_results = max(test_results, key=os.path.getctime)
        print(f"Analyzing test results: {latest_test_results}")
        test_analysis = analyzer.analyze_test_results(str(latest_test_results))
    
    if test_logs:
        latest_test_log = max(test_logs, key=os.path.getctime)
        print(f"Analyzing test log: {latest_test_log}")
        log_analysis = analyzer.analyze_test_log(str(latest_test_log))
    
    # Categorize issues
    analyzer.categorize_issues(app_analysis, test_analysis, log_analysis)
    
    # Generate reports
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    issue_report_file = reports_path / f"issue_report_{timestamp}.json"
    orchestrator_prompt_file = reports_path / f"orchestrator_prompt_{timestamp}.md"
    
    analyzer.generate_issue_report(str(issue_report_file))
    analyzer.generate_orchestrator_prompt(str(orchestrator_prompt_file))
    
    print(f"\nAnalysis complete!")
    print(f"Issue report: {issue_report_file}")
    print(f"Orchestrator prompt: {orchestrator_prompt_file}")
    print(f"\nTotal issues found: {len(analyzer.issues)}")
    print(f"  - Critical: {len([i for i in analyzer.issues if i.get('severity') == 'critical'])}")
    print(f"  - High: {len([i for i in analyzer.issues if i.get('severity') == 'high'])}")
    print(f"  - Medium: {len([i for i in analyzer.issues if i.get('severity') == 'medium'])}")
    print(f"  - Low: {len([i for i in analyzer.issues if i.get('severity') == 'low'])}")


if __name__ == "__main__":
    main()
