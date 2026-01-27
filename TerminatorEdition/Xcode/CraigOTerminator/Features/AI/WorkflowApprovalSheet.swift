//
//  WorkflowApprovalSheet.swift
//  CraigOTerminator
//
//  Created by Claude Code on 2026-01-27.
//  Copyright © 2026 NeuralQuantum.ai. All rights reserved.
//

import SwiftUI

/// Sheet for reviewing and approving AI-generated workflows
struct WorkflowApprovalSheet: View {

    // MARK: - Properties

    let workflow: WorkflowPlan
    let safetyAssessment: SafetyAssessment
    let onApprove: () -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerView

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Summary
                    summarySection

                    Divider()

                    // Risk Assessment
                    riskAssessmentSection

                    Divider()

                    // Workflow Steps
                    workflowStepsSection

                    if !safetyAssessment.warnings.isEmpty {
                        Divider()
                        warningsSection
                    }

                    if !safetyAssessment.suggestions.isEmpty {
                        Divider()
                        suggestionsSection
                    }
                }
                .padding()
            }

            Divider()

            // Actions
            actionsView
        }
        .frame(width: 600, height: 700)
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: riskIcon)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)

                Text("Workflow Approval")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("Review this workflow before execution")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Summary", systemImage: "doc.text")
                .font(.headline)

            Text(workflow.summary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
        }
    }

    // MARK: - Risk Assessment Section

    private var riskAssessmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Risk Assessment", systemImage: "shield.checkered")
                .font(.headline)

            HStack(spacing: 12) {
                riskBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(riskLevelText)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(riskDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(riskBackgroundColor)
            .cornerRadius(8)
        }
    }

    // MARK: - Workflow Steps Section

    private var workflowStepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Workflow Steps (\(workflow.workflow.count))", systemImage: "list.number")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(workflow.workflow.enumerated()), id: \.offset) { index, step in
                    WorkflowStepRow(
                        stepNumber: index + 1,
                        step: step
                    )
                }
            }
        }
    }

    // MARK: - Warnings Section

    private var warningsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Warnings", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(safetyAssessment.warnings, id: \.self) { warning in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)

                        Text(warning)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Suggestions Section

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suggestions", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(safetyAssessment.suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Text(suggestion)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Actions View

    private var actionsView: some View {
        HStack(spacing: 12) {
            Button {
                onCancel()
                dismiss()
            } label: {
                Text("Cancel")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            Button {
                onApprove()
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text(safetyAssessment.approved ? "Execute Workflow" : "Execute Anyway")
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!safetyAssessment.approved && safetyAssessment.riskLevel == .destructive)
        }
        .padding()
    }

    // MARK: - Computed Properties

    private var riskIcon: String {
        switch safetyAssessment.riskLevel {
        case .safe:
            return "checkmark.shield.fill"
        case .moderate:
            return "exclamationmark.shield.fill"
        case .destructive:
            return "xmark.shield.fill"
        }
    }

    private var riskBadge: some View {
        Group {
            switch safetyAssessment.riskLevel {
            case .safe:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            case .moderate:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
            case .destructive:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.title2)
            }
        }
    }

    private var riskLevelText: String {
        switch safetyAssessment.riskLevel {
        case .safe:
            return "Safe Operation"
        case .moderate:
            return "Moderate Risk"
        case .destructive:
            return "Destructive Operation"
        }
    }

    private var riskDescription: String {
        switch safetyAssessment.riskLevel {
        case .safe:
            return "No permanent changes will be made"
        case .moderate:
            return "Some system services may restart briefly"
        case .destructive:
            return "May permanently delete data or modify system files"
        }
    }

    private var riskBackgroundColor: Color {
        switch safetyAssessment.riskLevel {
        case .safe:
            return Color.green.opacity(0.1)
        case .moderate:
            return Color.orange.opacity(0.1)
        case .destructive:
            return Color.red.opacity(0.1)
        }
    }
}

// MARK: - Workflow Step Row

struct WorkflowStepRow: View {
    let stepNumber: Int
    let step: WorkflowStep

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            Text("\(stepNumber)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(step.reason)
                    .font(.callout)
                    .fontWeight(.medium)

                Text(step.capabilityId)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Previews

#Preview("Safe Workflow") {
    WorkflowApprovalSheet(
        workflow: WorkflowPlan(
            workflow: [
                WorkflowStep(
                    capabilityId: "diag.mem.pressure",
                    arguments: [:],
                    reason: "Check memory pressure"
                ),
                WorkflowStep(
                    capabilityId: "diag.disk.free",
                    arguments: [:],
                    reason: "Check available disk space"
                )
            ],
            summary: "Analyzes system memory and disk usage"
        ),
        safetyAssessment: SafetyAssessment(
            approved: true,
            riskLevel: .safe,
            warnings: [],
            suggestions: ["These operations only read system information"],
            requiresConfirmation: false
        ),
        onApprove: {},
        onCancel: {}
    )
}

#Preview("Destructive Workflow") {
    WorkflowApprovalSheet(
        workflow: WorkflowPlan(
            workflow: [
                WorkflowStep(
                    capabilityId: "disk.trash.empty",
                    arguments: [:],
                    reason: "Empty trash"
                ),
                WorkflowStep(
                    capabilityId: "deep.cache.user",
                    arguments: [:],
                    reason: "Clear user caches"
                )
            ],
            summary: "Cleans up disk space"
        ),
        safetyAssessment: SafetyAssessment(
            approved: false,
            riskLevel: .destructive,
            warnings: [
                "Empty Trash will permanently delete all files in trash",
                "Clearing user caches may affect application performance"
            ],
            suggestions: [
                "Review trash contents before emptying",
                "Consider running disk analysis first"
            ],
            requiresConfirmation: true
        ),
        onApprove: {},
        onCancel: {}
    )
}
