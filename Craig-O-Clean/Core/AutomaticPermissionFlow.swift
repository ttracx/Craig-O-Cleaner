// MARK: - AutomaticPermissionFlow.swift
// Craig-O-Clean - Automated Permission Granting Flow
// Guides users through granting permissions with visual assistance and auto-detection

import Foundation
import SwiftUI
import AppKit
import os.log

// MARK: - Permission Flow Step

enum PermissionFlowStep: Int, CaseIterable {
    case welcome = 0
    case accessibility = 1
    case fullDiskAccess = 2
    case browserAutomation = 3
    case complete = 4

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .accessibility: return "Accessibility"
        case .fullDiskAccess: return "Full Disk Access"
        case .browserAutomation: return "Browser Automation"
        case .complete: return "All Set!"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Let's get Craig-O-Clean set up with the permissions it needs"
        case .accessibility:
            return "Required for monitoring system resources and memory usage"
        case .fullDiskAccess:
            return "Required for advanced memory optimization features"
        case .browserAutomation:
            return "Required for managing browser tabs across Safari, Chrome, Edge, and more"
        case .complete:
            return "Craig-O-Clean is ready to help optimize your Mac!"
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "hand.wave.fill"
        case .accessibility: return "accessibility"
        case .fullDiskAccess: return "internaldrive.fill"
        case .browserAutomation: return "safari.fill"
        case .complete: return "checkmark.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome: return .blue
        case .accessibility: return .purple
        case .fullDiskAccess: return .orange
        case .browserAutomation: return .cyan
        case .complete: return .green
        }
    }
}

// MARK: - Automatic Permission Flow

@MainActor
class AutomaticPermissionFlow: ObservableObject {
    static let shared = AutomaticPermissionFlow()

    private let logger = Logger(subsystem: "com.craigoclean.app", category: "PermissionFlow")

    @Published var currentStep: PermissionFlowStep = .welcome
    @Published var isChecking = false
    @Published var flowCompleted = false

    private var permissionsService: PermissionsService?
    private var checkTimer: Timer?

    private init() {}

    /// Start the permission flow
    func startFlow(permissionsService: PermissionsService) {
        logger.info("Starting automatic permission flow")
        self.permissionsService = permissionsService
        currentStep = .welcome
        flowCompleted = false
    }

    /// Advance to next step
    func nextStep() {
        guard let nextStep = PermissionFlowStep(rawValue: currentStep.rawValue + 1) else {
            completeFlow()
            return
        }

        logger.info("Advancing to step: \(nextStep.title)")
        currentStep = nextStep

        // Start checking for permission grant if not on welcome or complete
        if currentStep != .welcome && currentStep != .complete {
            startPermissionCheck()
        }
    }

    /// Skip to a specific step
    func skipToStep(_ step: PermissionFlowStep) {
        logger.info("Skipping to step: \(step.title)")
        stopPermissionCheck()
        currentStep = step

        if currentStep != .welcome && currentStep != .complete {
            startPermissionCheck()
        }
    }

    /// Complete the flow
    func completeFlow() {
        logger.info("Permission flow completed")
        stopPermissionCheck()
        currentStep = .complete
        flowCompleted = true
    }

    /// Open System Settings to the appropriate panel
    func openSystemSettings() {
        let urlString: String

        switch currentStep {
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .fullDiskAccess:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        case .browserAutomation:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        default:
            return
        }

        if let url = URL(string: urlString) {
            logger.info("Opening System Settings: \(urlString)")
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Permission Checking

    private func startPermissionCheck() {
        isChecking = true
        logger.info("Starting permission check for: \(self.currentStep.title)")

        // Check immediately
        checkCurrentPermission()

        // Then check every 1 second
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkCurrentPermission()
            }
        }
    }

    private func stopPermissionCheck() {
        isChecking = false
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func checkCurrentPermission() {
        guard let permissionsService = permissionsService else { return }

        Task {
            await permissionsService.checkAllPermissions()

            let granted: Bool
            switch currentStep {
            case .accessibility:
                granted = permissionsService.accessibilityStatus == PermissionStatus.granted
            case .fullDiskAccess:
                granted = permissionsService.fullDiskAccessStatus == PermissionStatus.granted
            case .browserAutomation:
                granted = permissionsService.allAutomationGranted
            default:
                return
            }

            if granted {
                logger.info("Permission granted for: \(self.currentStep.title)")
                stopPermissionCheck()

                // Auto-advance after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.nextStep()
                }
            }
        }
    }

