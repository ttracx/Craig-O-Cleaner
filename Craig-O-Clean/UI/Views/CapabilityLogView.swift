// MARK: - CapabilityLogView.swift
// Craig-O-Clean - Run Log Viewer
// Displays recent capability executions with filtering and detail expansion

import SwiftUI

struct CapabilityLogView: View {
    @ObservedObject var logStore: LogStore
    @State private var filterCategory: String?
    @State private var filterSuccess: Bool?
    @State private var selectedRecord: RunRecord?
    @State private var showingExport = false

    var filteredRecords: [RunRecord] {
        var records = logStore.records
        if let cat = filterCategory {
            records = records.filter { $0.category == cat }
        }
        if let success = filterSuccess {
            records = records.filter { $0.success == success }
        }
        return records
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Run Logs")
                    .font(.headline)
                Spacer()
                Button("Export") {
                    exportLogs()
                }
                .font(.caption)
            }

            // Filters
            HStack(spacing: 8) {
                Picker("Category", selection: $filterCategory) {
                    Text("All").tag(nil as String?)
                    ForEach(CapabilityCategory.allCases, id: \.rawValue) { cat in
                        Text(cat.rawValue).tag(cat.rawValue as String?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                Picker("Status", selection: $filterSuccess) {
                    Text("All").tag(nil as Bool?)
                    Text("Success").tag(true as Bool?)
                    Text("Failed").tag(false as Bool?)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            // Records List
            if filteredRecords.isEmpty {
                Text("No run records yet.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredRecords) { record in
                            RunRecordRow(record: record, isExpanded: selectedRecord?.id == record.id, logStore: logStore)
                                .onTapGesture {
                                    withAnimation {
                                        if selectedRecord?.id == record.id {
                                            selectedRecord = nil
                                        } else {
                                            selectedRecord = record
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func exportLogs() {
        if let url = logStore.exportLogsZip() {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

// MARK: - Run Record Row

struct RunRecordRow: View {
    let record: RunRecord
    let isExpanded: Bool
    let logStore: LogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(record.success ? .green : .red)
                    .font(.caption)

                Text(record.capabilityTitle)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)

                Spacer()

                Text(record.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(record.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if isExpanded {
                expandedContent
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isExpanded ? Color.accentColor.opacity(0.05) : Color.clear)
        .cornerRadius(6)
    }

    @ViewBuilder
    var expandedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Capability ID", value: record.capabilityId)
                .font(.caption)
            LabeledContent("Category", value: record.category)
                .font(.caption)
            LabeledContent("Exit Code", value: "\(record.exitCode)")
                .font(.caption)
            LabeledContent("Privilege", value: record.privilegeLevel)
                .font(.caption)

            if let summary = record.parsedSummaryJSON {
                GroupBox("Summary") {
                    Text(summary)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if let stdout = logStore.readStdout(for: record), !stdout.isEmpty {
                GroupBox("stdout") {
                    ScrollView(.horizontal) {
                        Text(stdout.prefix(2000))
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 100)
                }
            }

            if let stderr = logStore.readStderr(for: record), !stderr.isEmpty {
                GroupBox("stderr") {
                    ScrollView(.horizontal) {
                        Text(stderr.prefix(2000))
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.red)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 80)
                }
            }

            if let hint = record.remediationHint {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(hint)
                        .font(.caption)
                }
                .padding(6)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(4)

                Button("Copy Remediation") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(hint, forType: .string)
                }
                .font(.caption)
            }
        }
        .padding(.top, 4)
    }
}
