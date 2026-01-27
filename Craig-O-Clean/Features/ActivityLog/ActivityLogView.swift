// MARK: - ActivityLogView.swift
// Craig-O-Clean - Activity Log UI
// Shows run history with status, duration, and expandable details

import SwiftUI

struct ActivityLogView: View {
    @State private var records: [RunRecord] = []
    @State private var isLoading = true
    @State private var selectedRecord: RunRecord?
    @State private var showExportSheet = false

    private let logStore: LogStore = SQLiteLogStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Activity Log")
                    .font(.headline)
                Spacer()
                Button(action: { showExportSheet = true }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: { Task { await loadRecords() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if isLoading {
                ProgressView()
                    .padding(40)
            } else if records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No activity yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Run a capability to see activity here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List(records) { record in
                    RunRecordRow(record: record)
                        .onTapGesture { selectedRecord = record }
                }
                .listStyle(.inset)
            }
        }
        .task { await loadRecords() }
        .sheet(item: $selectedRecord) { record in
            RunRecordDetailView(record: record)
        }
    }

    private func loadRecords() async {
        isLoading = true
        do {
            records = try await logStore.fetch(limit: 100, offset: 0)
        } catch {
            records = []
        }
        isLoading = false
    }
}

// MARK: - Run Record Row

struct RunRecordRow: View {
    let record: RunRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.statusIcon)
                .font(.title3)
                .foregroundColor(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.capabilityTitle)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Text(record.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(record.durationFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(record.status.rawValue)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch record.status {
        case .success: return .green
        case .partialSuccess: return .orange
        case .failed: return .red
        case .cancelled: return .gray
        case .permissionDenied: return .yellow
        case .timeout: return .orange
        }
    }
}

// MARK: - Run Record Detail

struct RunRecordDetailView: View {
    let record: RunRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: record.statusIcon)
                    .font(.title2)
                Text(record.capabilityTitle)
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }

            Divider()

            Grid(alignment: .leading, verticalSpacing: 8) {
                GridRow {
                    Text("Capability:").fontWeight(.medium)
                    Text(record.capabilityId).font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("Status:").fontWeight(.medium)
                    Text(record.status.rawValue.capitalized)
                }
                GridRow {
                    Text("Exit Code:").fontWeight(.medium)
                    Text("\(record.exitCode)")
                }
                GridRow {
                    Text("Duration:").fontWeight(.medium)
                    Text(record.durationFormatted)
                }
                GridRow {
                    Text("Privilege:").fontWeight(.medium)
                    Text(record.privilegeLevel.rawValue.capitalized)
                }
                GridRow {
                    Text("Timestamp:").fontWeight(.medium)
                    Text(record.timestamp, format: .dateTime)
                }
                GridRow {
                    Text("Output Size:").fontWeight(.medium)
                    Text(ByteCountFormatter.string(fromByteCount: Int64(record.outputSizeBytes), countStyle: .file))
                }
            }

            if let stdout = record.stdoutPreview, !stdout.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Output:")
                        .fontWeight(.medium)
                    ScrollView {
                        Text(stdout)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                }
            }

            if let stderr = record.stderrPreview, !stderr.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Errors:")
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                    ScrollView {
                        Text(stderr)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                    .padding(8)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(6)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 500, minHeight: 400)
    }
}
