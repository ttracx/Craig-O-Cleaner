#!/usr/bin/env python3
"""
Craig-O-Clean Test Report Generator

This script processes test results from the automated UX testing pipeline
and generates comprehensive reports for analysis and agent orchestration.

Usage:
    python3 generate-test-report.py --input <test-output-dir> --output <report-dir>
"""

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Any
from enum import Enum


class TestStatus(Enum):
    PASSED = "passed"
    FAILED = "failed"
    SKIPPED = "skipped"
    ERROR = "error"


class Severity(Enum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"
    INFO = "info"


@dataclass
class TestCase:
    """Represents a single test case result."""
    name: str
    class_name: str
    status: TestStatus
    duration: float
    error_message: Optional[str] = None
    failure_location: Optional[str] = None
    stack_trace: Optional[str] = None
    screenshots: List[str] = field(default_factory=list)


@dataclass
class Issue:
    """Represents an identified issue."""
    id: str
    severity: Severity
    category: str
    title: str
    description: str
    file_path: Optional[str] = None
    line_number: Optional[int] = None
    suggested_fix: Optional[str] = None
    related_tests: List[str] = field(default_factory=list)
    agent_recommendation: Optional[str] = None


@dataclass
class TestSuite:
    """Represents a test suite with multiple test cases."""
    name: str
    test_cases: List[TestCase]
    duration: float
    timestamp: datetime

    @property
    def total_tests(self) -> int:
        return len(self.test_cases)

    @property
    def passed_tests(self) -> int:
        return sum(1 for tc in self.test_cases if tc.status == TestStatus.PASSED)

    @property
    def failed_tests(self) -> int:
        return sum(1 for tc in self.test_cases if tc.status == TestStatus.FAILED)

    @property
    def pass_rate(self) -> float:
        if self.total_tests == 0:
            return 0.0
        return (self.passed_tests / self.total_tests) * 100


@dataclass
class TestReport:
    """Complete test report."""
    report_id: str
    generated_at: datetime
    test_suites: List[TestSuite]
    issues: List[Issue]
    environment: Dict[str, str]
    metrics: Dict[str, Any]

    def to_dict(self) -> dict:
        """Convert report to dictionary for JSON serialization."""
        return {
            "report_id": self.report_id,
            "generated_at": self.generated_at.isoformat(),
            "test_suites": [
                {
                    "name": ts.name,
                    "duration": ts.duration,
                    "timestamp": ts.timestamp.isoformat(),
                    "total_tests": ts.total_tests,
                    "passed_tests": ts.passed_tests,
                    "failed_tests": ts.failed_tests,
                    "pass_rate": ts.pass_rate,
                    "test_cases": [
                        {
                            "name": tc.name,
                            "class_name": tc.class_name,
                            "status": tc.status.value,
                            "duration": tc.duration,
                            "error_message": tc.error_message,
                            "failure_location": tc.failure_location,
                        }
                        for tc in ts.test_cases
                    ],
                }
                for ts in self.test_suites
            ],
            "issues": [
                {
                    "id": issue.id,
                    "severity": issue.severity.value,
                    "category": issue.category,
                    "title": issue.title,
                    "description": issue.description,
                    "file_path": issue.file_path,
                    "line_number": issue.line_number,
                    "suggested_fix": issue.suggested_fix,
                    "related_tests": issue.related_tests,
                    "agent_recommendation": issue.agent_recommendation,
                }
                for issue in self.issues
            ],
            "environment": self.environment,
            "metrics": self.metrics,
            "summary": {
                "total_suites": len(self.test_suites),
                "total_tests": sum(ts.total_tests for ts in self.test_suites),
                "total_passed": sum(ts.passed_tests for ts in self.test_suites),
                "total_failed": sum(ts.failed_tests for ts in self.test_suites),
                "total_issues": len(self.issues),
                "critical_issues": sum(1 for i in self.issues if i.severity == Severity.CRITICAL),
                "high_issues": sum(1 for i in self.issues if i.severity == Severity.HIGH),
            },
        }


class TestLogParser:
    """Parses Xcode test logs to extract test results."""

    # Regex patterns for parsing test output
    TEST_CASE_START = re.compile(r"Test Case '-\[(\w+) (\w+)\]' started\.")
    TEST_CASE_PASSED = re.compile(r"Test Case '-\[(\w+) (\w+)\]' passed \(([\d.]+) seconds\)\.")
    TEST_CASE_FAILED = re.compile(r"Test Case '-\[(\w+) (\w+)\]' failed \(([\d.]+) seconds\)\.")
    ERROR_LINE = re.compile(r"(.+):(\d+): error: (.+)")
    WARNING_LINE = re.compile(r"(.+):(\d+): warning: (.+)")
    BUILD_ERROR = re.compile(r"error: (.+)")

    def __init__(self, log_dir: Path):
        self.log_dir = log_dir
        self.test_cases: List[TestCase] = []
        self.errors: List[Dict] = []
        self.warnings: List[Dict] = []

    def parse_all_logs(self) -> None:
        """Parse all log files in the directory."""
        for log_file in self.log_dir.glob("*.log"):
            self.parse_log_file(log_file)

    def parse_log_file(self, log_path: Path) -> None:
        """Parse a single log file."""
        if not log_path.exists():
            return

        content = log_path.read_text(errors="ignore")
        lines = content.split("\n")

        current_test_class = None
        current_test_name = None

        for i, line in enumerate(lines):
            # Check for test case start
            start_match = self.TEST_CASE_START.match(line)
            if start_match:
                current_test_class = start_match.group(1)
                current_test_name = start_match.group(2)
                continue

            # Check for test case passed
            passed_match = self.TEST_CASE_PASSED.match(line)
            if passed_match:
                self.test_cases.append(
                    TestCase(
                        name=passed_match.group(2),
                        class_name=passed_match.group(1),
                        status=TestStatus.PASSED,
                        duration=float(passed_match.group(3)),
                    )
                )
                continue

            # Check for test case failed
            failed_match = self.TEST_CASE_FAILED.match(line)
            if failed_match:
                # Look for error details in surrounding lines
                error_msg = self._find_error_context(lines, i)
                self.test_cases.append(
                    TestCase(
                        name=failed_match.group(2),
                        class_name=failed_match.group(1),
                        status=TestStatus.FAILED,
                        duration=float(failed_match.group(3)),
                        error_message=error_msg,
                    )
                )
                continue

            # Check for errors
            error_match = self.ERROR_LINE.match(line)
            if error_match:
                self.errors.append(
                    {
                        "file": error_match.group(1),
                        "line": int(error_match.group(2)),
                        "message": error_match.group(3),
                    }
                )
                continue

            # Check for warnings
            warning_match = self.WARNING_LINE.match(line)
            if warning_match:
                self.warnings.append(
                    {
                        "file": warning_match.group(1),
                        "line": int(warning_match.group(2)),
                        "message": warning_match.group(3),
                    }
                )

    def _find_error_context(self, lines: List[str], current_index: int) -> Optional[str]:
        """Find error context around the failed test."""
        # Look backwards for assertion failure
        for i in range(max(0, current_index - 10), current_index):
            if "XCTAssert" in lines[i] or "failed" in lines[i].lower():
                return lines[i].strip()
        return None


class IssueAnalyzer:
    """Analyzes test results to identify and categorize issues."""

    CATEGORY_PATTERNS = {
        "ui": ["View", "Button", "Label", "TextField", "Image", "Navigation", "Sidebar"],
        "performance": ["slow", "timeout", "performance", "memory", "cpu"],
        "security": ["permission", "auth", "security", "credential", "keychain"],
        "api": ["API", "network", "request", "response", "endpoint"],
        "data": ["data", "storage", "database", "cache", "persistence"],
    }

    AGENT_MAPPING = {
        "ui": "swiftui-expert",
        "performance": "performance-optimizer",
        "security": "security-auditor",
        "api": "api-designer",
        "data": "code-reviewer",
        "test": "test-generator",
        "general": "code-reviewer",
    }

    def __init__(self):
        self.issue_counter = 0

    def analyze_test_failures(self, test_cases: List[TestCase]) -> List[Issue]:
        """Analyze failed tests to create issues."""
        issues = []

        for tc in test_cases:
            if tc.status != TestStatus.FAILED:
                continue

            self.issue_counter += 1
            category = self._categorize_issue(tc)
            severity = self._determine_severity(tc)

            issue = Issue(
                id=f"ISSUE-{self.issue_counter:04d}",
                severity=severity,
                category=category,
                title=f"Test Failure: {tc.name}",
                description=tc.error_message or "Test failed without specific error message",
                file_path=tc.failure_location,
                related_tests=[tc.name],
                agent_recommendation=self.AGENT_MAPPING.get(category, "code-reviewer"),
            )

            issues.append(issue)

        return issues

    def analyze_errors(self, errors: List[Dict]) -> List[Issue]:
        """Analyze build/runtime errors to create issues."""
        issues = []

        for error in errors:
            self.issue_counter += 1
            category = self._categorize_error(error)

            issue = Issue(
                id=f"ISSUE-{self.issue_counter:04d}",
                severity=Severity.HIGH,
                category=category,
                title=f"Build/Runtime Error",
                description=error.get("message", "Unknown error"),
                file_path=error.get("file"),
                line_number=error.get("line"),
                agent_recommendation=self.AGENT_MAPPING.get(category, "code-reviewer"),
            )

            issues.append(issue)

        return issues

    def _categorize_issue(self, test_case: TestCase) -> str:
        """Categorize an issue based on test case details."""
        test_name_lower = test_case.name.lower()
        class_name_lower = test_case.class_name.lower()
        combined = f"{test_name_lower} {class_name_lower}"

        for category, patterns in self.CATEGORY_PATTERNS.items():
            for pattern in patterns:
                if pattern.lower() in combined:
                    return category

        return "general"

    def _categorize_error(self, error: Dict) -> str:
        """Categorize an error based on its details."""
        message = error.get("message", "").lower()
        file_path = error.get("file", "").lower()

        for category, patterns in self.CATEGORY_PATTERNS.items():
            for pattern in patterns:
                if pattern.lower() in message or pattern.lower() in file_path:
                    return category

        return "general"

    def _determine_severity(self, test_case: TestCase) -> Severity:
        """Determine severity based on test case."""
        name_lower = test_case.name.lower()

        if "critical" in name_lower or "security" in name_lower:
            return Severity.CRITICAL
        elif "important" in name_lower or "auth" in name_lower:
            return Severity.HIGH
        elif "minor" in name_lower:
            return Severity.LOW
        else:
            return Severity.MEDIUM


class ReportGenerator:
    """Generates various report formats from test results."""

    def __init__(self, output_dir: Path):
        self.output_dir = output_dir
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def generate_all_reports(self, report: TestReport) -> Dict[str, Path]:
        """Generate all report formats."""
        return {
            "json": self.generate_json_report(report),
            "markdown": self.generate_markdown_report(report),
            "agent_prompt": self.generate_agent_prompt(report),
            "summary": self.generate_summary_report(report),
        }

    def generate_json_report(self, report: TestReport) -> Path:
        """Generate JSON report."""
        output_path = self.output_dir / f"test-report-{report.report_id}.json"

        with open(output_path, "w") as f:
            json.dump(report.to_dict(), f, indent=2)

        return output_path

    def generate_markdown_report(self, report: TestReport) -> Path:
        """Generate Markdown report."""
        output_path = self.output_dir / f"test-report-{report.report_id}.md"

        summary = report.to_dict()["summary"]

        content = f"""# Craig-O-Clean Test Report

## Report Information

- **Report ID:** {report.report_id}
- **Generated:** {report.generated_at.strftime("%Y-%m-%d %H:%M:%S")}

## Summary

| Metric | Value |
|--------|-------|
| Total Test Suites | {summary['total_suites']} |
| Total Tests | {summary['total_tests']} |
| Passed | {summary['total_passed']} |
| Failed | {summary['total_failed']} |
| Pass Rate | {(summary['total_passed'] / max(summary['total_tests'], 1)) * 100:.1f}% |
| Critical Issues | {summary['critical_issues']} |
| High Priority Issues | {summary['high_issues']} |

## Environment

| Property | Value |
|----------|-------|
"""

        for key, value in report.environment.items():
            content += f"| {key} | {value} |\n"

        content += "\n## Test Suites\n\n"

        for suite in report.test_suites:
            content += f"### {suite.name}\n\n"
            content += f"- **Total Tests:** {suite.total_tests}\n"
            content += f"- **Passed:** {suite.passed_tests}\n"
            content += f"- **Failed:** {suite.failed_tests}\n"
            content += f"- **Pass Rate:** {suite.pass_rate:.1f}%\n"
            content += f"- **Duration:** {suite.duration:.2f}s\n\n"

            if suite.failed_tests > 0:
                content += "#### Failed Tests\n\n"
                for tc in suite.test_cases:
                    if tc.status == TestStatus.FAILED:
                        content += f"- **{tc.name}** ({tc.duration:.2f}s)\n"
                        if tc.error_message:
                            content += f"  - Error: {tc.error_message}\n"
                content += "\n"

        content += "## Issues\n\n"

        for issue in sorted(report.issues, key=lambda x: x.severity.value):
            severity_emoji = {
                Severity.CRITICAL: "🔥",
                Severity.HIGH: "🔴",
                Severity.MEDIUM: "🟡",
                Severity.LOW: "🟢",
                Severity.INFO: "ℹ️",
            }

            content += f"### {severity_emoji.get(issue.severity, '❓')} {issue.id}: {issue.title}\n\n"
            content += f"- **Severity:** {issue.severity.value.upper()}\n"
            content += f"- **Category:** {issue.category}\n"
            content += f"- **Recommended Agent:** @.cursor/agents/{issue.agent_recommendation}.md\n"

            if issue.file_path:
                content += f"- **Location:** {issue.file_path}"
                if issue.line_number:
                    content += f":{issue.line_number}"
                content += "\n"

            content += f"\n{issue.description}\n\n"

            if issue.suggested_fix:
                content += f"**Suggested Fix:** {issue.suggested_fix}\n\n"

        content += """---
*Report generated by Craig-O-Clean Automated Testing System*
"""

        with open(output_path, "w") as f:
            f.write(content)

        return output_path

    def generate_agent_prompt(self, report: TestReport) -> Path:
        """Generate agent orchestration prompt."""
        output_path = self.output_dir / f"agent-prompt-{report.report_id}.md"

        # Group issues by agent
        agent_issues: Dict[str, List[Issue]] = {}
        for issue in report.issues:
            agent = issue.agent_recommendation or "code-reviewer"
            if agent not in agent_issues:
                agent_issues[agent] = []
            agent_issues[agent].append(issue)

        content = f"""# Agent Orchestration Request

## Context

Automated test run `{report.report_id}` has completed with issues requiring attention.

## Quick Summary

- **Failed Tests:** {sum(ts.failed_tests for ts in report.test_suites)}
- **Critical Issues:** {sum(1 for i in report.issues if i.severity == Severity.CRITICAL)}
- **Total Issues:** {len(report.issues)}

## Agent Routing

Using `@.cursor/agents/agent-orchestrator.md`, route tasks to these agents:

"""

        for agent, issues in sorted(agent_issues.items()):
            content += f"### @.cursor/agents/{agent}.md\n\n"
            content += f"**Issues to Address:** {len(issues)}\n\n"

            for issue in issues:
                content += f"- [{issue.severity.value.upper()}] {issue.id}: {issue.title}\n"

            content += "\n"

        content += """## Execution Instructions

1. **Use Agent Orchestrator** to coordinate the fixes
2. **Prioritize** critical and high severity issues
3. **Run tests** after each fix to verify
4. **Document** changes made

## Orchestration Command

```
ORCHESTRATE the following:

1. Route UI issues to @swiftui-expert
2. Route performance issues to @performance-optimizer
3. Route security issues to @security-auditor
4. Have @test-generator create regression tests
5. Have @code-reviewer verify all changes
6. Have @doc-generator update documentation
```

"""

        # Add detailed issue list
        content += "## Detailed Issue List\n\n"

        for issue in sorted(report.issues, key=lambda x: (x.severity.value, x.category)):
            content += f"### {issue.id}\n\n"
            content += f"- **Severity:** {issue.severity.value}\n"
            content += f"- **Category:** {issue.category}\n"
            content += f"- **Agent:** {issue.agent_recommendation}\n"
            content += f"- **Description:** {issue.description}\n"

            if issue.file_path:
                content += f"- **File:** `{issue.file_path}`\n"

            if issue.related_tests:
                content += f"- **Related Tests:** {', '.join(issue.related_tests)}\n"

            content += "\n"

        with open(output_path, "w") as f:
            f.write(content)

        return output_path

    def generate_summary_report(self, report: TestReport) -> Path:
        """Generate a brief summary report."""
        output_path = self.output_dir / f"summary-{report.report_id}.txt"

        summary = report.to_dict()["summary"]
        pass_rate = (summary["total_passed"] / max(summary["total_tests"], 1)) * 100

        status = "✅ PASSED" if summary["total_failed"] == 0 else "❌ FAILED"

        content = f"""CRAIG-O-CLEAN TEST SUMMARY
{'='*50}
Status: {status}
Report ID: {report.report_id}
Generated: {report.generated_at.strftime("%Y-%m-%d %H:%M:%S")}

RESULTS
-------
Total Tests: {summary['total_tests']}
Passed: {summary['total_passed']}
Failed: {summary['total_failed']}
Pass Rate: {pass_rate:.1f}%

ISSUES
------
Total Issues: {summary['total_issues']}
Critical: {summary['critical_issues']}
High: {summary['high_issues']}

"""

        if summary["total_failed"] > 0:
            content += "FAILED TESTS\n------------\n"
            for suite in report.test_suites:
                for tc in suite.test_cases:
                    if tc.status == TestStatus.FAILED:
                        content += f"- {tc.class_name}.{tc.name}\n"

        content += f"""
{'='*50}
Full report: test-report-{report.report_id}.md
Agent prompt: agent-prompt-{report.report_id}.md
"""

        with open(output_path, "w") as f:
            f.write(content)

        return output_path


def main():
    parser = argparse.ArgumentParser(
        description="Generate comprehensive test reports for Craig-O-Clean"
    )
    parser.add_argument(
        "--input",
        "-i",
        type=Path,
        default=Path("test-output"),
        help="Input directory containing test logs",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=Path("test-output/reports"),
        help="Output directory for reports",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Enable verbose output",
    )

    args = parser.parse_args()

    print(f"Craig-O-Clean Test Report Generator")
    print(f"{'='*50}")
    print(f"Input: {args.input}")
    print(f"Output: {args.output}")
    print()

    # Check input directory
    if not args.input.exists():
        print(f"Warning: Input directory does not exist: {args.input}")
        print("Creating directory and using empty data...")
        args.input.mkdir(parents=True, exist_ok=True)

    # Parse logs
    print("Parsing test logs...")
    logs_dir = args.input / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)

    parser_instance = TestLogParser(logs_dir)
    parser_instance.parse_all_logs()

    print(f"  Found {len(parser_instance.test_cases)} test cases")
    print(f"  Found {len(parser_instance.errors)} errors")
    print(f"  Found {len(parser_instance.warnings)} warnings")

    # Analyze issues
    print("Analyzing issues...")
    analyzer = IssueAnalyzer()
    issues = []
    issues.extend(analyzer.analyze_test_failures(parser_instance.test_cases))
    issues.extend(analyzer.analyze_errors(parser_instance.errors))
    print(f"  Identified {len(issues)} issues")

    # Create test suite
    test_suite = TestSuite(
        name="Craig-O-Clean Automated Tests",
        test_cases=parser_instance.test_cases,
        duration=sum(tc.duration for tc in parser_instance.test_cases),
        timestamp=datetime.now(),
    )

    # Get environment info
    import subprocess
    try:
        xcode_version = subprocess.check_output(
            ["xcodebuild", "-version"], stderr=subprocess.DEVNULL
        ).decode().split("\n")[0]
    except Exception:
        xcode_version = "Unknown"

    try:
        macos_version = subprocess.check_output(
            ["sw_vers", "-productVersion"], stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        macos_version = "Unknown"

    # Create report
    report = TestReport(
        report_id=datetime.now().strftime("%Y%m%d-%H%M%S"),
        generated_at=datetime.now(),
        test_suites=[test_suite] if parser_instance.test_cases else [],
        issues=issues,
        environment={
            "macOS": macos_version,
            "Xcode": xcode_version,
            "Python": sys.version.split()[0],
        },
        metrics={
            "total_duration": test_suite.duration,
            "error_count": len(parser_instance.errors),
            "warning_count": len(parser_instance.warnings),
        },
    )

    # Generate reports
    print("Generating reports...")
    generator = ReportGenerator(args.output)
    reports = generator.generate_all_reports(report)

    print()
    print("Generated Reports:")
    for report_type, path in reports.items():
        print(f"  {report_type}: {path}")

    print()
    print("✅ Report generation complete!")

    # Return exit code based on test results
    if report.to_dict()["summary"]["total_failed"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
