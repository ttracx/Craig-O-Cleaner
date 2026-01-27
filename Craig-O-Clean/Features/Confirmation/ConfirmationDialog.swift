// MARK: - ConfirmationDialog.swift
// Craig-O-Clean - Confirmation Flow for Destructive Operations
// Shows risk details, rollback notes, and optional dry-run preview

import SwiftUI

struct CapabilityConfirmationDialog: View {
    let capability: Capability
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onPreview: (() -> Void)?

    @State private var isConfirmed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: riskIcon)
                    .font(.title2)
                    .foregroundColor(riskColor)
                Text(capability.title)
                    .font(.headline)
            }

            Divider()

            // Description
            Text(capability.description)
                .font(.body)
                .foregroundColor(.secondary)

            // Risk indicator
            HStack {
                Label(capability.riskClass.rawValue.capitalized, systemImage: riskIcon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(riskColor.opacity(0.15))
                    .cornerRadius(6)

                Label(capability.privilegeLevel.rawValue.capitalized, systemImage: privilegeIcon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
            }

            // Rollback notes
            if let rollback = capability.rollbackNotes {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundColor(.orange)
                    Text(rollback)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(8)
            }

            Divider()

            // Actions
            HStack {
                if let onPreview = onPreview, capability.riskClass == .destructive {
                    Button("Preview Changes") {
                        onPreview()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(capability.riskClass == .destructive ? "Confirm Delete" : "Proceed") {
                    onConfirm()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(riskColor)
            }
        }
        .padding(20)
        .frame(minWidth: 400)
    }

    private var riskIcon: String {
        switch capability.riskClass {
        case .safe: return "checkmark.shield"
        case .moderate: return "exclamationmark.triangle"
        case .destructive: return "exclamationmark.triangle.fill"
        }
    }

    private var riskColor: Color {
        switch capability.riskClass {
        case .safe: return .green
        case .moderate: return .orange
        case .destructive: return .red
        }
    }

    private var privilegeIcon: String {
        switch capability.privilegeLevel {
        case .user: return "person"
        case .elevated: return "lock.shield"
        case .automation: return "gearshape.2"
        case .fullDiskAccess: return "externaldrive"
        }
    }
}

// MARK: - Dry Run Preview

struct DryRunPreviewView: View {
    let capability: Capability
    let previewLines: [String]
    let totalSize: String?
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.vibePurple)
                Text("Preview: \(capability.title)")
                    .font(.headline)
            }

            Divider()

            if previewLines.isEmpty {
                Text("No items found to process.")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(previewLines, id: \.self) { line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
            }

            if let size = totalSize {
                Text("Total: \(size)")
                    .font(.callout)
                    .fontWeight(.medium)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("Confirm Delete") { onConfirm() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 450)
    }
}
