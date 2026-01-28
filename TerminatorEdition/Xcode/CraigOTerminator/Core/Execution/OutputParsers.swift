//
//  OutputParsers.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import Foundation
import os.log

// MARK: - Parsed Output Types

enum ParsedOutput: Codable {
    case text(String)
    case json([String: AnyCodable])
    case regex(captures: [String])
    case table(headers: [String], rows: [[String]])
    case memoryPressure(MemoryPressureInfo)
    case diskUsage([DiskUsageEntry])
    case processTable([ProcessInfo])

    // Custom coding for JSON dictionary
    enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let value):
            try container.encode("text", forKey: .type)
            try container.encode(value, forKey: .value)
        case .json(let value):
            try container.encode("json", forKey: .type)
            try container.encode(value, forKey: .value)
        case .regex(let captures):
            try container.encode("regex", forKey: .type)
            try container.encode(captures, forKey: .value)
        case .table(let headers, let rows):
            try container.encode("table", forKey: .type)
            struct TableData: Codable {
                let headers: [String]
                let rows: [[String]]
            }
            try container.encode(TableData(headers: headers, rows: rows), forKey: .value)
        case .memoryPressure(let info):
            try container.encode("memoryPressure", forKey: .type)
            try container.encode(info, forKey: .value)
        case .diskUsage(let entries):
            try container.encode("diskUsage", forKey: .type)
            try container.encode(entries, forKey: .value)
        case .processTable(let processes):
            try container.encode("processTable", forKey: .type)
            try container.encode(processes, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case "json":
            let value = try container.decode([String: AnyCodable].self, forKey: .value)
            self = .json(value)
        case "regex":
            let value = try container.decode([String].self, forKey: .value)
            self = .regex(captures: value)
        case "table":
            let dict = try container.decode([String: AnyCodable].self, forKey: .value)
            guard let headers = dict["headers"]?.value as? [String],
                  let rows = dict["rows"]?.value as? [[String]] else {
                throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Invalid table data")
            }
            self = .table(headers: headers, rows: rows)
        case "memoryPressure":
            let value = try container.decode(MemoryPressureInfo.self, forKey: .value)
            self = .memoryPressure(value)
        case "diskUsage":
            let value = try container.decode([DiskUsageEntry].self, forKey: .value)
            self = .diskUsage(value)
        case "processTable":
            let value = try container.decode([ProcessInfo].self, forKey: .value)
            self = .processTable(value)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown type: \(type)")
        }
    }
}

// Helper for encoding/decoding Any values in JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Memory Pressure Info

struct MemoryPressureInfo: Codable {
    let level: String  // "normal", "warn", "critical"
    let availableBytes: Int64
    let pagesAvailable: Int
    let freePercentage: Double?
}

// MARK: - Disk Usage Entry

struct DiskUsageEntry: Codable {
    let filesystem: String?
    let size: String
    let used: String
    let available: String
    let capacity: String
    let mountPoint: String?
    let path: String?  // For du output
}

// MARK: - Process Info

struct ProcessInfo: Codable {
    let pid: Int
    let user: String
    let cpuPercent: Double
    let memPercent: Double
    let vsz: Int
    let rss: Int
    let tt: String
    let stat: String
    let started: String
    let time: String
    let command: String
}

// MARK: - Output Parser Protocol

protocol OutputParserProtocol {
    func parse(_ output: String, pattern: String?) -> ParsedOutput?
}

// MARK: - Text Parser

final class TextParser: OutputParserProtocol {
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "TextParser")

    func parse(_ output: String, pattern: String?) -> ParsedOutput? {
        logger.debug("Parsing as text, length: \(output.count)")
        return .text(output)
    }
}

// MARK: - JSON Parser

