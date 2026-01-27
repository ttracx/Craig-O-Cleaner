//
//  AIWorkflowTests.swift
//  CraigOTerminator Tests
//
//  Created by Claude Code on 2026-01-27.
//  Copyright © 2026 NeuralQuantum.ai. All rights reserved.
//

import XCTest
@testable import CraigOTerminator

/// Tests for AI Workflow orchestration components
final class AIWorkflowTests: XCTestCase {

    // MARK: - Properties

    var mockCatalog: CapabilityCatalog!
    var mockOllamaClient: MockOllamaClient!
    var plannerAgent: PlannerAgent!
    var safetyAgent: SafetyAgent!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        // Create mock catalog with test capabilities
        mockCatalog = createMockCatalog()
        mockOllamaClient = MockOllamaClient()

        plannerAgent = PlannerAgent(
            ollamaClient: mockOllamaClient,
            capabilityCatalog: mockCatalog,
            model: "test"
        )

        safetyAgent = SafetyAgent(
            ollamaClient: mockOllamaClient,
            capabilityCatalog: mockCatalog,
            model: "test"
        )
    }

    override func tearDown() {
        mockCatalog = nil
        mockOllamaClient = nil
        plannerAgent = nil
        safetyAgent = nil
        super.tearDown()
    }

    // MARK: - PlannerAgent Tests

    func testPlannerGeneratesValidWorkflow() async throws {
        // Given
        let query = "Check system status"
        let mockResponse = """
        {
          "workflow": [
            {"capabilityId": "diag.mem", "arguments": {}, "reason": "Check memory"},
            {"capabilityId": "diag.disk", "arguments": {}, "reason": "Check disk"}
          ],
          "summary": "System diagnostics"
        }
        """
        mockOllamaClient.mockResponse = mockResponse

        // When
        let plan = try await plannerAgent.planWorkflow(from: query)

        // Then
        XCTAssertEqual(plan.workflow.count, 2)
        XCTAssertEqual(plan.workflow[0].capabilityId, "diag.mem")
        XCTAssertEqual(plan.workflow[1].capabilityId, "diag.disk")
        XCTAssertEqual(plan.summary, "System diagnostics")
    }

    func testPlannerRejectsInvalidJSON() async {
        // Given
        let query = "Test query"
        mockOllamaClient.mockResponse = "This is not JSON"

        // When/Then
        do {
            _ = try await plannerAgent.planWorkflow(from: query)
            XCTFail("Should throw error for invalid JSON")
        } catch {
            XCTAssertTrue(error is PlannerError)
        }
    }

    func testPlannerStripsMarkdownFormatting() async throws {
        // Given
        let query = "Test query"
        let mockResponse = """
        ```json
        {
          "workflow": [
            {"capabilityId": "diag.mem", "arguments": {}, "reason": "Test"}
          ],
          "summary": "Test"
        }
        ```
        """
        mockOllamaClient.mockResponse = mockResponse

        // When
        let plan = try await plannerAgent.planWorkflow(from: query)

        // Then
        XCTAssertEqual(plan.workflow.count, 1)
    }

    func testPlannerValidatesCapabilityIDs() async {
        // Given
        let query = "Test query"
        let mockResponse = """
        {
          "workflow": [
            {"capabilityId": "invalid.capability", "arguments": {}, "reason": "Test"}
          ],
          "summary": "Test"
        }
        """
        mockOllamaClient.mockResponse = mockResponse

        // When/Then
        do {
            _ = try await plannerAgent.planWorkflow(from: query)
            XCTFail("Should throw error for invalid capability ID")
        } catch let error as PlannerError {
            if case .invalidCapabilityId(let id) = error {
                XCTAssertEqual(id, "invalid.capability")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPlannerRejectsEmptyWorkflow() async {
        // Given
        let query = "Test query"
        let mockResponse = """
        {
          "workflow": [],
          "summary": "Empty workflow"
        }
        """
        mockOllamaClient.mockResponse = mockResponse

        // When/Then
        do {
            _ = try await plannerAgent.planWorkflow(from: query)
            XCTFail("Should throw error for empty workflow")
        } catch let error as PlannerError {
            XCTAssertEqual(error, .emptyWorkflow)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPlannerRejectsTooLongWorkflow() async {
        // Given
        let query = "Test query"
        let steps = (1...11).map { n in
            """
            {"capabilityId": "diag.mem", "arguments": {}, "reason": "Step \(n)"}
            """
        }.joined(separator: ",")

        let mockResponse = """
        {
          "workflow": [\(steps)],
          "summary": "Too long"
        }
        """
        mockOllamaClient.mockResponse = mockResponse

        // When/Then
        do {
            _ = try await plannerAgent.planWorkflow(from: query)
            XCTFail("Should throw error for workflow too long")
        } catch let error as PlannerError {
            if case .workflowTooLong(let count) = error {
                XCTAssertEqual(count, 11)
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - SafetyAgent Tests

    func testSafetyAgentApprovesSafeWorkflow() async throws {
        // Given
        let plan = WorkflowPlan(
            workflow: [
                WorkflowStep(capabilityId: "diag.mem", arguments: [:], reason: "Check memory"),
                WorkflowStep(capabilityId: "diag.disk", arguments: [:], reason: "Check disk")
            ],
            summary: "Safe diagnostics"
        )

        // When
        let assessment = try await safetyAgent.assessSafety(of: plan)

        // Then
        XCTAssertTrue(assessment.approved)
        XCTAssertEqual(assessment.riskLevel, .safe)
        XCTAssertFalse(assessment.requiresConfirmation)
    }

    func testSafetyAgentFlagsModerateRisk() async throws {
        // Given
        let plan = WorkflowPlan(
            workflow: [
                WorkflowStep(capabilityId: "moderate.op", arguments: [:], reason: "Moderate operation")
            ],
            summary: "Moderate risk workflow"
        )

        // When
        let assessment = try await safetyAgent.assessSafety(of: plan)

        // Then
        XCTAssertEqual(assessment.riskLevel, .moderate)
        XCTAssertTrue(assessment.requiresConfirmation)
    }

    func testSafetyAgentFlagsDestructiveRisk() async throws {
        // Given
        let plan = WorkflowPlan(
            workflow: [
                WorkflowStep(capabilityId: "destructive.op", arguments: [:], reason: "Destructive operation")
            ],
            summary: "Destructive workflow"
        )

        // When
        let assessment = try await safetyAgent.assessSafety(of: plan)

        // Then
        XCTAssertEqual(assessment.riskLevel, .destructive)
        XCTAssertTrue(assessment.requiresConfirmation)
        XCTAssertFalse(assessment.warnings.isEmpty)
    }

    func testSafetyAgentDetectsElevatedOperations() async throws {
        // Given
        let plan = WorkflowPlan(
            workflow: [
                WorkflowStep(capabilityId: "elevated.op", arguments: [:], reason: "Needs admin")
            ],
            summary: "Elevated operation"
        )

        // When
        let assessment = try await safetyAgent.assessSafety(of: plan)

        // Then
        XCTAssertTrue(assessment.warnings.contains { $0.contains("administrator") })
    }

    // MARK: - WorkflowStep Tests

    func testWorkflowStepIdentifiable() {
        // Given
        let step1 = WorkflowStep(capabilityId: "test.1", arguments: [:], reason: "Test")
        let step2 = WorkflowStep(capabilityId: "test.2", arguments: [:], reason: "Test")

        // Then
        XCTAssertEqual(step1.id, "test.1")
        XCTAssertNotEqual(step1.id, step2.id)
    }

    // MARK: - RiskLevel Tests

    func testRiskLevelComparable() {
        XCTAssertTrue(RiskLevel.safe < RiskLevel.moderate)
        XCTAssertTrue(RiskLevel.moderate < RiskLevel.destructive)
        XCTAssertFalse(RiskLevel.destructive < RiskLevel.safe)
    }

    func testRiskLevelRawValue() {
        XCTAssertEqual(RiskLevel.safe.rawValue, 0)
        XCTAssertEqual(RiskLevel.moderate.rawValue, 1)
        XCTAssertEqual(RiskLevel.destructive.rawValue, 2)
    }

    // MARK: - WorkflowResult Tests

    func testWorkflowResultSuccessRate() {
        // Given
        let plan = WorkflowPlan(workflow: [], summary: "Test")
        let results = [
            WorkflowStepResult(
                step: WorkflowStep(capabilityId: "test.1", arguments: [:], reason: "Test"),
                stepNumber: 1,
                success: true,
                output: nil,
                error: nil,
                duration: 1.0,
                isCritical: false
            ),
            WorkflowStepResult(
                step: WorkflowStep(capabilityId: "test.2", arguments: [:], reason: "Test"),
                stepNumber: 2,
                success: false,
                output: nil,
                error: "Error",
                duration: 1.0,
                isCritical: false
            ),
            WorkflowStepResult(
                step: WorkflowStep(capabilityId: "test.3", arguments: [:], reason: "Test"),
                stepNumber: 3,
                success: true,
                output: nil,
                error: nil,
                duration: 1.0,
                isCritical: false
            )
        ]

        let workflowResult = WorkflowResult(
            plan: plan,
            results: results,
            failedSteps: results.filter { !$0.success },
            totalDuration: 3.0,
            completedAt: Date(),
            success: false
        )

        // Then
        XCTAssertEqual(workflowResult.successRate, 2.0/3.0, accuracy: 0.01)
    }

    func testWorkflowResultSummaryText() {
        // Given - Success case
        let successPlan = WorkflowPlan(workflow: [], summary: "Test")
        let successResults = [
            WorkflowStepResult(
                step: WorkflowStep(capabilityId: "test.1", arguments: [:], reason: "Test"),
                stepNumber: 1,
                success: true,
                output: nil,
                error: nil,
                duration: 1.0,
                isCritical: false
            )
        ]

        let successResult = WorkflowResult(
            plan: successPlan,
            results: successResults,
            failedSteps: [],
            totalDuration: 1.0,
            completedAt: Date(),
            success: true
        )

        // Then
        XCTAssertTrue(successResult.summaryText.contains("Successfully completed"))

        // Given - Failure case
        let failurePlan = WorkflowPlan(workflow: [], summary: "Test")
        let failureResults = [
            WorkflowStepResult(
                step: WorkflowStep(capabilityId: "test.1", arguments: [:], reason: "Test"),
                stepNumber: 1,
                success: false,
                output: nil,
                error: "Failed",
                duration: 1.0,
                isCritical: true
            )
        ]

        let failureResult = WorkflowResult(
            plan: failurePlan,
            results: failureResults,
            failedSteps: failureResults,
            totalDuration: 1.0,
            completedAt: Date(),
            success: false
        )

        // Then
        XCTAssertTrue(failureResult.summaryText.contains("failed"))
    }

    // MARK: - Helper Methods

    private func createMockCatalog() -> CapabilityCatalog {
        let capabilities = [
            Capability(
                id: "diag.mem",
                title: "Memory Check",
                description: "Check memory usage",
                group: .diagnostics,
                commandTemplate: "memory_pressure",
                arguments: [],
                workingDirectory: nil,
                timeout: 10,
                privilegeLevel: .user,
                riskClass: .safe,
                outputParser: .text,
                parserPattern: nil,
                preflightChecks: [],
                requiredPaths: [],
                requiredApps: [],
                icon: "memorychip",
                rollbackNotes: nil,
                estimatedDuration: 1
            ),
            Capability(
                id: "diag.disk",
                title: "Disk Check",
                description: "Check disk usage",
                group: .diagnostics,
                commandTemplate: "df -h",
                arguments: [],
                workingDirectory: nil,
                timeout: 10,
                privilegeLevel: .user,
                riskClass: .safe,
                outputParser: .text,
                parserPattern: nil,
                preflightChecks: [],
                requiredPaths: [],
                requiredApps: [],
                icon: "internaldrive",
                rollbackNotes: nil,
                estimatedDuration: 1
            ),
            Capability(
                id: "moderate.op",
                title: "Moderate Operation",
                description: "Moderate risk operation",
                group: .quickClean,
                commandTemplate: "test",
                arguments: [],
                workingDirectory: nil,
                timeout: 10,
                privilegeLevel: .user,
                riskClass: .moderate,
                outputParser: .text,
                parserPattern: nil,
                preflightChecks: [],
                requiredPaths: [],
                requiredApps: [],
                icon: "exclamationmark.triangle",
                rollbackNotes: "Can be undone",
                estimatedDuration: 5
            ),
            Capability(
                id: "destructive.op",
                title: "Destructive Operation",
                description: "Permanent data loss",
                group: .deepClean,
                commandTemplate: "test",
                arguments: [],
                workingDirectory: nil,
                timeout: 10,
                privilegeLevel: .user,
                riskClass: .destructive,
                outputParser: .text,
                parserPattern: nil,
                preflightChecks: [],
                requiredPaths: [],
                requiredApps: [],
                icon: "xmark.circle",
                rollbackNotes: "Cannot be recovered",
                estimatedDuration: 10
            ),
            Capability(
                id: "elevated.op",
                title: "Elevated Operation",
                description: "Requires admin privileges",
                group: .system,
                commandTemplate: "test",
                arguments: [],
                workingDirectory: nil,
                timeout: 10,
                privilegeLevel: .elevated,
                riskClass: .moderate,
                outputParser: .text,
                parserPattern: nil,
                preflightChecks: [],
                requiredPaths: [],
                requiredApps: [],
                icon: "lock.shield",
                rollbackNotes: nil,
                estimatedDuration: 5
            )
        ]

        return CapabilityCatalog(capabilities: capabilities)
    }
}

// MARK: - Mock Ollama Client

class MockOllamaClient: OllamaClient {
    var mockResponse: String = "{}"
    var shouldFail: Bool = false

    override func generate(
        model: String,
        prompt: String,
        system: String?,
        temperature: Double,
        stream: Bool
    ) async throws -> String {
        if shouldFail {
            throw OllamaError.serverNotRunning
        }
        return mockResponse
    }

    override func checkServerStatus() async -> Bool {
        return !shouldFail
    }
}

// MARK: - Error Equality

extension PlannerError: Equatable {
    public static func == (lhs: PlannerError, rhs: PlannerError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidJSONResponse, .invalidJSONResponse):
            return true
        case (.emptyWorkflow, .emptyWorkflow):
            return true
        case (.workflowTooLong(let a), .workflowTooLong(let b)):
            return a == b
        case (.invalidCapabilityId(let a), .invalidCapabilityId(let b)):
            return a == b
        case (.modelNotAvailable, .modelNotAvailable):
            return true
        default:
            return false
        }
    }
}
