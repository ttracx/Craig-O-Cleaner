import SwiftUI

struct PermissionsSheet: View {
    @ObservedObject var permissionsManager: PermissionsManager
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Welcome to Craig-O Clean")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Craig-O Terminator Edition requires certain permissions to function properly.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)

            Divider()

            // Permissions List
            VStack(spacing: 16) {
                ForEach(PermissionsManager.PermissionType.allCases, id: \.self) { permission in
                    PermissionRow(
                        permission: permission,
                        status: permissionsManager.getStatus(for: permission),
                        onRequest: {
                            handlePermissionRequest(for: permission)
                        }
                    )
                }
            }
            .padding(.horizontal)

            Divider()

            // Footer
            HStack {
                if permissionsManager.allPermissionsGranted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All permissions granted!")
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(permissionsManager.requiredPermissionsCount) permission(s) required")
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Check Again") {
                    Task {
                        await permissionsManager.checkAllPermissions()
                    }
                }
                .buttonStyle(.bordered)

                Button(permissionsManager.allPermissionsGranted ? "Continue" : "I'll Do This Later") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .onAppear {
            Task {
                await permissionsManager.checkAllPermissions()
            }
        }
    }

    private func handlePermissionRequest(for permission: PermissionsManager.PermissionType) {
        switch permission {
        case .accessibility:
            permissionsManager.requestAccessibility()
        case .fullDiskAccess, .automation:
            permissionsManager.openSystemSettings(for: permission)
        }
    }
}

struct PermissionRow: View {
    let permission: PermissionsManager.PermissionType
    let status: PermissionsManager.PermissionStatus
    let onRequest: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: permission.icon)
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(permission.rawValue)
                    .font(.headline)

                Text(permission.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Status
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .foregroundStyle(Color(status.color))

                Text(status.statusText)
                    .font(.caption)
                    .foregroundStyle(Color(status.color))
            }
            .frame(width: 120)

            // Action button
            if status != .granted {
                Button("Grant") {
                    onRequest()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status == .granted ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status == .granted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    @Previewable @State var isPresented = true

    return PermissionsSheet(
        permissionsManager: PermissionsManager.shared,
        isPresented: $isPresented
    )
}