    /// Check if user can skip current step (permission already granted)
    var canSkipCurrentStep: Bool {
        guard let permissionsService = permissionsService else { return false }

        switch currentStep {
        case .accessibility:
            return permissionsService.accessibilityStatus == PermissionStatus.granted
        case .fullDiskAccess:
            return permissionsService.fullDiskAccessStatus == PermissionStatus.granted
        case .browserAutomation:
            return permissionsService.allAutomationGranted
        default:
            return false
        }
    }
}

// MARK: - Automatic Permission Flow View

struct AutomaticPermissionFlowView: View {
    @EnvironmentObject var permissionFlow: AutomaticPermissionFlow
    @EnvironmentObject var permissions: PermissionsService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress Indicator
            progressBar

            // Content
            ZStack {
                ForEach(PermissionFlowStep.allCases, id: \.rawValue) { step in
                    if permissionFlow.currentStep == step {
                        stepView(for: step)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: permissionFlow.currentStep)

            // Navigation
            navigationButtons
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(PermissionFlowStep.allCases, id: \.rawValue) { step in
                    Rectangle()
                        .fill(step.rawValue <= permissionFlow.currentStep.rawValue ? step.iconColor : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }

            HStack(spacing: 8) {
                ForEach(PermissionFlowStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= permissionFlow.currentStep.rawValue ? step.iconColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)

                    if step.rawValue < PermissionFlowStep.allCases.count - 1 {
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 12)
        }
    }

    // MARK: - Step Views

    @ViewBuilder
    private func stepView(for step: PermissionFlowStep) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: step.icon)
                .font(.system(size: 80))
                .foregroundColor(step.iconColor)

            // Title
            Text(step.title)
                .font(.largeTitle)
                .fontWeight(.bold)

            // Description
            Text(step.description)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            // Step-specific content
            stepContent(for: step)

            Spacer()
        }
    }

    @ViewBuilder
    private func stepContent(for step: PermissionFlowStep) -> some View {
        switch step {
        case .welcome:
            welcomeContent
        case .accessibility, .fullDiskAccess, .browserAutomation:
            permissionContent(for: step)
        case .complete:
            completeContent
        }
    }

    // MARK: - Welcome Content

    private var welcomeContent: some View {
        VStack(spacing: 16) {
            Text("Craig-O-Clean needs a few permissions to work properly")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("We'll guide you through each one")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Permission Content

    private func permissionContent(for step: PermissionFlowStep) -> some View {
        VStack(spacing: 20) {
            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("1")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(step.iconColor))

                    Text("Click \"Open System Settings\" below")
                        .font(.body)
                }

                HStack(spacing: 12) {
                    Text("2")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(step.iconColor))

                    Text("Find Craig-O-Clean in the list")
                        .font(.body)
                }

                HStack(spacing: 12) {
                    Text("3")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(step.iconColor))

                    Text("Toggle the switch to enable")
                        .font(.body)
                }
            }
            .padding(.horizontal, 40)

            // Open Settings Button
            Button(action: {
                permissionFlow.openSystemSettings()
            }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Open System Settings")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: 300)
                .padding()
                .background(step.iconColor)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Checking indicator
            if permissionFlow.isChecking {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Waiting for permission...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Complete Content

    private var completeContent: some View {
        VStack(spacing: 16) {
            Text("Craig-O-Clean is now ready to:")
                .font(.body)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Monitor system resources")
                }

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Optimize memory usage")
                }

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Manage browser tabs")
                }
            }
        }
        .padding(.horizontal, 60)
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            // Back button (only show if not on first or last step)
            if permissionFlow.currentStep != .welcome && permissionFlow.currentStep != .complete {
                Button("Back") {
                    if let prevStep = PermissionFlowStep(rawValue: permissionFlow.currentStep.rawValue - 1) {
                        permissionFlow.skipToStep(prevStep)
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // Skip button (only if permission already granted)
            if permissionFlow.canSkipCurrentStep && permissionFlow.currentStep != .complete {
                Button("Skip") {
                    permissionFlow.nextStep()
                }
                .buttonStyle(.bordered)
            }

            // Next/Done button
            if permissionFlow.currentStep == .complete {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            } else if permissionFlow.currentStep == .welcome {
                Button("Get Started") {
                    permissionFlow.nextStep()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    AutomaticPermissionFlowView()
        .environmentObject(AutomaticPermissionFlow.shared)
        .environmentObject(PermissionsService())
}
