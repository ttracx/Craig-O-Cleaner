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
                            Task { await runMission("quick") }
                        }

                        MissionButton(
                            title: "Deep Cleanup",
                            description: "Comprehensive system cleanup",
                            icon: "tornado",
                            color: .blue
                        ) {
                            Task { await runMission("deep") }
                        }

                        MissionButton(
                            title: "Diagnostics",
                            description: "System health analysis",
                            icon: "stethoscope",
                            color: .purple
                        ) {
                            Task { await runMission("diagnostics") }
                        }

                        MissionButton(
                            title: "Emergency",
                            description: "Critical system recovery",
                            icon: "exclamationmark.triangle",
                            color: .red
                        ) {
                            Task { await runMission("emergency") }
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
                                missionLog.removeAll()
                            }
                            .buttonStyle(.borderless)
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(missionLog.enumerated()), id: \.offset) { _, log in
                                    Text(log)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(height: 150)
                        .padding()
                        .background(.black.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
        }
    }

    private func runMission(_ type: String) async {
        isRunningMission = true
        missionLog.append("[\(Date().formatted(date: .omitted, time: .standard))] Starting \(type) mission with \(team.name)...")

        let executor = CommandExecutor.shared

        switch type {
        case "quick":
            missionLog.append("  → Purging inactive memory...")
            _ = try? await executor.executePrivileged("purge")
            missionLog.append("  → Memory purged")

            missionLog.append("  → Clearing temporary files...")
            _ = try? await executor.execute("rm -rf ~/Library/Caches/TemporaryItems/* 2>/dev/null")
            missionLog.append("  → Temporary files cleared")

        case "deep":
            missionLog.append("  → Purging memory...")
            _ = try? await executor.executePrivileged("purge")
            missionLog.append("  → Memory purged")

            missionLog.append("  → Clearing user caches...")
            _ = try? await executor.execute("rm -rf ~/Library/Caches/* 2>/dev/null")
            missionLog.append("  → User caches cleared")

            missionLog.append("  → Clearing browser caches...")
            _ = try? await executor.execute("rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null")
            _ = try? await executor.execute("rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null")
            missionLog.append("  → Browser caches cleared")

            missionLog.append("  → Clearing logs...")
            _ = try? await executor.execute("find ~/Library/Logs -type f -mtime +7 -delete 2>/dev/null")
            missionLog.append("  → Old logs cleared")

        case "diagnostics":
            missionLog.append("  → Analyzing system health...")

            if let cpuResult = try? await executor.execute("top -l 1 -s 0 | grep 'CPU usage'") {
                missionLog.append("  → \(cpuResult.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }

            if let memResult = try? await executor.execute("top -l 1 -s 0 | grep PhysMem") {
                missionLog.append("  → \(memResult.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }

            if let diskResult = try? await executor.execute("df -h / | tail -1") {
                missionLog.append("  → Disk: \(diskResult.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }

        case "emergency":
            missionLog.append("  → EMERGENCY: Terminating resource hogs...")

            // Kill processes using > 90% CPU
            _ = try? await executor.execute("ps aux | awk '$3 > 90 {print $2}' | xargs -I {} kill -9 {} 2>/dev/null")
            missionLog.append("  → High CPU processes terminated")

            missionLog.append("  → EMERGENCY: Purging memory...")
            _ = try? await executor.executePrivileged("purge")
            missionLog.append("  → Memory purged")

            missionLog.append("  → EMERGENCY: Closing browser tabs...")
            _ = try? await executor.executeAppleScript("""
                tell application "Safari"
                    if (count of windows) > 0 then
                        close tabs of window 1
                    end if
                end tell
                """)
            missionLog.append("  → Browser tabs closed")

        default:
            break
        }

        missionLog.append("[\(Date().formatted(date: .omitted, time: .standard))] Mission completed!")
        isRunningMission = false

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
