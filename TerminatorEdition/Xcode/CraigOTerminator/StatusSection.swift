//
//  StatusSection.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import SwiftUI

// MARK: - Status Section

/// Displays system status information in the menu bar
struct StatusSection: View {
    // Mock data for now - will be replaced with real data in Slice B
    @State private var cpuUsage: Double = 23.0
    @State private var memoryPressure: String = "Normal"
    @State private var diskFreeGB: Int = 234

    var body: some View {
        VStack(alignment: .leading, spacing: VibeSpacing.sm) {
            Label {
                HStack {
                    Text("CPU:")
                        .foregroundColor(.vibeTextSecondary)
                    Text("\(Int(cpuUsage))%")
                        .foregroundColor(cpuColor)
                        .fontWeight(.semibold)
                }
                .font(VibeFont.body)
            } icon: {
                Image(systemName: "cpu")
                    .foregroundColor(.vibePrimary)
            }

            Label {
                HStack {
                    Text("Memory:")
                        .foregroundColor(.vibeTextSecondary)
                    Text(memoryPressure)
                        .foregroundColor(memoryColor)
                        .fontWeight(.semibold)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(memoryColor)
                        .font(.system(size: 10))
                }
                .font(VibeFont.body)
            } icon: {
                Image(systemName: "memorychip")
                    .foregroundColor(.vibeSecondary)
            }

            Label {
                HStack {
                    Text("Disk:")
                        .foregroundColor(.vibeTextSecondary)
                    Text("\(diskFreeGB) GB free")
                        .foregroundColor(diskColor)
                        .fontWeight(.semibold)
                }
                .font(VibeFont.body)
            } icon: {
                Image(systemName: "internaldrive")
                    .foregroundColor(.vibeAccent)
            }
        }
        .padding(VibeSpacing.md)
    }

    // MARK: - Computed Properties

    private var cpuColor: Color {
        if cpuUsage > 80 {
            return .vibeError
        } else if cpuUsage > 50 {
            return .vibeWarning
        } else {
            return .vibeSuccess
        }
    }

    private var memoryColor: Color {
        switch memoryPressure.lowercased() {
        case "critical": return .vibeError
        case "warn", "warning": return .vibeWarning
        default: return .vibeSuccess
        }
    }

    private var diskColor: Color {
        if diskFreeGB < 20 {
            return .vibeError
        } else if diskFreeGB < 50 {
            return .vibeWarning
        } else {
            return .vibeSuccess
        }
    }
}

// MARK: - Preview

#Preview {
    StatusSection()
        .frame(width: 300)
        .padding()
        .background(Color.vibeBackground)
}
