import SwiftUI

struct AgentsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTeam: TeamInfo?
    @State private var isRunningMission = false
    @State private var missionLog: [String] = []

    struct TeamInfo: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let type: String
        let description: String
        let agents: [AgentInfo]
        let icon: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: TeamInfo, rhs: TeamInfo) -> Bool {
            lhs.id == rhs.id
        }
    }

    struct AgentInfo: Identifiable {
        let id = UUID()
        let name: String
        let role: String
        let status: String
        let skills: [String]
    }

    let teams: [TeamInfo] = [
        TeamInfo(
            name: "Cleanup Specialists",
            type: "cleanup",
            description: "Comprehensive system cleanup specialists for memory, caches, and disk space",
            agents: [
                AgentInfo(name: "CleanupAgent", role: "Team Leader", status: "Ready", skills: ["Memory Purge", "Cache Cleaning", "Temp Files"]),
                AgentInfo(name: "BrowserAgent", role: "Browser Specialist", status: "Ready", skills: ["Tab Management", "Cache Clearing", "Cookie Cleanup"])
            ],
            icon: "sparkles"
        ),
        TeamInfo(
            name: "Diagnostics Team",
            type: "diagnostics",
            description: "System health monitoring and comprehensive analysis",
            agents: [
                AgentInfo(name: "DiagnosticsAgent", role: "Team Leader", status: "Ready", skills: ["Health Reports", "Performance Analysis", "System Monitoring"]),
                AgentInfo(name: "ProcessAgent", role: "Process Specialist", status: "Ready", skills: ["Process Monitoring", "Resource Analysis", "Performance Tracking"])
            ],
            icon: "stethoscope"
        ),
        TeamInfo(
            name: "Optimization Team",
            type: "optimization",
            description: "Performance optimization and resource management",
            agents: [
                AgentInfo(name: "ProcessAgent", role: "Team Leader", status: "Ready", skills: ["Process Management", "Resource Optimization", "Performance Tuning"]),
                AgentInfo(name: "BrowserAgent", role: "Browser Specialist", status: "Ready", skills: ["Tab Optimization", "Memory Recovery"]),
                AgentInfo(name: "CleanupAgent", role: "Cleanup Specialist", status: "Ready", skills: ["Cache Management", "Memory Cleanup"])
            ],
            icon: "bolt"
        ),
        TeamInfo(
            name: "Emergency Response",
            type: "emergency",
            description: "Critical system recovery and emergency response",
            agents: [
                AgentInfo(name: "CleanupAgent", role: "Team Leader", status: "Ready", skills: ["Emergency Cleanup", "Memory Recovery"]),
                AgentInfo(name: "ProcessAgent", role: "Process Specialist", status: "Ready", skills: ["Process Termination", "Resource Liberation"]),
                AgentInfo(name: "BrowserAgent", role: "Browser Specialist", status: "Ready", skills: ["Tab Termination", "Browser Recovery"]),
                AgentInfo(name: "DiagnosticsAgent", role: "Diagnostics Specialist", status: "Ready", skills: ["Quick Assessment", "System Status"])
            ],
            icon: "exclamationmark.triangle"
        )
    ]

    var body: some View {
        HSplitView {
            // Team list
            VStack(alignment: .leading, spacing: 0) {
                Text("Agent Teams")
                    .font(.headline)
                    .padding()

                List(teams, selection: $selectedTeam) { team in
                    TeamRow(team: team)
                        .tag(team)
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 250)

            // Team details
            if let team = selectedTeam {
                TeamDetailView(team: team, isRunningMission: $isRunningMission, missionLog: $missionLog)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Select a team")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Agent teams work together to perform complex system management tasks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Agents")
        .onAppear {
            selectedTeam = teams.first
        }
    }
}

struct TeamRow: View {
    let team: AgentsView.TeamInfo

    var body: some View {
        HStack {
            Image(systemName: team.icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(team.name)
                    .fontWeight(.medium)
                Text("\(team.agents.count) agents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct TeamDetailView: View {
    let team: AgentsView.TeamInfo
    @Binding var isRunningMission: Bool
    @Binding var missionLog: [String]
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: team.icon)
                            .font(.title)
                            .foregroundStyle(.blue)
                        Text(team.name)
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    Text(team.description)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Team Members
                VStack(alignment: .leading, spacing: 12) {
                    Text("Team Members")
                        .font(.headline)

                    ForEach(team.agents) { agent in
                        AgentCard(agent: agent)
                    }
                }

                Divider()

                // Missions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Missions")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MissionButton(
                            title: "Quick Cleanup",
                            description: "Fast memory and temp cleanup",
                            icon: "hare",
                            color: .green
                        ) {
                            Task { @MainActor in
                                await runMission("quick")
                            }
                        }

                        MissionButton(
                            title: "Deep Cleanup",
                            description: "Comprehensive system cleanup",
                            icon: "tornado",
                            color: .blue
                        ) {
                            Task { @MainActor in
                                await runMission("deep")
                            }
                        }

                        MissionButton(
                            title: "Diagnostics",
                            description: "System health analysis",
                            icon: "stethoscope",
                            color: .purple
                        ) {
                            Task { @MainActor in
                                await runMission("diagnostics")
                            }
                        }

                        MissionButton(
                            title: "Emergency",
                            description: "Critical system recovery",
                            icon: "exclamationmark.triangle",
                            color: .red
                        ) {
                            Task { @MainActor in
                                await runMission("emergency")
                            }
                        }
                    }
                }

                // Mission Log
                if !missionLog.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Mission Log")
                                .font(.headline)
                            Spacer()
                            Button("Clear") {
                                Task { @MainActor in
                                    missionLog.removeAll()
                                }
                            }
                            .buttonStyle(.borderless)
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(missionLog.enumerated()), id: \.offset) { _, log in
                                    Text(log)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .frame(height: 150)
                        .padding()
                        .background(Color(.systemGray).opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
        }
    }

    private func runMission(_ type: String) async {
        await MainActor.run {
            isRunningMission = true
            missionLog.append("[\(Date().formatted(date: .omitted, time: .standard))] Starting \(type) mission with \(team.name)...")
        }

        switch type {
        case "quick":
            await MainActor.run {
                missionLog.append("  → Purging inactive memory...")
            }

            // Purge memory (requires sudo)
            let purgeScript = "do shell script \"purge\" with administrator privileges"
            let purgeTask = Process()
            purgeTask.launchPath = "/usr/bin/osascript"
            purgeTask.arguments = ["-e", purgeScript]
            purgeTask.standardOutput = Pipe()
            purgeTask.standardError = Pipe()
            try? purgeTask.run()
            purgeTask.waitUntilExit()

            await MainActor.run {
                missionLog.append("  → Memory purged")
                missionLog.append("  → Clearing temporary files...")
            }

            let tempTask = Process()
            tempTask.launchPath = "/bin/sh"
            tempTask.arguments = ["-c", "rm -rf ~/Library/Caches/TemporaryItems/* 2>/dev/null"]
            tempTask.standardOutput = Pipe()
            tempTask.standardError = Pipe()
            try? tempTask.run()
            tempTask.waitUntilExit()

            await MainActor.run {
                missionLog.append("  → Temporary files cleared")
            }

        case "deep":
            await MainActor.run {
                missionLog.append("  → Purging memory...")
            }

            // Purge memory
            let purgeScript = "do shell script \"purge\" with administrator privileges"
            let purgeTask = Process()
            purgeTask.launchPath = "/usr/bin/osascript"
            purgeTask.arguments = ["-e", purgeScript]
            purgeTask.standardOutput = Pipe()
            purgeTask.standardError = Pipe()
            try? purgeTask.run()
            purgeTask.waitUntilExit()

            await MainActor.run {
                missionLog.append("  → Memory purged")
                missionLog.append("  → Clearing user caches...")
            }

            let cacheTask = Process()
            cacheTask.launchPath = "/bin/sh"
            cacheTask.arguments = ["-c", "rm -rf ~/Library/Caches/* 2>/dev/null"]
            cacheTask.standardOutput = Pipe()
            cacheTask.standardError = Pipe()
            try? cacheTask.run()
            cacheTask.waitUntilExit()

            await MainActor.run {
                missionLog.append("  → User caches cleared")
                missionLog.append("  → Clearing browser caches...")
            }

            let safariTask = Process()
            safariTask.launchPath = "/bin/sh"
            safariTask.arguments = ["-c", "rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null"]
            safariTask.standardOutput = Pipe()
            safariTask.standardError = Pipe()
            try? safariTask.run()
            safariTask.waitUntilExit()

            let chromeTask = Process()
            chromeTask.launchPath = "/bin/sh"
            chromeTask.arguments = ["-c", "rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null"]
            chromeTask.standardOutput = Pipe()
            chromeTask.standardError = Pipe()
            try? chromeTask.run()
            chromeTask.waitUntilExit()

            await MainActor.run {
                missionLog.append("  → Browser caches cleared")
                missionLog.append("  → Clearing logs...")
            }

            let logsTask = Process()
            logsTask.launchPath = "/bin/sh"
            logsTask.arguments = ["-c", "find ~/Library/Logs -type f -mtime +7 -delete 2>/dev/null"]
            logsTask.standardOutput = Pipe()
            logsTask.standardError = Pipe()
            try? logsTask.run()
            logsTask.waitUntilExit()

            await MainActor.run {
                missionLog.append("  → Old logs cleared")
            }

        case "diagnostics":
            await MainActor.run {
                missionLog.append("  → Analyzing system health...")
            }

            // CPU usage
            let cpuTask = Process()
            cpuTask.launchPath = "/bin/sh"
            cpuTask.arguments = ["-c", "top -l 1 -s 0 | grep 'CPU usage'"]
            let cpuPipe = Pipe()
            cpuTask.standardOutput = cpuPipe
            cpuTask.standardError = Pipe()
            try? cpuTask.run()
            cpuTask.waitUntilExit()

            if cpuTask.terminationStatus == 0 {
                let data = cpuPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let cpuInfo = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    await MainActor.run {
                        missionLog.append("  → \(cpuInfo)")
                    }
                }
            }

            // Memory usage
            let memTask = Process()
            memTask.launchPath = "/bin/sh"
            memTask.arguments = ["-c", "top -l 1 -s 0 | grep PhysMem"]
            let memPipe = Pipe()
            memTask.standardOutput = memPipe
            memTask.standardError = Pipe()
            try? memTask.run()
            memTask.waitUntilExit()

            if memTask.terminationStatus == 0 {
                let data = memPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let memInfo = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    await MainActor.run {
                        missionLog.append("  → \(memInfo)")
                    }
                }
            }

            // Disk usage
            let diskTask = Process()
            diskTask.launchPath = "/bin/sh"
            diskTask.arguments = ["-c", "df -h / | tail -1"]
            let diskPipe = Pipe()
            diskTask.standardOutput = diskPipe
            diskTask.standardError = Pipe()
            try? diskTask.run()
            diskTask.waitUntilExit()

            if diskTask.terminationStatus == 0 {
                let data = diskPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let diskInfo = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    await MainActor.run {
                        missionLog.append("  → Disk: \(diskInfo)")
                    }
                }
            }

        case "emergency":
            await MainActor.run {
                missionLog.append("  → EMERGENCY: Terminating resource hogs...")
            }

            // Kill high CPU processes
            let killTask = Process()
            killTask.launchPath = "/bin/sh"
            killTask.arguments = ["-c", "ps aux | awk '$3 > 90 {print $2}' | xargs -I {} kill -9 {} 2>/dev/null"]
            killTask.standardOutput = Pipe()
            killTask.standardError = Pipe()
            try? killTask.run()
            killTask.waitUntilExit()

            await MainActor.run {
                missionLog.append("  → High CPU processes terminated")
                missionLog.append("  → EMERGENCY: Purging memory...")
            }

            // Purge memory
            let purgeScript = "do shell script \"purge\" with administrator privileges"
            let purgeTask = Process()
            purgeTask.launchPath = "/usr/bin/osascript"
            purgeTask.arguments = ["-e", purgeScript]
            purgeTask.standardOutput = Pipe()
            purgeTask.standardError = Pipe()
            try? purgeTask.run()
            purgeTask.waitUntilExit()

            await MainActor.run {
                missionLog.append("  → Memory purged")
                missionLog.append("  → EMERGENCY: Closing browser tabs...")
            }

            // Close Safari tabs
            let safariScript = """
            tell application "Safari"
                if (count of windows) > 0 then
                    close tabs of window 1
                end if
            end tell
            """
            let safariTask = Process()
            safariTask.launchPath = "/usr/bin/osascript"
            safariTask.arguments = ["-e", safariScript]
            safariTask.standardOutput = Pipe()
            safariTask.standardError = Pipe()
            try? safariTask.run()
            safariTask.waitUntilExit()

            await MainActor.run {
                missionLog.append("  → Browser tabs closed")
            }

        default:
            break
        }

        await MainActor.run {
            missionLog.append("[\(Date().formatted(date: .omitted, time: .standard))] Mission completed!")
            isRunningMission = false
        }

        await appState.updateMetrics()
    }
}

struct AgentCard: View {
    let agent: AgentsView.AgentInfo

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(agent.name)
                        .fontWeight(.medium)
                    if agent.role == "Team Leader" {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                Text(agent.role)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    ForEach(agent.skills, id: \.self) { skill in
                        Text(skill)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Circle()
                .fill(agent.status == "Ready" ? .green : .orange)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct MissionButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                    Spacer()
                }

                Text(title)
                    .fontWeight(.semibold)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AgentsView()
        .environmentObject(AppState.shared)
        .frame(width: 900, height: 700)
}
