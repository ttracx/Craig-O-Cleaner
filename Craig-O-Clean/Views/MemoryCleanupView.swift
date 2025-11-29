// MemoryCleanupView.swift
// ClearMind Control Center
//
// Guided memory cleanup workflow with app recommendations
// Multi-step confirmation process for safe memory optimization

import SwiftUI

struct MemoryCleanupView: View {
    @StateObject private var optimizer = MemoryOptimizerService()
    @StateObject private var metricsService = SystemMetricsService()
    @State private var showPurgeWarning = false
    @State private var isPurging = false
    @State private var purgeError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Memory status header
            memoryStatusHeader
            
            Divider()
            
            // Main content based on current step
            Group {
                switch optimizer.currentStep {
                case .analyze:
                    analyzeStepView
                case .review:
                    reviewStepView
                case .confirm:
                    confirmStepView
                case .execute:
                    executeStepView
                case .complete:
                    completeStepView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Memory Status Header
    
    private var memoryStatusHeader: some View {
        HStack(spacing: 20) {
            // Memory usage gauge
            if let memory = metricsService.memoryMetrics {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(memory.usedPercentage / 100))
                            .stroke(
                                memoryGradient,
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f%%", memory.usedPercentage))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Used")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Memory details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: memory.memoryPressure.icon)
                            .foregroundColor(pressureColor)
                        Text("Memory Pressure: \(memory.memoryPressure.rawValue)")
                            .font(.headline)
                            .foregroundColor(pressureColor)
                    }
                    
                    Text("\(memory.usedFormatted) used of \(memory.totalFormatted)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        MemoryStatView(label: "Active", value: memory.activeFormatted)
                        MemoryStatView(label: "Wired", value: memory.wiredFormatted)
                        MemoryStatView(label: "Compressed", value: memory.compressedFormatted)
                    }
                }
                
                Spacer()
                
                // Quick actions
                VStack(spacing: 8) {
                    Button {
                        Task {
                            await optimizer.analyzeForCleanup()
                        }
                    } label: {
                        Label("Analyze Apps", systemImage: "magnifyingglass")
                            .frame(width: 140)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(optimizer.isProcessing)
                    
                    Button {
                        showPurgeWarning = true
                    } label: {
                        Label("Purge Memory", systemImage: "bolt")
                            .frame(width: 140)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isPurging)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .alert("Purge Memory Cache", isPresented: $showPurgeWarning) {
            Button("Purge", role: .destructive) {
                Task {
                    await runPurge()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear inactive memory cache. It requires administrator privileges and may briefly slow your system. This is generally safe but not necessary for normal use.")
        }
        .alert("Purge Error", isPresented: .init(
            get: { purgeError != nil },
            set: { if !$0 { purgeError = nil } }
        )) {
            Button("OK") { purgeError = nil }
        } message: {
            if let error = purgeError {
                Text(error)
            }
        }
    }
    
    // MARK: - Analyze Step
    
    private var analyzeStepView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "memorychip")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            Text("Memory Cleanup")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Analyze running applications and free up memory safely")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "magnifyingglass", text: "Identifies memory-heavy applications")
                FeatureRow(icon: "hand.raised", text: "Safe, guided cleanup process")
                FeatureRow(icon: "checkmark.shield", text: "You control what gets closed")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            Button {
                Task {
                    await optimizer.analyzeForCleanup()
                }
            } label: {
                Label("Start Analysis", systemImage: "play.fill")
                    .font(.headline)
                    .frame(width: 200, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Review Step
    
    private var reviewStepView: some View {
        VStack(spacing: 0) {
            // Step indicator
            StepIndicator(currentStep: 1, totalSteps: 3, title: "Review Suggestions")
                .padding()
            
            Divider()
            
            // Suggestions list
            HSplitView {
                // App list
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Applications (\(optimizer.cleanupCandidates.count))")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Select All") {
                            optimizer.selectAll()
                        }
                        .buttonStyle(.link)
                        
                        Button("Deselect All") {
                            optimizer.deselectAll()
                        }
                        .buttonStyle(.link)
                    }
                    .padding()
                    
                    // List
                    List {
                        ForEach(optimizer.cleanupCandidates) { candidate in
                            CleanupCandidateRow(
                                candidate: candidate,
                                isSelected: optimizer.selectedForCleanup.contains(candidate.id),
                                suggestion: optimizer.suggestions.first { $0.candidate.id == candidate.id }
                            ) {
                                optimizer.toggleSelection(candidate)
                            }
                        }
                    }
                    .listStyle(.inset)
                }
                .frame(minWidth: 400)
                
                // Summary panel
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cleanup Summary")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        SummaryRow(label: "Total Apps", value: "\(optimizer.cleanupCandidates.count)")
                        SummaryRow(label: "Selected", value: "\(optimizer.selectedCount)")
                        SummaryRow(label: "Suggestions", value: "\(optimizer.suggestionCount)")
                        
                        Divider()
                        
                        SummaryRow(
                            label: "Estimated Memory",
                            value: optimizer.estimatedMemoryFormatted,
                            isHighlighted: true
                        )
                    }
                    
                    Spacer()
                    
                    // Suggestions info
                    if !optimizer.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Why These Apps?")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(Set(optimizer.suggestions.map { $0.reason.rawValue })), id: \.self) { reason in
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text(reason)
                                        .font(.caption)
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    HStack {
                        Button("Reset") {
                            optimizer.reset()
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button("Continue") {
                            optimizer.proceedToConfirm()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(optimizer.selectedForCleanup.isEmpty)
                    }
                }
                .padding()
                .frame(width: 280)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }
    
    // MARK: - Confirm Step
    
    private var confirmStepView: some View {
        VStack(spacing: 0) {
            // Step indicator
            StepIndicator(currentStep: 2, totalSteps: 3, title: "Confirm Cleanup")
                .padding()
            
            Divider()
            
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                Text("Ready to Clean Up")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("The following applications will be closed:")
                    .foregroundColor(.secondary)
                
                // Selected apps summary
                VStack(spacing: 8) {
                    ForEach(selectedApps.prefix(5)) { candidate in
                        HStack {
                            if let icon = candidate.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }
                            Text(candidate.name)
                            Spacer()
                            Text(candidate.memoryFormatted)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if selectedApps.count > 5 {
                        Text("and \(selectedApps.count - 5) more...")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .frame(maxWidth: 400)
                
                // Memory estimate
                HStack {
                    Text("Estimated memory freed:")
                    Text(optimizer.estimatedMemoryFormatted)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                // Warning
                Text("Unsaved work in these applications may be lost.")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Back") {
                        optimizer.backToReview()
                    }
                    .buttonStyle(.bordered)
                    .frame(width: 100)
                    
                    Button {
                        Task {
                            _ = await optimizer.executeCleanup()
                        }
                    } label: {
                        Label("Clean Up Now", systemImage: "trash")
                            .frame(width: 150)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Execute Step
    
    private var executeStepView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(2)
            
            Text("Cleaning Up...")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Closing selected applications")
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Complete Step
    
    private var completeStepView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if let result = optimizer.lastResult {
                if result.success {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)
                    
                    Text("Cleanup Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                    
                    Text("Cleanup Completed with Warnings")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                // Stats
                VStack(spacing: 12) {
                    ResultRow(label: "Apps Closed", value: "\(result.appsTerminated)")
                    ResultRow(label: "Memory Freed", value: result.freedMemoryFormatted, isHighlighted: true)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // Errors
                if !result.errors.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Some apps could not be closed:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        ForEach(result.errors, id: \.self) { error in
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Button("Done") {
                optimizer.reset()
            }
            .buttonStyle(.borderedProminent)
            .frame(width: 100)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Views & Properties
    
    private var selectedApps: [CleanupCandidate] {
        optimizer.cleanupCandidates.filter { optimizer.selectedForCleanup.contains($0.id) }
    }
    
    private var memoryGradient: AngularGradient {
        AngularGradient(
            colors: [.green, .yellow, .orange, .red, .red],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * (metricsService.memoryMetrics?.usedPercentage ?? 0) / 100)
        )
    }
    
    private var pressureColor: Color {
        guard let memory = metricsService.memoryMetrics else { return .gray }
        switch memory.memoryPressure {
        case .normal: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    // MARK: - Actions
    
    private func runPurge() async {
        isPurging = true
        do {
            try await optimizer.runPurge()
            metricsService.updateAllMetrics()
        } catch {
            purgeError = error.localizedDescription
        }
        isPurging = false
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}

struct MemoryStatView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct StepIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    let title: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ForEach(1...totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    if step < totalSteps {
                        Rectangle()
                            .fill(step < currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .frame(maxWidth: 200)
            
            Text(title)
                .font(.headline)
        }
    }
}

struct CleanupCandidateRow: View {
    let candidate: CleanupCandidate
    let isSelected: Bool
    let suggestion: CleanupSuggestion?
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                onToggle()
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            
            // App icon
            if let icon = candidate.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app")
                    .font(.title)
                    .frame(width: 32, height: 32)
            }
            
            // App info
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .fontWeight(.medium)
                
                if let suggestion = suggestion {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(priorityColor(suggestion.priority))
                            .frame(width: 6, height: 6)
                        Text(suggestion.reason.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Memory usage
            Text(candidate.memoryFormatted)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func priorityColor(_ priority: CleanupPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(isHighlighted ? .bold : .regular)
                .foregroundColor(isHighlighted ? .green : .primary)
        }
    }
}

struct ResultRow: View {
    let label: String
    let value: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .foregroundColor(isHighlighted ? .green : .primary)
        }
    }
}

#Preview {
    MemoryCleanupView()
        .frame(width: 900, height: 700)
}
