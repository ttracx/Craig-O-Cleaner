// MARK: - MemoryCleanupView.swift
// CraigOClean Control Center - Memory Cleanup View
// Provides guided memory cleanup workflows and optimization suggestions

import SwiftUI
import AppKit

struct MemoryCleanupView: View {
    @EnvironmentObject var memoryOptimizer: MemoryOptimizerService
    @EnvironmentObject var systemMetrics: SystemMetricsService
    
    @State private var showingCleanupConfirmation = false
    @State private var showingPurgeConfirmation = false
    @State private var showingResult = false
    @State private var cleanupStep = 0
    @State private var lastResult: CleanupResult?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with memory status
                memoryStatusHeader
                
                // Quick actions
                quickActionsSection
                
                // Cleanup candidates
                cleanupCandidatesSection
                
                // Advanced options
                advancedOptionsSection
                
                // Last cleanup result
                if let result = lastResult {
                    lastResultSection(result)
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Memory Cleanup")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await memoryOptimizer.analyzeMemoryUsage()
                    }
                } label: {
                    Label("Analyze", systemImage: "arrow.clockwise")
                }
                .disabled(memoryOptimizer.isAnalyzing)
            }
        }
        .onAppear {
            Task {
                await memoryOptimizer.analyzeMemoryUsage()
            }
        }
        .sheet(isPresented: $showingCleanupConfirmation) {
            CleanupConfirmationSheet(
                candidates: Array(memoryOptimizer.selectedCandidates),
                onConfirm: {
                    Task {
                        let result = await memoryOptimizer.executeCleanup()
                        lastResult = result
                        showingResult = true
                    }
                }
            )
        }
        .alert("Memory Purge", isPresented: $showingPurgeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Purge Memory", role: .destructive) {
                Task {
                    let (_, message) = await memoryOptimizer.runPurgeCommand()
                    // Show result message if needed
                    print("Purge result: \(message)")
                }
            }
        } message: {
            Text("This will run the system purge command to free inactive memory. You may be prompted for your administrator password.")
        }
        .alert("Cleanup Complete", isPresented: $showingResult, presenting: lastResult) { result in
            Button("OK") { }
        } message: { result in
            Text("Terminated \(result.appsTerminated) apps and freed \(result.formattedMemoryFreed) of memory.")
        }
    }
    
    // MARK: - Memory Status Header
    
    private var memoryStatusHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Memory Status")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let memory = systemMetrics.memoryMetrics {
                        HStack(spacing: 8) {
                            PressureIndicator(level: memory.pressureLevel)
                            
                            Text(memory.pressureLevel.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Memory gauge
                if let memory = systemMetrics.memoryMetrics {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                            
                            Circle()
                                .trim(from: 0, to: memory.usedPercentage / 100)
                                .stroke(
                                    pressureColor(memory.pressureLevel),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                            
                            VStack(spacing: 2) {
                                Text("\(Int(memory.usedPercentage))%")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("Used")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 80, height: 80)
                        
                        Text("\(SystemMetricsService.formatBytes(memory.availableRAM)) free")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Memory breakdown
            if let memory = systemMetrics.memoryMetrics {
                VStack(alignment: .leading, spacing: 8) {
                    MemorySegmentBar(memory: memory)
                    
                    HStack(spacing: 16) {
                        MemoryLegendItem(color: .orange, label: "App Memory", value: SystemMetricsService.formatBytes(memory.activeRAM))
                        MemoryLegendItem(color: .red, label: "Wired", value: SystemMetricsService.formatBytes(memory.wiredRAM))
                        MemoryLegendItem(color: .purple, label: "Compressed", value: SystemMetricsService.formatBytes(memory.compressedRAM))
                        MemoryLegendItem(color: .green.opacity(0.5), label: "Free", value: SystemMetricsService.formatBytes(memory.freeRAM))
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 16) {
                QuickActionButton(
                    title: "Smart Cleanup",
                    description: "Automatically select best candidates",
                    icon: "sparkles",
                    color: .blue
                ) {
                    Task {
                        let result = await memoryOptimizer.smartCleanup()
                        lastResult = result
                        showingResult = true
                    }
                }
                
                QuickActionButton(
                    title: "Close Background",
                    description: "Terminate background apps",
                    icon: "moon.fill",
                    color: .purple
                ) {
                    Task {
                        let result = await memoryOptimizer.quickCleanupBackground()
                        lastResult = result
                        showingResult = true
                    }
                }
                
                QuickActionButton(
                    title: "Top 3 Heavy",
                    description: "Close top memory consumers",
                    icon: "memorychip.fill",
                    color: .orange
                ) {
                    Task {
                        let result = await memoryOptimizer.quickCleanupHeavy(limit: 3)
                        lastResult = result
                        showingResult = true
                    }
                }
            }
        }
    }
    
    // MARK: - Cleanup Candidates Section
    
    private var cleanupCandidatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cleanup Candidates")
                    .font(.headline)
                
                Spacer()
                
                if !memoryOptimizer.cleanupCandidates.isEmpty {
                    Text("Potential savings: \(formatBytes(memoryOptimizer.potentialMemorySavings))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if memoryOptimizer.isAnalyzing {
                HStack {
                    ProgressView()
                    Text("Analyzing memory usage...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if memoryOptimizer.cleanupCandidates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("No cleanup candidates found")
                        .font(.headline)
                    Text("Your system memory is being used efficiently")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    // Selection controls
                    HStack {
                        Button("Select All") {
                            memoryOptimizer.selectAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Deselect All") {
                            memoryOptimizer.deselectAll()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                        
                        if !memoryOptimizer.selectedCandidates.isEmpty {
                            Button("Clean Up Selected (\(memoryOptimizer.selectedCandidates.count))") {
                                showingCleanupConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    
                    Divider()
                    
                    // Candidates list grouped by category
                    ForEach(CleanupCategory.allCases, id: \.self) { category in
                        let categoryItems = memoryOptimizer.cleanupCandidates.filter { $0.category == category }
                        if !categoryItems.isEmpty {
                            CategorySection(
                                category: category,
                                items: categoryItems,
                                selectedItems: memoryOptimizer.selectedCandidates,
                                onToggle: { memoryOptimizer.toggleSelection($0) }
                            )
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Advanced Options Section
    
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced")
                .font(.headline)
            
            HStack(spacing: 16) {
                // Purge button (requires admin)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Purge Inactive Memory")
                            .font(.headline)
                    }
                    
                    Text("Forces the system to free inactive memory. Requires administrator password. Use with caution.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Run Purge Command") {
                        showingPurgeConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(!memoryOptimizer.isPurgeAvailable())
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Last Result Section
    
    private func lastResultSection(_ result: CleanupResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Cleanup")
                .font(.headline)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps Terminated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(result.appsTerminated)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Memory Freed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.formattedMemoryFreed)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(result.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                if result.success {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.yellow)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    
    private func pressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - Supporting Views

struct PressureIndicator: View {
    let level: MemoryPressureLevel
    
    var color: Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(level.rawValue)
                .font(.headline)
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(20)
    }
}

struct MemorySegmentBar: View {
    let memory: MemoryMetrics
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: segmentWidth(for: memory.activeRAM, in: geometry))
                
                Rectangle()
                    .fill(Color.red)
                    .frame(width: segmentWidth(for: memory.wiredRAM, in: geometry))
                
                Rectangle()
                    .fill(Color.purple)
                    .frame(width: segmentWidth(for: memory.compressedRAM, in: geometry))
                
                Rectangle()
                    .fill(Color.green.opacity(0.5))
            }
            .cornerRadius(6)
        }
        .frame(height: 12)
    }
    
    private func segmentWidth(for bytes: UInt64, in geometry: GeometryProxy) -> CGFloat {
        let percentage = Double(bytes) / Double(memory.totalRAM)
        return max(0, geometry.size.width * CGFloat(percentage) - 2)
    }
}

struct MemoryLegendItem: View {
    let color: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(isHovered ? color.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? color.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct CategorySection: View {
    let category: CleanupCategory
    let items: [CleanupCandidate]
    let selectedItems: Set<CleanupCandidate>
    let onToggle: (CleanupCandidate) -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.accentColor)
                    
                    Text(category.rawValue)
                        .font(.headline)
                    
                    Text("(\(items.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                ForEach(items) { item in
                    Divider()
                    
                    CleanupCandidateRow(
                        candidate: item,
                        isSelected: selectedItems.contains(item),
                        onToggle: { onToggle(item) }
                    )
                }
            }
        }
    }
}

struct CleanupCandidateRow: View {
    let candidate: CleanupCandidate
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .onTapGesture { onToggle() }
            
            // Icon
            if let icon = candidate.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "app")
                    .frame(width: 28, height: 28)
            }
            
            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .lineLimit(1)
                
                if candidate.isBackgroundApp {
                    Text("Background")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Memory
            Text(candidate.formattedMemoryUsage)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.orange)
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }
}

struct CleanupConfirmationSheet: View {
    let candidates: [CleanupCandidate]
    let onConfirm: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var totalMemory: Int64 {
        candidates.reduce(0) { $0 + $1.memoryUsage }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.yellow)
                
                Text("Confirm Cleanup")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("The following \(candidates.count) apps will be terminated:")
                    .foregroundColor(.secondary)
            }
            .padding()
            
            Divider()
            
            // App list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(candidates) { candidate in
                        HStack {
                            if let icon = candidate.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }
                            Text(candidate.name)
                            Spacer()
                            Text(candidate.formattedMemoryUsage)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 300)
            
            Divider()
            
            // Footer
            HStack {
                VStack(alignment: .leading) {
                    Text("Estimated memory freed:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatBytes(totalMemory))
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Terminate Apps") {
                    dismiss()
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 450, height: 500)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1024.0 / 1024.0
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

// MARK: - Preview

#Preview {
    MemoryCleanupView()
        .environmentObject(MemoryOptimizerService())
        .environmentObject(SystemMetricsService())
        .frame(width: 800, height: 700)
}
