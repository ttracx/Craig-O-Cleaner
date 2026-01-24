import SwiftUI

struct BrowsersView: View {
    @EnvironmentObject var appState: AppState
    @State private var browsers: [BrowserInfo] = []
    @State private var selectedBrowser: BrowserInfo?
    @State private var isRefreshing = false
    @State private var refreshTimer: Timer?

    struct BrowserInfo: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let bundleId: String
        let isRunning: Bool
        var tabCount: Int
        var memoryUsage: Double
        let icon: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: BrowserInfo, rhs: BrowserInfo) -> Bool {
            lhs.id == rhs.id
        }
    }

    var body: some View {
        HSplitView {
            // Browser list
            VStack(alignment: .leading, spacing: 0) {
                Text("Browsers")
                    .font(.headline)
                    .padding()

                List(browsers, selection: $selectedBrowser) { browser in
                    BrowserRow(browser: browser)
                        .tag(browser)
                }
                .listStyle(.inset)

                HStack {
                    Button {
                        Task { await refreshBrowsers() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isRefreshing)

                    Spacer()

                    Text("\(browsers.filter { $0.isRunning }.count) running")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .frame(minWidth: 250)

            // Browser details
            if let browser = selectedBrowser {
                BrowserDetailView(browser: browser) {
                    Task { await refreshBrowsers() }
                }
            } else {
                VStack {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Select a browser")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Browsers")
        .task {
            await refreshBrowsers()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                await refreshBrowsers()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshBrowsers() async {
        guard !isRefreshing else { return }

        await MainActor.run {
            isRefreshing = true
        }

        var updatedBrowsers: [BrowserInfo] = []

        let browserConfigs: [(name: String, bundleId: String, icon: String)] = [
            ("Safari", "com.apple.Safari", "safari"),
            ("Google Chrome", "com.google.Chrome", "globe"),
            ("Firefox", "org.mozilla.firefox", "flame"),
            ("Microsoft Edge", "com.microsoft.edgemac", "globe.americas"),
            ("Brave", "com.brave.Browser", "shield"),
            ("Arc", "company.thebrowser.Browser", "circle.grid.cross")
        ]

        for config in browserConfigs {
            // Check if browser is running using pgrep
            var isRunning = false
            let pgrepTask = Process()
            pgrepTask.launchPath = "/usr/bin/pgrep"
            pgrepTask.arguments = ["-i", config.name]
            let pgrepPipe = Pipe()
            pgrepTask.standardOutput = pgrepPipe
            pgrepTask.standardError = Pipe()

            try? pgrepTask.run()
            pgrepTask.waitUntilExit()

            if pgrepTask.terminationStatus == 0 {
                let data = pgrepPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    isRunning = true
                }
            }

            var tabCount = 0
            var memoryUsage: Double = 0

            if isRunning {
                // Get tab count via AppleScript
                if config.name == "Safari" || config.name == "Google Chrome" {
                    let script = """
                    tell application "\(config.name)"
                        set tabCount to 0
                        repeat with w in windows
                            set tabCount to tabCount + (count of tabs of w)
                        end repeat
                        return tabCount
                    end tell
                    """

                    let asTask = Process()
                    asTask.launchPath = "/usr/bin/osascript"
                    asTask.arguments = ["-e", script]
                    let asPipe = Pipe()
                    asTask.standardOutput = asPipe
                    asTask.standardError = Pipe()

                    try? asTask.run()
                    asTask.waitUntilExit()

                    if asTask.terminationStatus == 0 {
                        let data = asPipe.fileHandleForReading.readDataToEndOfFile()
                        if let output = String(data: data, encoding: .utf8) {
                            tabCount = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
                        }
                    }
                }

                // Get memory usage
                let memTask = Process()
                memTask.launchPath = "/bin/ps"
                memTask.arguments = ["aux"]
                let memPipe = Pipe()
                memTask.standardOutput = memPipe
                memTask.standardError = Pipe()

                try? memTask.run()
                memTask.waitUntilExit()

                if let data = try? memPipe.fileHandleForReading.readDataToEndOfFile(),
                   let output = String(data: data, encoding: .utf8) {
                    var totalMem: Double = 0
                    for line in output.components(separatedBy: "\n") {
                        if line.range(of: config.name, options: .caseInsensitive) != nil {
                            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                            if parts.count >= 6, let mem = Double(parts[5]) {
                                totalMem += mem
                            }
                        }
                    }
                    memoryUsage = totalMem / 1024 // Convert KB to MB
                }
            }

            updatedBrowsers.append(BrowserInfo(
                name: config.name,
                bundleId: config.bundleId,
                isRunning: isRunning,
                tabCount: tabCount,
                memoryUsage: memoryUsage,
                icon: config.icon
            ))
        }

        // Update state on main actor
        await MainActor.run {
            browsers = updatedBrowsers
            isRefreshing = false
        }
    }
}

struct BrowserRow: View {
    let browser: BrowsersView.BrowserInfo

    var body: some View {
        HStack {
            Image(systemName: browser.icon)
                .frame(width: 24)
                .foregroundStyle(browser.isRunning ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(browser.name)
                    .fontWeight(.medium)
                if browser.isRunning {
                    Text("\(browser.tabCount) tabs • \(String(format: "%.0f", browser.memoryUsage)) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Circle()
                .fill(browser.isRunning ? .green : .gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

struct BrowserDetailView: View {
    let browser: BrowsersView.BrowserInfo
    let onAction: () -> Void
    @State private var isClosingTabs = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: browser.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text(browser.name)
                    .font(.title)
                    .fontWeight(.bold)

                HStack(spacing: 16) {
                    Label(browser.isRunning ? "Running" : "Not Running", systemImage: browser.isRunning ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(browser.isRunning ? .green : .secondary)

                    if browser.isRunning {
                        Label("\(browser.tabCount) tabs", systemImage: "square.stack")
                        Label("\(String(format: "%.0f", browser.memoryUsage)) MB", systemImage: "memorychip")
                    }
                }
                .font(.subheadline)
            }
            .padding()

            Divider()

            if browser.isRunning {
                // Actions
                VStack(spacing: 12) {
                    Text("Actions")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        ActionButton(
                            title: "Close Heavy Tabs",
                            icon: "xmark.circle",
                            color: .orange
                        ) {
                            Task { await closeHeavyTabs() }
                        }

                        ActionButton(
                            title: "Clear Cache",
                            icon: "trash",
                            color: .red
                        ) {
                            Task { await clearCache() }
                        }
                    }

                    HStack(spacing: 12) {
                        ActionButton(
                            title: "Close All Tabs",
                            icon: "xmark.square",
                            color: .red
                        ) {
                            Task { await closeAllTabs() }
                        }

                        ActionButton(
                            title: "Force Quit",
                            icon: "power",
                            color: .red
                        ) {
                            Task { await forceQuit() }
                        }
                    }
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    Text("Browser is not running")
                        .foregroundStyle(.secondary)

                    Button("Launch \(browser.name)") {
                        Task { await launchBrowser() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func closeHeavyTabs() async {
        if browser.name == "Safari" {
            let script = """
            tell application "Safari"
                -- Close duplicate tabs as Safari doesn't expose memory per tab
                set urlList to {}
                repeat with w in windows
                    repeat with t in tabs of w
                        set tabURL to URL of t
                        if urlList contains tabURL then
                            close t
                        else
                            set end of urlList to tabURL
                        end if
                    end repeat
                end repeat
            end tell
            """

            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            try? task.run()
            task.waitUntilExit()
        }

        onAction()
    }

    private func clearCache() async {
        let cachePath: String
        switch browser.name {
        case "Safari":
            cachePath = "~/Library/Caches/com.apple.Safari"
        case "Google Chrome":
            cachePath = "~/Library/Caches/Google/Chrome"
        case "Firefox":
            cachePath = "~/Library/Caches/Firefox"
        case "Microsoft Edge":
            cachePath = "~/Library/Caches/Microsoft Edge"
        case "Brave":
            cachePath = "~/Library/Caches/BraveSoftware"
        case "Arc":
            cachePath = "~/Library/Caches/company.thebrowser.Browser"
        default:
            onAction()
            return
        }

        let expandedPath = (cachePath as NSString).expandingTildeInPath
        let task = Process()
        task.launchPath = "/bin/rm"
        task.arguments = ["-rf", expandedPath + "/*"]
        try? task.run()
        task.waitUntilExit()

        onAction()
    }

    private func closeAllTabs() async {
        if browser.name == "Safari" || browser.name == "Google Chrome" {
            let script = """
            tell application "\(browser.name)"
                repeat with w in windows
                    close tabs of w
                end repeat
            end tell
            """

            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            try? task.run()
            task.waitUntilExit()
        }

        onAction()
    }

    private func forceQuit() async {
        let task = Process()
        task.launchPath = "/usr/bin/pkill"
        task.arguments = ["-9", "-f", browser.name]
        try? task.run()
        task.waitUntilExit()

        onAction()
    }

    private func launchBrowser() async {
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", browser.name]
        try? task.run()
        task.waitUntilExit()

        try? await Task.sleep(nanoseconds: 1_000_000_000)
        onAction()
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BrowsersView()
        .environmentObject(AppState.shared)
        .frame(width: 800, height: 600)
}
