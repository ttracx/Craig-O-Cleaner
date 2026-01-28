// MARK: - PermissionSetupView.swift
// Craig-O-Clean Sandbox Edition - Permission Setup Guide
// Guides users through granting necessary permissions

import SwiftUI

struct PermissionSetupView: View {
    @EnvironmentObject var permissionsManager: SandboxPermissionsManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var isCheckingPermission = false

    private let steps = PermissionOnboardingStep.allSteps

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Content
            if currentStep < steps.count {
                stepView(for: steps[currentStep])
            } else {
                completionView
            }

            Divider()

            // Footer
            footerView
        }
        .frame(width: 500, height: 450)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Permission Setup")
                .font(.title2)
                .fontWeight(.bold)

            Text("Craig-O-Clean needs a few permissions to work its magic")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count + 1, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Step View

    private func stepView(for step: PermissionOnboardingStep) -> some View {
        VStack(spacing: 20) {
            // Step header
            HStack {
                Image(systemName: step.type.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text(step.title)
                        .font(.headline)
                    Text(step.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status badge
                statusBadge(for: step.type)
            }
            .padding()
            .background(Color(.textBackgroundColor))
            .cornerRadius(10)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("How to enable:")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(Array(step.instructions.enumerated()), id: \.offset) { index, instruction in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.accentColor)
                            .clipShape(Circle())

                        Text(instruction)
                            .font(.subheadline)
                    }
                }
            }
            .padding()

            Spacer()

            // Action button
            Button {
                requestPermission(for: step.type)
            } label: {
                HStack {
                    if isCheckingPermission {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    Text(buttonTitle(for: step.type))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isCheckingPermission)
        }
        .padding()
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("All Set!")
                .font(.title)
                .fontWeight(.bold)

            Text("Craig-O-Clean is ready to help optimize your Mac")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Summary
            VStack(spacing: 12) {
                let summary = permissionsManager.permissionSummary
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(summary.granted) of \(summary.total) permissions granted")
                }

                if summary.criticalMissing {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Some features may be limited")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.textBackgroundColor))
            .cornerRadius(10)

            Spacer()
        }
        .padding()
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if currentStep > 0 && currentStep < steps.count {
                Button("Back") {
                    currentStep -= 1
                }
            }

            Spacer()

            if currentStep < steps.count {
                Button("Skip") {
                    currentStep += 1
                }
                .foregroundColor(.secondary)
            } else {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    // MARK: - Status Badge

    private func statusBadge(for type: SandboxPermissionType) -> some View {
        let status = getStatus(for: type)

        return HStack(spacing: 4) {
            Circle()
                .fill(status.isGranted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(status.displayText)
                .font(.caption)
                .foregroundColor(status.isGranted ? .green : .orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.isGranted ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Helper Methods

    private func getStatus(for type: SandboxPermissionType) -> PermissionStatus {
        if type == .accessibility {
            return permissionsManager.accessibilityStatus
        }
        return permissionsManager.automationStatus[type] ?? .unknown
    }

    private func buttonTitle(for type: SandboxPermissionType) -> String {
        let status = getStatus(for: type)
        if status.isGranted {
            return "Continue"
        }
        return "Grant Permission"
    }

    private func requestPermission(for type: SandboxPermissionType) {
        isCheckingPermission = true

        Task {
            if type == .accessibility {
                permissionsManager.requestAccessibilityPermission()
                // Wait a moment for user to potentially grant permission
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await permissionsManager.refreshAllPermissions()
            } else {
                _ = await permissionsManager.requestAutomationPermission(for: type)
            }

            isCheckingPermission = false
            currentStep += 1
        }
    }
}

// MARK: - Preview

#Preview {
    PermissionSetupView()
        .environmentObject(SandboxPermissionsManager())
}
