// MARK: - AutoCleanupSettingsView.swift
// Craig-O-Clean - Auto-Cleanup Configuration View
// Configure automatic resource monitoring and cleanup thresholds

import SwiftUI

struct AutoCleanupSettingsView: View {
    @ObservedObject var autoCleanup: AutoCleanupService
    @State private var showingEventHistory = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Enable/Disable Section
                enableSection

                if autoCleanup.isEnabled {
                    // Status Section
                    statusSection

                    // Thresholds Configuration
                    thresholdsSection

                    // Statistics Section
                    statisticsSection

                    // Recent Events
                    eventsSection
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle("Auto-Cleanup")
        .sheet(isPresented: $showingEventHistory) {
            EventHistorySheet(events: autoCleanup.recentEvents)
        }
    }

    // MARK: - Enable Section

    private var enableSection: some View {
        SettingsSection(title: "Auto-Cleanup", icon: "wand.and.stars") {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Automatic Resource Management")
                            .fontWeight(.medium)
                        Text("Automatically monitor system resources and perform cleanup when thresholds are exceeded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { autoCleanup.isEnabled },
                        set: { newValue in
                            if newValue {
                                autoCleanup.enable()
                            } else {
                                autoCleanup.disable()
                            }
                        }
                    ))
                    .labelsHidden()
                }

                if autoCleanup.isEnabled {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.vibeTeal)
                        Text("Auto-cleanup is active and monitoring your system")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.vibeTeal.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        SettingsSection(title: "Status", icon: "chart.line.uptrend.xyaxis") {
            VStack(spacing: 12) {
                HStack {
                    Label("Monitoring", systemImage: autoCleanup.isMonitoring ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(autoCleanup.isMonitoring ? .vibeTeal : .secondary)
                    Spacer()
                    Text(autoCleanup.isMonitoring ? "Active" : "Inactive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                HStack {
                    Label("Last Cleanup", systemImage: "clock.arrow.circlepath")
                        .foregroundColor(.vibePurple)
                    Spacer()
                    if let lastCleanup = autoCleanup.lastCleanupTime {
                        Text(lastCleanup, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                Button {
                    Task {
                        await autoCleanup.triggerImmediateCleanup()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Trigger Immediate Cleanup")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.vibePurple)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Thresholds Section

    private var thresholdsSection: some View {
        SettingsSection(title: "Thresholds", icon: "slider.horizontal.3") {
            VStack(spacing: 20) {
                // Memory Warning Threshold
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Memory Warning", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.vibeAmber)
                        Spacer()
                        Text("\(Int(autoCleanup.thresholds.memoryWarning))%")
                            .font(.headline)
                            .foregroundColor(.vibeAmber)
                    }

                    Slider(value: Binding(
                        get: { autoCleanup.thresholds.memoryWarning },
                        set: { newValue in
                            var updated = autoCleanup.thresholds
                            updated.memoryWarning = newValue
                            autoCleanup.updateThresholds(updated)
                        }
                    ), in: 50...95, step: 5)

                    Text("Show warning when memory usage exceeds this percentage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Memory Critical Threshold
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Memory Critical", systemImage: "exclamationmark.octagon.fill")
                            .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                        Spacer()
                        Text("\(Int(autoCleanup.thresholds.memoryCritical))%")
                            .font(.headline)
                            .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                    }

                    Slider(value: Binding(
                        get: { autoCleanup.thresholds.memoryCritical },
                        set: { newValue in
                            var updated = autoCleanup.thresholds
                            updated.memoryCritical = newValue
                            autoCleanup.updateThresholds(updated)
                        }
                    ), in: 60...98, step: 5)

                    Text("Automatically purge memory and terminate processes when exceeded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // CPU Warning Threshold
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("CPU Warning", systemImage: "cpu")
                            .foregroundColor(.vibeAmber)
                        Spacer()
                        Text("\(Int(autoCleanup.thresholds.cpuWarning))%")
                            .font(.headline)
                            .foregroundColor(.vibeAmber)
                    }

                    Slider(value: Binding(
                        get: { autoCleanup.thresholds.cpuWarning },
                        set: { newValue in
                            var updated = autoCleanup.thresholds
                            updated.cpuWarning = newValue
                            autoCleanup.updateThresholds(updated)
                        }
                    ), in: 50...95, step: 5)

                    Text("Show warning when CPU usage exceeds this percentage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // CPU Critical Threshold
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("CPU Critical", systemImage: "flame.fill")
                            .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                        Spacer()
                        Text("\(Int(autoCleanup.thresholds.cpuCritical))%")
                            .font(.headline)
                            .foregroundColor(Color(red: 239/255, green: 68/255, blue: 68/255))
                    }

                    Slider(value: Binding(
                        get: { autoCleanup.thresholds.cpuCritical },
                        set: { newValue in
                            var updated = autoCleanup.thresholds
                            updated.cpuCritical = newValue
                            autoCleanup.updateThresholds(updated)
                        }
                    ), in: 60...98, step: 5)

                    Text("Automatically terminate CPU-intensive processes when exceeded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Statistics Section

    private var statisticsSection: some View {
        SettingsSection(title: "Statistics", icon: "chart.bar.fill") {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Cleanups")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(autoCleanup.totalCleanups)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.vibePurple)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Memory Freed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(autoCleanup.totalMemoryFreed), countStyle: .memory))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.vibeTeal)
                    }
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Processes Terminated")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(autoCleanup.totalProcessesTerminated)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.vibeAmber)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        SettingsSection(title: "Recent Events", icon: "list.bullet.rectangle") {
            VStack(spacing: 12) {
                if autoCleanup.recentEvents.isEmpty {
                    HStack {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No cleanup events yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Events will appear here when auto-cleanup is triggered")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                } else {
                    ForEach(autoCleanup.recentEvents.prefix(5)) { event in
                        EventRow(event: event)
                    }

                    if autoCleanup.recentEvents.count > 5 {
                        Button("View All Events (\(autoCleanup.recentEvents.count))") {
                            showingEventHistory = true
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Event Row

struct EventRow: View {
    let event: CleanupEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.action.icon)
                .font(.title2)
                .foregroundColor(.vibePurple)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.action.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(event.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    if let freed = event.memoryFreed {
                        Label(ByteCountFormatter.string(fromByteCount: Int64(freed), countStyle: .memory), systemImage: "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.vibeTeal)
                    }

                    if let terminated = event.processesTerminated {
                        Label("\(terminated) processes", systemImage: "xmark.app.fill")
                            .font(.caption2)
                            .foregroundColor(.vibeAmber)
                    }
                }
            }

            Spacer()

            Text(event.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Event History Sheet

struct EventHistorySheet: View {
    @Environment(\.dismiss) var dismiss
    let events: [CleanupEvent]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cleanup History")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.vibePurple)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Events List
            if events.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("No cleanup events")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(events) { event in
                            EventRow(event: event)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Preview

#Preview {
    AutoCleanupSettingsView(
        autoCleanup: AutoCleanupService(
            systemMetrics: SystemMetricsService(),
            memoryOptimizer: MemoryOptimizerService(),
            processManager: ProcessManager()
        )
    )
    .frame(width: 700, height: 800)
}
