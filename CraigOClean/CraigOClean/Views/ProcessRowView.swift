//
//  ProcessRowView.swift
//  Craig-O-Clean
//
//  View component for displaying individual process information
//

import SwiftUI

struct ProcessRowView: View {
    let process: ProcessInfo
    let onForceQuit: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon (generic)
            Image(systemName: "app.fill")
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 30, height: 30)
            
            // App info
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Text("PID: \(process.id)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Memory usage
            VStack(alignment: .trailing, spacing: 2) {
                Text(process.formattedMemory)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(memoryColor(for: process.memoryUsageMB))
                
                if isHovered {
                    Button(action: onForceQuit) {
                        Text("Force Quit")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private func memoryColor(for memoryMB: Double) -> Color {
        if memoryMB > 1024 { // > 1GB
            return .red
        } else if memoryMB > 512 { // > 512MB
            return .orange
        } else {
            return .primary
        }
    }
}
