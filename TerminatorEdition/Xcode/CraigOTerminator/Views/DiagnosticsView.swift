import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isRunningDiagnostics = false
    @State private var diagnosticReport: DiagnosticReport?
    @State private var selectedSection: DiagnosticSection = .system

    enum DiagnosticSection: String, CaseIterable {
        case system = "System"
        case cpu = "CPU"
        case memory = "Memory"
        case disk = "Disk"
        case network = "Network"
        case battery = "Battery"
    }

    struct DiagnosticReport {
        var systemInfo: SystemInfo?
        var cpuInfo: CPUInfo?
        var memoryInfo: MemoryInfo?
        var diskInfo: DiskInfo?
        var networkInfo: NetworkInfo?
        var batteryInfo: BatteryInfo?

        struct SystemInfo {
            let hostname: String
            let model: String
            let osVersion: String
            let kernel: String
            let uptime: String
        }

        struct CPUInfo {
            let model: String
            let cores: String
            let usage: Double
        }

        struct MemoryInfo {
            let total: String
            let used: String
            let free: String
            let pressure: String
        }

        struct DiskInfo {
            let total: String
            let used: String
            let available: String
            let percentUsed: Int
        }

        struct NetworkInfo {
            let activeInterface: String
            let ipAddress: String
            let wifiSSID: String?
            let isConnected: Bool
        }

        struct BatteryInfo {
            let charge: Int
            let status: String
            let cycleCount: Int?
            let condition: String?
        }
    }

    var body: some View {
        HSplitView {
            // Section list
            VStack(alignment: .leading, spacing: 0) {
                Text("Diagnostics")
                    .font(.headline)
                    .padding()

                List(DiagnosticSection.allCases, id: \.self, selection: $selectedSection) { section in
                    Label(section.rawValue, systemImage: iconFor(section))
                        .tag(section)
                }
                .listStyle(.sidebar)

                Spacer()

                Button {
                    Task { await runFullDiagnostics() }
                } label: {
                    HStack {
                        if isRunningDiagnostics {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "stethoscope")
                        }
                        Text(isRunningDiagnostics ? "Running..." : "Run Full Diagnostics")
                    }
                    .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(isRunningDiagnostics)
                .padding()
            }
            .frame(minWidth: 200)

            // Detail view
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let report = diagnosticReport {
                        switch selectedSection {
                        case .system:
                            SystemInfoSection(info: report.systemInfo)
                        case .cpu:
                            CPUInfoSection(info: report.cpuInfo)
                        case .memory:
                            MemoryInfoSection(info: report.memoryInfo)
                        case .disk:
                            DiskInfoSection(info: report.diskInfo)
                        case .network:
                            NetworkInfoSection(info: report.networkInfo)
                        case .battery:
                            BatteryInfoSection(info: report.batteryInfo)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "stethoscope")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Run diagnostics to see system information")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Button("Run Diagnostics") {
                                Task { await runFullDiagnostics() }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .frame(minWidth: 400)
        }
        .navigationTitle("Diagnostics")
        .task {
            await runFullDiagnostics()
        }
    }

    private func iconFor(_ section: DiagnosticSection) -> String {
        switch section {
        case .system: return "desktopcomputer"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .battery: return "battery.100"
        }
    }

    private func runFullDiagnostics() async {
        isRunningDiagnostics = true
        let executor = CommandExecutor.shared

        var report = DiagnosticReport()

        // System Info
        async let hostname = try? await executor.execute("hostname").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let model = try? await executor.execute("sysctl -n hw.model").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let osVersion = try? await executor.execute("sw_vers -productVersion").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let kernel = try? await executor.execute("uname -r").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let uptime = try? await executor.execute("uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}'").output.trimmingCharacters(in: .whitespacesAndNewlines)

        let (h, m, o, k, u) = await (hostname, model, osVersion, kernel, uptime)
        report.systemInfo = DiagnosticReport.SystemInfo(
            hostname: h ?? "Unknown",
            model: m ?? "Unknown",
            osVersion: o ?? "Unknown",
            kernel: k ?? "Unknown",
            uptime: u ?? "Unknown"
        )

        // CPU Info
        async let cpuModel = try? await executor.execute("sysctl -n machdep.cpu.brand_string").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let cores = try? await executor.execute("echo \"$(sysctl -n hw.physicalcpu) physical, $(sysctl -n hw.logicalcpu) logical\"").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let cpuUsage = try? await executor.execute("top -l 1 -s 0 | grep 'CPU usage' | awk '{print $3}' | tr -d '%'").output.trimmingCharacters(in: .whitespacesAndNewlines)

        let (cm, co, cu) = await (cpuModel, cores, cpuUsage)
        report.cpuInfo = DiagnosticReport.CPUInfo(
            model: cm ?? "Unknown",
            cores: co ?? "Unknown",
            usage: Double(cu ?? "0") ?? 0
        )

        // Memory Info
        async let memTotal = try? await executor.execute("sysctl -n hw.memsize | awk '{printf \"%.0f GB\", $0/1073741824}'").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let memPressure = try? await executor.execute("memory_pressure | head -1 | awk -F': ' '{print $2}'").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let memStats = try? await executor.execute("top -l 1 -s 0 | grep PhysMem").output.trimmingCharacters(in: .whitespacesAndNewlines)

        let (mt, mp, ms) = await (memTotal, memPressure, memStats)

        var memUsed = "Unknown"
        var memFree = "Unknown"
        if let stats = ms {
            if let usedMatch = stats.range(of: #"(\d+[A-Z]) used"#, options: .regularExpression) {
                memUsed = String(stats[usedMatch]).replacingOccurrences(of: " used", with: "")
            }
            if let freeMatch = stats.range(of: #"(\d+[A-Z]) unused"#, options: .regularExpression) {
                memFree = String(stats[freeMatch]).replacingOccurrences(of: " unused", with: "")
            }
        }

        report.memoryInfo = DiagnosticReport.MemoryInfo(
            total: mt ?? "Unknown",
            used: memUsed,
            free: memFree,
            pressure: mp ?? "Unknown"
        )

        // Disk Info
        if let diskResult = try? await executor.execute("df -h / | tail -1") {
            let parts = diskResult.output.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 5 {
                report.diskInfo = DiagnosticReport.DiskInfo(
                    total: String(parts[1]),
                    used: String(parts[2]),
                    available: String(parts[3]),
                    percentUsed: Int(parts[4].replacingOccurrences(of: "%", with: "")) ?? 0
                )
            }
        }

        // Network Info
        async let activeIf = try? await executor.execute("route get default 2>/dev/null | grep interface | awk '{print $2}'").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let wifiSSID = try? await executor.execute("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null | grep ' SSID' | awk '{print $2}'").output.trimmingCharacters(in: .whitespacesAndNewlines)
        async let pingResult = try? await executor.execute("ping -c 1 -W 2 8.8.8.8 &>/dev/null && echo 'connected' || echo 'disconnected'").output.trimmingCharacters(in: .whitespacesAndNewlines)

        let (ai, ws, pr) = await (activeIf, wifiSSID, pingResult)

        var ipAddr = "Unknown"
        if let interface = ai, !interface.isEmpty {
            if let ipResult = try? await executor.execute("ifconfig \(interface) 2>/dev/null | grep 'inet ' | awk '{print $2}'") {
                ipAddr = ipResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        report.networkInfo = DiagnosticReport.NetworkInfo(
            activeInterface: ai ?? "None",
            ipAddress: ipAddr,
            wifiSSID: ws?.isEmpty == false ? ws : nil,
            isConnected: pr?.contains("connected") ?? false
        )

        // Battery Info
        if let batteryResult = try? await executor.execute("pmset -g batt 2>/dev/null") {
            let output = batteryResult.output
            if output.contains("Battery") {
                var charge = 0
                var status = "AC Power"

                if let percentMatch = output.range(of: #"\d+%"#, options: .regularExpression) {
                    charge = Int(output[percentMatch].replacingOccurrences(of: "%", with: "")) ?? 0
                }

                if output.contains("discharging") {
                    status = "Discharging"
                } else if output.contains("charging") {
                    status = "Charging"
                } else if output.contains("charged") {
                    status = "Charged"
                }

                report.batteryInfo = DiagnosticReport.BatteryInfo(
                    charge: charge,
                    status: status,
                    cycleCount: nil,
                    condition: nil
                )
            }
        }

        diagnosticReport = report
        isRunningDiagnostics = false
    }
}

// MARK: - Section Views

struct SystemInfoSection: View {
    let info: DiagnosticsView.DiagnosticReport.SystemInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "System Information", icon: "desktopcomputer")

            if let info = info {
                InfoGrid {
                    InfoRow(label: "Hostname", value: info.hostname)
                    InfoRow(label: "Model", value: info.model)
                    InfoRow(label: "macOS Version", value: info.osVersion)
                    InfoRow(label: "Kernel", value: info.kernel)
                    InfoRow(label: "Uptime", value: info.uptime)
                }
            } else {
                Text("No data available")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct CPUInfoSection: View {
    let info: DiagnosticsView.DiagnosticReport.CPUInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "CPU Information", icon: "cpu")

            if let info = info {
                InfoGrid {
                    InfoRow(label: "Model", value: info.model)
                    InfoRow(label: "Cores", value: info.cores)
                }

                // CPU Usage gauge
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Usage")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 8)
                                .fill(info.usage > 80 ? .red : (info.usage > 50 ? .orange : .green))
                                .frame(width: geometry.size.width * (info.usage / 100))
                        }
                    }
                    .frame(height: 24)

                    Text("\(String(format: "%.1f", info.usage))%")
                        .font(.headline)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No data available")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MemoryInfoSection: View {
    let info: DiagnosticsView.DiagnosticReport.MemoryInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Memory Information", icon: "memorychip")

            if let info = info {
                InfoGrid {
                    InfoRow(label: "Total", value: info.total)
                    InfoRow(label: "Used", value: info.used)
                    InfoRow(label: "Free", value: info.free)
                    InfoRow(label: "Pressure", value: info.pressure)
                }
            } else {
                Text("No data available")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DiskInfoSection: View {
    let info: DiagnosticsView.DiagnosticReport.DiskInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Disk Information", icon: "internaldrive")

            if let info = info {
                InfoGrid {
                    InfoRow(label: "Total", value: info.total)
                    InfoRow(label: "Used", value: info.used)
                    InfoRow(label: "Available", value: info.available)
                }

                // Disk usage gauge
                VStack(alignment: .leading, spacing: 8) {
                    Text("Disk Usage")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 8)
                                .fill(info.percentUsed > 90 ? .red : (info.percentUsed > 75 ? .orange : .blue))
                                .frame(width: geometry.size.width * (Double(info.percentUsed) / 100))
                        }
                    }
                    .frame(height: 24)

                    Text("\(info.percentUsed)% used")
                        .font(.headline)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No data available")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NetworkInfoSection: View {
    let info: DiagnosticsView.DiagnosticReport.NetworkInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Network Information", icon: "network")

            if let info = info {
                InfoGrid {
                    InfoRow(label: "Interface", value: info.activeInterface)
                    InfoRow(label: "IP Address", value: info.ipAddress)
                    if let ssid = info.wifiSSID {
                        InfoRow(label: "Wi-Fi Network", value: ssid)
                    }
                }

                HStack {
                    Image(systemName: info.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(info.isConnected ? .green : .red)
                    Text(info.isConnected ? "Internet Connected" : "No Internet Connection")
                        .fontWeight(.medium)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(info.isConnected ? .green.opacity(0.1) : .red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No data available")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BatteryInfoSection: View {
    let info: DiagnosticsView.DiagnosticReport.BatteryInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Battery Information", icon: "battery.100")

            if let info = info {
                InfoGrid {
                    InfoRow(label: "Charge", value: "\(info.charge)%")
                    InfoRow(label: "Status", value: info.status)
                    if let cycles = info.cycleCount {
                        InfoRow(label: "Cycle Count", value: "\(cycles)")
                    }
                    if let condition = info.condition {
                        InfoRow(label: "Condition", value: condition)
                    }
                }

                // Battery gauge
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.gray.opacity(0.2))

                            RoundedRectangle(cornerRadius: 8)
                                .fill(info.charge < 20 ? .red : (info.charge < 50 ? .orange : .green))
                                .frame(width: geometry.size.width * (Double(info.charge) / 100))
                        }
                    }
                    .frame(height: 32)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No battery detected (Desktop Mac)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
}

struct InfoGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
    }
}

#Preview {
    DiagnosticsView()
        .environmentObject(AppState.shared)
        .frame(width: 800, height: 600)
}
