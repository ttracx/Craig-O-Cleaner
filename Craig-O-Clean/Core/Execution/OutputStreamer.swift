// MARK: - OutputStreamer.swift
// Craig-O-Clean - Live Output Streaming
// Provides an observable stream of process output for UI display

import Foundation
import Combine

@MainActor
final class OutputStreamer: ObservableObject {

    @Published private(set) var lines: [OutputLine] = []
    @Published private(set) var isStreaming = false

    struct OutputLine: Identifiable {
        let id = UUID()
        let text: String
        let isError: Bool
        let timestamp: Date

        init(_ text: String, isError: Bool = false) {
            self.text = text
            self.isError = isError
            self.timestamp = Date()
        }
    }

    private let maxLines = 500

    func appendStdout(_ text: String) {
        let newLines = text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { OutputLine($0) }
        lines.append(contentsOf: newLines)
        trimIfNeeded()
    }

    func appendStderr(_ text: String) {
        let newLines = text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { OutputLine($0, isError: true) }
        lines.append(contentsOf: newLines)
        trimIfNeeded()
    }

    func clear() {
        lines.removeAll()
    }

    func startStreaming() {
        isStreaming = true
        clear()
    }

    func stopStreaming() {
        isStreaming = false
    }

    private func trimIfNeeded() {
        if lines.count > maxLines {
            lines = Array(lines.suffix(maxLines))
        }
    }

    /// Full output as a single string
    var fullOutput: String {
        lines.map { $0.text }.joined(separator: "\n")
    }

    /// Error output only
    var errorOutput: String {
        lines.filter { $0.isError }.map { $0.text }.joined(separator: "\n")
    }
}
