//
//  MenuBarContentView.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import SwiftUI

// MARK: - Menu Bar Content View

/// Main menu bar content structure with capability-based navigation
struct MenuBarContentView: View {
    @Environment(CapabilityCatalog.self) private var catalog

    var body: some View {
        VStack(spacing: 0) {
            // Header
            MenuHeaderView()

            Divider()

            // Status Section
            StatusSection()

            Divider()

            // Capability Groups
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(CapabilityGroup.allCases, id: \.self) { group in
                        if catalog.count(for: group) > 0 {
                            CapabilityGroupSection(group: group)
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 400)

            Divider()

            // Footer Actions
            MenuFooterView()
        }
        .frame(width: 350)
    }
}

// MARK: - Menu Header

struct MenuHeaderView: View {
    var body: some View {
        HStack {
            Image(systemName: "paintbrush.pointed.fill")
                .font(.system(size: 20))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.vibePrimary, .vibeSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Craig-O-Clean")
                .font(VibeFont.title)
                .foregroundColor(.vibeText)

            Spacer()

            Text("v1.0")
                .font(VibeFont.caption)
                .foregroundColor(.vibeTextSecondary)
        }
        .padding(VibeSpacing.md)
    }
}

// MARK: - Capability Group Section

struct CapabilityGroupSection: View {
    let group: CapabilityGroup
    @Environment(CapabilityCatalog.self) private var catalog
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Group Header
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: group.icon)
                        .foregroundColor(.vibePrimary)
                        .font(.system(size: 14))

                    Text(group.displayTitle)
                        .font(VibeFont.headline)
                        .foregroundColor(.vibeText)

                    Spacer()

                    Text("\(catalog.count(for: group))")
                        .font(VibeFont.caption)
                        .foregroundColor(.vibeTextSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.vibeSurface)
                        .cornerRadius(8)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.vibeTextSecondary)
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(VibeSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Capabilities List
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(catalog.capabilities(group: group)) { capability in
                        CapabilityRow(capability: capability)
                        if capability != catalog.capabilities(group: group).last {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .padding(.leading, VibeSpacing.md)
            }
        }
    }
}

// MARK: - Capability Row

struct CapabilityRow: View {
    let capability: Capability

    var body: some View {
        Button(action: { executeCapability() }) {
            HStack(spacing: VibeSpacing.sm) {
                // Icon
                Image(systemName: capability.icon)
                    .foregroundColor(.vibeSecondary)
                    .font(.system(size: 12))
                    .frame(width: 20)

                // Title and description
                VStack(alignment: .leading, spacing: 2) {
                    Text(capability.title)
                        .font(VibeFont.body)
                        .foregroundColor(.vibeText)

                    if !capability.description.isEmpty {
                        Text(capability.description)
                            .font(VibeFont.caption)
                            .foregroundColor(.vibeTextSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Risk indicator
                Image(systemName: capability.riskClass.icon)
                    .foregroundColor(capability.riskClass.color)
                    .font(.system(size: 10))
            }
            .padding(.vertical, VibeSpacing.sm)
            .padding(.horizontal, VibeSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func executeCapability() {
        // TODO: Implement in Slice B
        print("Execute capability: \(capability.id)")
    }
}

// MARK: - Menu Footer

struct MenuFooterView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { openActivityLog() }) {
                Label("Activity Log", systemImage: "list.bullet.clipboard")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(VibeSpacing.sm)

            Divider()

            Button(action: { openPermissions() }) {
                Label("Permissions", systemImage: "lock.shield")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(VibeSpacing.sm)

            Divider()

            Button(action: { openSettings() }) {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(VibeSpacing.sm)

            Divider()

            Button(action: { quitApp() }) {
                Label("Quit Craig-O-Clean", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(VibeSpacing.sm)
        }
        .font(VibeFont.body)
        .foregroundColor(.vibeText)
    }

    private func openActivityLog() {
        // TODO: Implement in Slice B
        print("Open Activity Log")
    }

    private func openPermissions() {
        // TODO: Implement in Slice C
        print("Open Permissions")
    }

    private func openSettings() {
        // TODO: Implement
        print("Open Settings")
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Preview

#Preview {
    MenuBarContentView()
        .environment(CapabilityCatalog.shared)
        .background(Color.vibeBackground)
}
