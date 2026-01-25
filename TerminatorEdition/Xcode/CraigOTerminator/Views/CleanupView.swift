import SwiftUI

struct CleanupView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategories: Set<CleanupCategory> = []
    @State private var isAnalyzing = false
    @State private var cacheAnalysis: [CacheAnalysis] = []

    enum CleanupCategory: String, CaseIterable, Identifiable {
        case userCaches = "User Caches"
        case browserCaches = "Browser Caches"
        case systemTemp = "System Temp"
        case developerCaches = "Developer Caches"
        case logs = "Log Files"
        case trash = "Trash"
        case dns = "DNS Cache"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .userCaches: return "folder.badge.gear"
            case .browserCaches: return "globe"
            case .systemTemp: return "clock.arrow.circlepath"
            case .developerCaches: return "hammer"
            case .logs: return "doc.text"
            case .trash: return "trash"
            case .dns: return "network"
            }
        }

        var description: String {
            switch self {
            case .userCaches: return "Application caches in ~/Library/Caches"
            case .browserCaches: return "Safari, Chrome, Firefox, Edge caches"
            case .systemTemp: return "Temporary files in /var/tmp"
            case .developerCaches: return "Xcode, CocoaPods, npm caches"
            case .logs: return "System and application logs"
            case .trash: return "Files in Trash"
            case .dns: return "DNS resolver cache"
            }
        }
    }

    struct CacheAnalysis: Identifiable {
        let id = UUID()
        let category: CleanupCategory
        var size: UInt64
        var itemCount: Int
    }

    var body: some View {
        HSplitView {
            // Left panel - Categories
            VStack(alignment: .leading, spacing: 16) {
                Text("Cleanup Categories")
                    .font(.headline)

                ForEach(CleanupCategory.allCases) { category in
                    CleanupCategoryRow(
                        category: category,
                        isSelected: selectedCategories.contains(category),
                        analysis: cacheAnalysis.first { $0.category == category }
                    ) {
                        if selectedCategories.contains(category) {
                            selectedCategories.remove(category)
                        } else {
                            selectedCategories.insert(category)
                        }
                    }
                }

                Spacer()

                HStack {
                    Button("Select All") {
                        selectedCategories = Set(CleanupCategory.allCases)
                    }
                    .buttonStyle(.borderless)

                    Button("Select None") {
                        selectedCategories.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding()
            .frame(minWidth: 300)

            // Right panel - Actions
            VStack(spacing: 24) {
                // Analysis results
                if !cacheAnalysis.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Analysis Results")
                            .font(.headline)

                        let totalSize = cacheAnalysis.reduce(0) { $0 + $1.size }
                        let selectedSize = cacheAnalysis
                            .filter { selectedCategories.contains($0.category) }
                            .reduce(0) { $0 + $1.size }

                        HStack(spacing: 24) {
                            VStack {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file))
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("Total Found")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(selectedSize), countStyle: .file))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                                Text("Selected to Clean")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        Task { @MainActor in
                            await analyzeSystem()
                        }
                    } label: {
                        HStack {
                            if isAnalyzing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "magnifyingglass")
                            }
                            Text(isAnalyzing ? "Analyzing..." : "Analyze System")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                    .disabled(isAnalyzing)

                    Button {
                        Task { @MainActor in
                            await performCleanup()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Clean Selected (\(selectedCategories.count))")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(selectedCategories.isEmpty || appState.isLoading)
                }
            }
            .padding()
            .frame(minWidth: 300)
        }
        .navigationTitle("Cleanup")
    }

    // MARK: - Actions

    private func analyzeSystem() async {
        isAnalyzing = true
        cacheAnalysis.removeAll()

        let executor = CommandExecutor.shared

        for category in CleanupCategory.allCases {
            var size: UInt64 = 0
            let count = 0

            switch category {
            case .userCaches:
                if let result = try? await executor.execute("du -sk ~/Library/Caches 2>/dev/null | cut -f1") {
                    size = (UInt64(result.output.trimmingCharacters(in: .whitespaces)) ?? 0) * 1024
                }
            case .browserCaches:
                let paths = [
                    "~/Library/Caches/com.apple.Safari",
                    "~/Library/Caches/Google/Chrome",
                    "~/Library/Caches/Firefox"
                ]
                for path in paths {
                    if let result = try? await executor.execute("du -sk \(path) 2>/dev/null | cut -f1") {
                        size += (UInt64(result.output.trimmingCharacters(in: .whitespaces)) ?? 0) * 1024
                    }
                }
            case .systemTemp:
                if let result = try? await executor.execute("du -sk /private/var/tmp 2>/dev/null | cut -f1") {
                    size = (UInt64(result.output.trimmingCharacters(in: .whitespaces)) ?? 0) * 1024
                }
            case .developerCaches:
                if let result = try? await executor.execute("du -sk ~/Library/Developer/Xcode/DerivedData 2>/dev/null | cut -f1") {
                    size = (UInt64(result.output.trimmingCharacters(in: .whitespaces)) ?? 0) * 1024
                }
            case .logs:
                if let result = try? await executor.execute("du -sk ~/Library/Logs 2>/dev/null | cut -f1") {
                    size = (UInt64(result.output.trimmingCharacters(in: .whitespaces)) ?? 0) * 1024
                }
            case .trash:
                if let result = try? await executor.execute("du -sk ~/.Trash 2>/dev/null | cut -f1") {
                    size = (UInt64(result.output.trimmingCharacters(in: .whitespaces)) ?? 0) * 1024
                }
            case .dns:
                size = 1024 * 1024 // Estimated 1MB for DNS cache
            }

            cacheAnalysis.append(CacheAnalysis(category: category, size: size, itemCount: count))
        }

        isAnalyzing = false
    }

    private func performCleanup() async {
        let executor = CommandExecutor.shared

        for category in selectedCategories {
            switch category {
            case .userCaches:
                _ = try? await executor.execute("rm -rf ~/Library/Caches/* 2>/dev/null")
            case .browserCaches:
                _ = try? await executor.execute("rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null")
                _ = try? await executor.execute("rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null")
                _ = try? await executor.execute("rm -rf ~/Library/Caches/Firefox/* 2>/dev/null")
            case .systemTemp:
                _ = try? await executor.executePrivileged("rm -rf /private/var/tmp/* 2>/dev/null")
            case .developerCaches:
                _ = try? await executor.execute("rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null")
            case .logs:
                _ = try? await executor.execute("rm -rf ~/Library/Logs/* 2>/dev/null")
            case .trash:
                _ = try? await executor.execute("rm -rf ~/.Trash/* 2>/dev/null")
            case .dns:
                _ = try? await executor.executePrivileged("dscacheutil -flushcache && killall -HUP mDNSResponder 2>/dev/null")
            }
        }

        appState.showAlertMessage("Cleanup completed for \(selectedCategories.count) categories")
        await appState.updateMetrics()

        // Re-analyze
        await analyzeSystem()
    }
}

// MARK: - Category Row

struct CleanupCategoryRow: View {
    let category: CleanupView.CleanupCategory
    let isSelected: Bool
    let analysis: CleanupView.CacheAnalysis?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Image(systemName: category.icon)
                    .frame(width: 24)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .fontWeight(.medium)
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let analysis = analysis {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(analysis.size), countStyle: .file))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(analysis.size > 100_000_000 ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CleanupView()
        .environmentObject(AppState.shared)
        .frame(width: 800, height: 600)
}
