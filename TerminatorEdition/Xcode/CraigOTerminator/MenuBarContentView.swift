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
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon with glow effect
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.vibePrimary.opacity(0.2),
                                Color.vibePrimary.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .blur(radius: 4)

                Image(systemName: "paintbrush.pointed.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.vibePrimary, .vibeSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .vibePrimary.opacity(0.3), radius: 3, x: 0, y: 2)
            }

            Text("Craig-O-Clean")
                .font(VibeFont.title)
                .foregroundColor(.vibeText)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 0.5)

            Spacer()

            // Enhanced version badge
            Text("v1.0")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.vibePrimary, .vibeSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: .vibePrimary.opacity(0.3), radius: 3, x: 0, y: 2)
        }
        .padding(VibeSpacing.md)
        .background(
            Rectangle()
                .fill(Color.clear)
        )
    }
}

// MARK: - Capability Group Section

struct CapabilityGroupSection: View {
    let group: CapabilityGroup
    @Environment(CapabilityCatalog.self) private var catalog
    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Group Header
            Button(action: {
                // Haptic feedback on expand/collapse
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: group.icon)
                        .foregroundColor(.vibePrimary)
                        .font(.system(size: 14, weight: .semibold))

                    Text(group.displayTitle)
                        .font(VibeFont.headline)
                        .foregroundColor(.vibeText)

                    Spacer()

                    Text("\(catalog.count(for: group))")
                        .font(VibeFont.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.vibePrimary.opacity(0.7))
                        )

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.vibeTextSecondary)
                        .font(.system(size: 10, weight: .semibold))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .animation(.spring(response: 0.3), value: isExpanded)
                }
                .padding(VibeSpacing.md)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.vibePrimary.opacity(isHovered ? 0.05 : 0))
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }

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
    @State private var isHovered: Bool = false
    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: { executeCapability() }) {
            HStack(spacing: VibeSpacing.sm) {
                // Icon with circle background
                ZStack {
                    Circle()
                        .fill(capability.riskClass.color.opacity(0.15))
                        .frame(width: 28, height: 28)

                    Image(systemName: capability.icon)
                        .foregroundColor(capability.riskClass.color)
                        .font(.system(size: 12, weight: .semibold))
                }

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

                // Risk indicator with enhanced styling
                HStack(spacing: 4) {
                    Image(systemName: capability.riskClass.icon)
                        .foregroundColor(capability.riskClass.color)
                        .font(.system(size: 10, weight: .semibold))

                    Text(capability.riskClass.rawValue.capitalized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(capability.riskClass.color)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(capability.riskClass.color.opacity(0.1))
                )
            }
            .padding(.vertical, VibeSpacing.sm)
            .padding(.horizontal, VibeSpacing.md)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.vibePrimary.opacity(isHovered ? 0.05 : 0))
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(capability.description)
    }

    private func executeCapability() {
        // Haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        // Press animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            isPressed = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring()) {
                isPressed = false
            }
        }

        // TODO: Implement in Slice B
        print("Execute capability: \(capability.id)")
    }
}

// MARK: - Menu Footer

struct MenuFooterView: View {
    @State private var hoveredItem: String?

    var body: some View {
        VStack(spacing: 0) {
            MenuFooterButton(
                title: "Activity Log",
                icon: "list.bullet.clipboard",
                isHovered: hoveredItem == "activity"
            ) {
                openActivityLog()
            }
            .onHover { hovering in
                hoveredItem = hovering ? "activity" : nil
            }

            Divider()

            MenuFooterButton(
                title: "Permissions",
                icon: "lock.shield",
                isHovered: hoveredItem == "permissions"
            ) {
                openPermissions()
            }
            .onHover { hovering in
                hoveredItem = hovering ? "permissions" : nil
            }

            Divider()

            MenuFooterButton(
                title: "Settings",
                icon: "gearshape",
                isHovered: hoveredItem == "settings"
            ) {
                openSettings()
            }
            .onHover { hovering in
                hoveredItem = hovering ? "settings" : nil
            }

            Divider()

            MenuFooterButton(
                title: "Quit Craig-O-Clean",
                icon: "power",
                isHovered: hoveredItem == "quit"
            ) {
                quitApp()
            }
            .onHover { hovering in
                hoveredItem = hovering ? "quit" : nil
            }
        }
    }

    private func openActivityLog() {
        // TODO: Implement in Slice B
        print("Open Activity Log")
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func openPermissions() {
        // TODO: Implement in Slice C
        print("Open Permissions")
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func openSettings() {
        // TODO: Implement
        print("Open Settings")
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func quitApp() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Menu Footer Button

struct MenuFooterButton: View {
    let title: String
    let icon: String
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VibeSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.vibePrimary)
                    .frame(width: 20)

                Text(title)
                    .font(VibeFont.body)
                    .foregroundColor(.vibeText)

                Spacer()
            }
            .padding(.horizontal, VibeSpacing.md)
            .padding(.vertical, VibeSpacing.sm)
            .contentShape(Rectangle())
            .background(
                Rectangle()
                    .fill(Color.vibePrimary.opacity(isHovered ? 0.1 : 0))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    MenuBarContentView()
        .environment(CapabilityCatalog.shared)
        .background(Color.vibeBackground)
}