final class JSONParser: OutputParserProtocol {
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "JSONParser")

    func parse(_ output: String, pattern: String?) -> ParsedOutput? {
        logger.debug("Parsing as JSON")

        guard let data = output.data(using: .utf8) else {
            logger.error("Failed to convert output to data")
            return nil
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            if let dict = json as? [String: Any] {
                let codableDict = dict.mapValues { AnyCodable($0) }
                return .json(codableDict)
            } else {
                logger.error("JSON root is not a dictionary")
                return nil
            }
        } catch {
            logger.error("Failed to parse JSON: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Regex Parser

final class RegexParser: OutputParserProtocol {
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "RegexParser")

    func parse(_ output: String, pattern: String?) -> ParsedOutput? {
        guard let pattern = pattern else {
            logger.error("No regex pattern provided")
            return nil
        }

        logger.debug("Parsing with regex: \(pattern)")

        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(output.startIndex..., in: output)

            guard let match = regex.firstMatch(in: output, options: [], range: range) else {
                logger.warning("No regex match found")
                return .regex(captures: [])
            }

            var captures: [String] = []
            for i in 0..<match.numberOfRanges {
                let matchRange = match.range(at: i)
                if matchRange.location != NSNotFound,
                   let range = Range(matchRange, in: output) {
                    captures.append(String(output[range]))
                }
            }

            logger.debug("Found \(captures.count) captures")
            return .regex(captures: captures)

        } catch {
            logger.error("Invalid regex pattern: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Table Parser

final class TableParser: OutputParserProtocol {
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "TableParser")

    func parse(_ output: String, pattern: String?) -> ParsedOutput? {
        logger.debug("Parsing as table")

        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            logger.warning("No lines to parse")
            return .table(headers: [], rows: [])
        }

        // First line is headers
        let headers = lines[0].split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }

        // Remaining lines are rows
        var rows: [[String]] = []
        for line in lines.dropFirst() {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
                .map { String($0) }
            if !columns.isEmpty {
                rows.append(columns)
            }
        }

        logger.debug("Parsed table: \(headers.count) columns, \(rows.count) rows")
        return .table(headers: headers, rows: rows)
    }
}

// MARK: - Memory Pressure Parser

final class MemoryPressureParser: OutputParserProtocol {
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "MemoryPressureParser")

    func parse(_ output: String, pattern: String?) -> ParsedOutput? {
        logger.debug("Parsing memory_pressure output")

        var level = "unknown"
        var availableBytes: Int64 = 0
        var pagesAvailable = 0
        var freePercentage: Double?

        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Parse status line: "System-wide memory free percentage: 45%"
            if trimmed.contains("memory free percentage") {
                if let percentMatch = trimmed.range(of: #"(\d+)%"#, options: .regularExpression) {
                    let percentStr = trimmed[percentMatch].dropLast()  // Remove %
                    freePercentage = Double(percentStr)
                }

                // Determine level based on percentage
                if let percent = freePercentage {
                    if percent >= 50 {
                        level = "normal"
                    } else if percent >= 20 {
                        level = "warn"
                    } else {
                        level = "critical"
                    }
                }
            }

            // Parse available memory: "Available memory: 12.5 GB"
            if trimmed.contains("Available memory") {
                if let gbMatch = trimmed.range(of: #"(\d+\.?\d*)\s*GB"#, options: .regularExpression) {
                    let gbStr = trimmed[gbMatch].components(separatedBy: .whitespaces)[0]
                    if let gb = Double(gbStr) {
                        availableBytes = Int64(gb * 1024 * 1024 * 1024)
                    }
                } else if let mbMatch = trimmed.range(of: #"(\d+\.?\d*)\s*MB"#, options: .regularExpression) {
                    let mbStr = trimmed[mbMatch].components(separatedBy: .whitespaces)[0]
                    if let mb = Double(mbStr) {
                        availableBytes = Int64(mb * 1024 * 1024)
                    }
                }
            }

            // Parse pages: "Pages free: 12345"
            if trimmed.contains("Pages free") {
                let components = trimmed.components(separatedBy: .whitespaces)
                if let lastComponent = components.last,
                   let pages = Int(lastComponent) {
                    pagesAvailable = pages
                }
            }
        }

        logger.debug("Memory pressure: level=\(level), available=\(availableBytes) bytes")

        return .memoryPressure(MemoryPressureInfo(
            level: level,
            availableBytes: availableBytes,
            pagesAvailable: pagesAvailable,
            freePercentage: freePercentage
        ))
    }
}

// MARK: - Disk Usage Parser

