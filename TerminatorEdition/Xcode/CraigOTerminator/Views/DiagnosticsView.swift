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
                    Task { @MainActor in
                        await runFullDiagnostics()
                    }
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
                                Task { @MainActor in
                                    await runFullDiagnostics()
                                }
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
        // Delay to ensure we're completely outside any view update cycle
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        isRunningDiagnostics = true

        var report = DiagnosticReport()

        let executor = CommandExecutor.shared

        // Helper function to run command via CommandExecutor
        func runCommand(_ command: String) async -> String {
            guard let result = try? await executor.execute(command) else {
                return ""
            }
            return result.isSuccess ? result.output.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        }

        let hostname = await runCommand("hostname")
        let model = await runCommand("sysctl -n hw.model")
        let osVersion = await runCommand("sw_vers -productVersion")
        let kernel = await runCommand("uname -r")
        let uptimeOutput = await runCommand("uptime")

        var uptime = "Unknown"
        if let range = uptimeOutput.range(of: #"up\s+(.+?),"#, options: .regularExpression) {
            uptime = String(uptimeOutput[range]).replacingOccurrences(of: "up ", with: "").replacingOccurrences(of: ",", with: "")
        }

        report.systemInfo = DiagnosticReport.SystemInfo(
            hostname: hostname.isEmpty ? "Unknown" : hostname,
            model: model.isEmpty ? "Unknown" : model,
            osVersion: osVersion.isEmpty ? "Unknown" : osVersion,
            kernel: kernel.isEmpty ? "Unknown" : kernel,
            uptime: uptime
        )

        // CPU Info
        let cpuModel = await runCommand("sysctl -n machdep.cpu.brand_string")
        let physicalCPU = await runCommand("sysctl -n hw.physicalcpu")
        let logicalCPU = await runCommand("sysctl -n hw.logicalcpu")
        let cores = "\(physicalCPU) physical, \(logicalCPU) logical"

        let topOutput = await runCommand("top -l 1 -s 0")
        var cpuUsage = 0.0
        if let cpuLine = topOutput.components(separatedBy: "\n").first(where: { $0.contains("CPU usage") }),
           let percentRange = cpuLine.range(of: #"\d+\.\d+"#, options: .regularExpression) {
            cpuUsage = Double(cpuLine[percentRange]) ?? 0.0
        }

        report.cpuInfo = DiagnosticReport.CPUInfo(
            model: cpuModel.isEmpty ? "Unknown" : cpuModel,
            cores: cores,
            usage: cpuUsage
        )

        // Memory Info
        let memSizeBytes = await runCommand("sysctl -n hw.memsize")
        let memGB = (Double(memSizeBytes) ?? 0) / 1073741824.0
        let memTotal = String(format: "%.0f GB", memGB)

        let memPressureOutput = await runCommand("memory_pressure")
        var memPressure = "Unknown"
        if let firstLine = memPressureOutput.components(separatedBy: "\n").first,
           let colonIndex = firstLine.range(of: ": ") {
            memPressure = String(firstLine[colonIndex.upperBound...])
        }

        let topMemOutput = await runCommand("top -l 1 -s 0")
        var memUsed = "Unknown"
        var memFree = "Unknown"
        if let memLine = topMemOutput.components(separatedBy: "\n").first(where: { $0.contains("PhysMem") }) {
            if let usedRange = memLine.range(of: #"\d+[KMGT](?= used)"#, options: .regularExpression) {
                memUsed = String(memLine[usedRange])
            }
            if let freeRange = memLine.range(of: #"\d+[KMGT](?= unused)"#, options: .regularExpression) {
                memFree = String(memLine[freeRange])
            }
        }

        report.memoryInfo = DiagnosticReport.MemoryInfo(
            total: memTotal,
            used: memUsed,
            free: memFree,
            pressure: memPressure
        )

        // Disk Info
        let dfOutput = await runCommand("df -h /")
        if let lastLine = dfOutput.components(separatedBy: "\n").last,
           !lastLine.contains("Filesystem") {
            let parts = lastLine.split(separator: " ", omittingEmptySubsequences: true)
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
        let routeOutput = await runCommand("route get default")
        var activeInterface = "None"
        if let interfaceLine = routeOutput.components(separatedBy: "\n").first(where: { $0.contains("interface:") }),
           let colonIndex = interfaceLine.range(of: ": ") {
            activeInterface = String(interfaceLine[colonIndex.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        var ipAddr = "Unknown"
        if !activeInterface.isEmpty && activeInterface != "None" {
            let ifconfigOutput = await runCommand("ifconfig \(activeInterface)")
            if let inetLine = ifconfigOutput.components(separatedBy: "\n").first(where: { $0.contains("inet ") && !$0.contains("inet6") }) {
                let parts = inetLine.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count >= 2 {
                    ipAddr = String(parts[1])
                }
            }
        }

        let airportOutput = await runCommand("/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I")
        var wifiSSID: String? = nil
        if let ssidLine = airportOutput.components(separatedBy: "\n").first(where: { $0.contains(" SSID:") }),
           let colonIndex = ssidLine.range(of: ": ") {
            let ssid = String(ssidLine[colonIndex.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !ssid.isEmpty {
                wifiSSID = ssid
            }
        }

        // Test internet connectivity
        let pingResult = try? await executor.execute("ping -c 1 -W 2 8.8.8.8")
        let isConnected = pingResult?.isSuccess ?? false

        report.networkInfo = DiagnosticReport.NetworkInfo(
            activeInterface: activeInterface,
            ipAddress: ipAddr,
            wifiSSID: wifiSSID,
            isConnected: isConnected
        )

        // Battery Info
        let batteryOutput = await runCommand("pmset -g batt")
        if batteryOutput.contains("Battery") {
            var charge = 0
            var status = "AC Power"

            if let percentMatch = batteryOutput.range(of: #"\d+%"#, options: .regularExpression) {
                charge = Int(batteryOutput[percentMatch].replacingOccurrences(of: "%", with: "")) ?? 0
            }

            if batteryOutput.contains("discharging") {
                status = "Discharging"
            } else if batteryOutput.contains("charging") {
                status = "Charging"
            } else if batteryOutput.contains("charged") {
                status = "Charged"
            }

            report.batteryInfo = DiagnosticReport.BatteryInfo(
                charge: charge,
                status: status,
                cycleCount: nil,
                condition: nil
            )
        }

        // Delay before batch updating all @State properties
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Batch update all @State
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