final class DiskUsageParser: OutputParserProtocol {
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "DiskUsageParser")

    func parse(_ output: String, pattern: String?) -> ParsedOutput? {
        logger.debug("Parsing disk usage output")

        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            logger.warning("Insufficient lines for df output")
            return .diskUsage([])
        }

        var entries: [DiskUsageEntry] = []

        // Check if this is df output (has header line) or du output (no header)
        let isDfOutput = lines[0].contains("Filesystem")

        if isDfOutput {
            // Parse df output
            for line in lines.dropFirst() {
                if let entry = parseDfLine(line) {
                    entries.append(entry)
                }
            }
        } else {
            // Parse du output: "1234567  /path/to/directory"
            for line in lines {
                if let entry = parseDuLine(line) {
                    entries.append(entry)
                }
            }
        }

        logger.debug("Parsed \(entries.count) disk usage entries")
        return .diskUsage(entries)
    }

    private func parseDfLine(_ line: String) -> DiskUsageEntry? {
        // Expected format: /dev/disk3s1  932Gi  234Gi  234Gi  51%  12345678 234567  34%  /
        let components = line.split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }

        guard components.count >= 6 else { return nil }

        let filesystem = components[0]
        let size = components[1]
        let used = components[2]
        let available = components[3]
        let capacity = components[4]
        let mountPoint = components.count > 8 ? components[8] : components.last

        return DiskUsageEntry(
            filesystem: filesystem,
            size: size,
            used: used,
            available: available,
            capacity: capacity,
            mountPoint: mountPoint,
            path: nil
        )
    }

    private func parseDuLine(_ line: String) -> DiskUsageEntry? {
        // Expected format: "1234567  /path/to/directory"
        let components = line.split(separator: "\t", omittingEmptySubsequences: true)
            .map { String($0) }

        guard components.count >= 2 else { return nil }

        let sizeKB = components[0]
        let path = components[1]

        // Convert KB to human readable
        let sizeBytes = Int64(sizeKB) ?? 0
        let humanSize = ByteCountFormatter.string(fromByteCount: sizeBytes * 1024, countStyle: .file)

        return DiskUsageEntry(
            filesystem: nil,
            size: humanSize,
            used: humanSize,
            available: "-",
            capacity: "-",
            mountPoint: nil,
            path: path
        )
    }
}

// MARK: - Process Table Parser

final class ProcessTableParser: OutputParserProtocol {
    private let logger = Logger(subsystem: "com.neuralquantum.craigoclean", category: "ProcessTableParser")

    func parse(_ output: String, pattern: String?) -> ParsedOutput? {
        logger.debug("Parsing process table (ps aux)")

        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            logger.warning("Insufficient lines for ps aux output")
            return .processTable([])
        }

        var processes: [ProcessInfo] = []

        // Skip header line
        for line in lines.dropFirst() {
            if let process = parseProcessLine(line) {
                processes.append(process)
            }
        }

        logger.debug("Parsed \(processes.count) processes")
        return .processTable(processes)
    }

    private func parseProcessLine(_ line: String) -> ProcessInfo? {
        // Expected format: USER PID %CPU %MEM VSZ RSS TT STAT STARTED TIME COMMAND
        // Example: root 123 0.5 1.2 1234567 89012 ?? Ss 1Jan26 0:01.23 /usr/sbin/mDNSResponder

        let components = line.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
            .map { String($0) }

        guard components.count >= 11 else { return nil }

        guard let pid = Int(components[1]),
              let cpuPercent = Double(components[2]),
              let memPercent = Double(components[3]),
              let vsz = Int(components[4]),
              let rss = Int(components[5]) else {
            return nil
        }

        return ProcessInfo(
            pid: pid,
            user: components[0],
            cpuPercent: cpuPercent,
            memPercent: memPercent,
            vsz: vsz,
            rss: rss,
            tt: components[6],
            stat: components[7],
            started: components[8],
            time: components[9],
            command: components[10]
        )
    }
}

// MARK: - Output Parser Factory

final class OutputParserFactory {
    private static let textParser = TextParser()
    private static let jsonParser = JSONParser()
    private static let regexParser = RegexParser()
    private static let tableParser = TableParser()
    private static let memoryPressureParser = MemoryPressureParser()
    private static let diskUsageParser = DiskUsageParser()
    private static let processTableParser = ProcessTableParser()

    static func parser(for type: OutputParser) -> OutputParserProtocol {
        switch type {
        case .text:
            return textParser
        case .json:
            return jsonParser
        case .regex:
            return regexParser
        case .table:
            return tableParser
        case .memoryPressure:
            return memoryPressureParser
        case .diskUsage:
            return diskUsageParser
        case .processTable:
            return processTableParser
        }
    }
}
