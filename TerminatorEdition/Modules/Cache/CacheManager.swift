import Foundation

// MARK: - Cache Manager
/// Comprehensive cache cleaning for macOS Silicon
/// Handles user caches, system caches, browser caches, and developer caches

@MainActor
public final class CacheManager: ObservableObject {

    // MARK: - Types

    public enum CacheCategory: String, CaseIterable, Sendable {
        case user = "User Caches"
        case system = "System Caches"
        case browser = "Browser Caches"
        case developer = "Developer Caches"
        case application = "Application Caches"
        case dns = "DNS Cache"
        case font = "Font Caches"
    }

    public struct CacheLocation: Identifiable, Sendable {
        public let id = UUID()
        public let name: String
        public let path: String
        public let category: CacheCategory
        public let safeToDelete: Bool
        public let description: String
    }

    public struct CacheInfo: Sendable {
        public let location: CacheLocation
        public let sizeBytes: UInt64
        public let fileCount: Int
        public let lastModified: Date?

        public var sizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
        }
    }

    public struct CacheCleanupResult {
        public let spaceFreed: UInt64
        public let cacheCount: Int
        public let errors: [String]
        public let duration: TimeInterval

        public var summary: String {
            let freed = ByteCountFormatter.string(fromByteCount: Int64(spaceFreed), countStyle: .file)
            return "Cleared \(cacheCount) caches, freed \(freed) in \(String(format: "%.1f", duration))s"
        }
    }

    // MARK: - Properties

    private let executor = CommandExecutor.shared

    @Published public private(set) var cacheInfos: [CacheInfo] = []
    @Published public private(set) var totalCacheSize: UInt64 = 0

    // MARK: - Cache Locations

    public static let userCaches: [CacheLocation] = [
        CacheLocation(
            name: "User Caches",
            path: "~/Library/Caches",
            category: .user,
            safeToDelete: true,
            description: "Application caches for current user"
        ),
        CacheLocation(
            name: "Temporary Items",
            path: "~/Library/Caches/TemporaryItems",
            category: .user,
            safeToDelete: true,
            description: "Temporary files created by apps"
        ),
        CacheLocation(
            name: "Metadata Cache",
            path: "~/Library/Caches/Metadata",
            category: .user,
            safeToDelete: true,
            description: "Spotlight and metadata caches"
        )
    ]

    public static let systemCaches: [CacheLocation] = [
        CacheLocation(
            name: "System Caches",
            path: "/Library/Caches",
            category: .system,
            safeToDelete: true,
            description: "System-wide application caches"
        ),
        CacheLocation(
            name: "Private Temp",
            path: "/private/var/tmp",
            category: .system,
            safeToDelete: true,
            description: "System temporary files"
        ),
        CacheLocation(
            name: "Private Folders",
            path: "/private/var/folders",
            category: .system,
            safeToDelete: true,
            description: "Per-user temporary caches"
        )
    ]

    public static let browserCaches: [CacheLocation] = [
        CacheLocation(
            name: "Safari Cache",
            path: "~/Library/Caches/com.apple.Safari",
            category: .browser,
            safeToDelete: true,
            description: "Safari browser cache"
        ),
        CacheLocation(
            name: "Safari Local Storage",
            path: "~/Library/Safari/LocalStorage",
            category: .browser,
            safeToDelete: true,
            description: "Safari local storage data"
        ),
        CacheLocation(
            name: "Chrome Cache",
            path: "~/Library/Caches/Google/Chrome",
            category: .browser,
            safeToDelete: true,
            description: "Google Chrome cache"
        ),
        CacheLocation(
            name: "Chrome Profile Cache",
            path: "~/Library/Application Support/Google/Chrome/Default/Cache",
            category: .browser,
            safeToDelete: true,
            description: "Chrome profile cache"
        ),
        CacheLocation(
            name: "Chrome Code Cache",
            path: "~/Library/Application Support/Google/Chrome/Default/Code Cache",
            category: .browser,
            safeToDelete: true,
            description: "Chrome JavaScript code cache"
        ),
        CacheLocation(
            name: "Firefox Cache",
            path: "~/Library/Caches/Firefox",
            category: .browser,
            safeToDelete: true,
            description: "Firefox browser cache"
        ),
        CacheLocation(
            name: "Firefox Profile Cache",
            path: "~/Library/Application Support/Firefox/Profiles/*/cache2",
            category: .browser,
            safeToDelete: true,
            description: "Firefox profile caches"
        ),
        CacheLocation(
            name: "Edge Cache",
            path: "~/Library/Caches/Microsoft Edge",
            category: .browser,
            safeToDelete: true,
            description: "Microsoft Edge cache"
        ),
        CacheLocation(
            name: "Brave Cache",
            path: "~/Library/Caches/BraveSoftware",
            category: .browser,
            safeToDelete: true,
            description: "Brave Browser cache"
        ),
        CacheLocation(
            name: "Arc Cache",
            path: "~/Library/Caches/company.thebrowser.Browser",
            category: .browser,
            safeToDelete: true,
            description: "Arc browser cache"
        ),
        CacheLocation(
            name: "Opera Cache",
            path: "~/Library/Caches/com.operasoftware.Opera",
            category: .browser,
            safeToDelete: true,
            description: "Opera browser cache"
        )
    ]

    public static let developerCaches: [CacheLocation] = [
        CacheLocation(
            name: "Xcode Derived Data",
            path: "~/Library/Developer/Xcode/DerivedData",
            category: .developer,
            safeToDelete: true,
            description: "Xcode build artifacts and indexes"
        ),
        CacheLocation(
            name: "Xcode Archives",
            path: "~/Library/Developer/Xcode/Archives",
            category: .developer,
            safeToDelete: true,
            description: "Old Xcode archives"
        ),
        CacheLocation(
            name: "iOS Device Support",
            path: "~/Library/Developer/Xcode/iOS DeviceSupport",
            category: .developer,
            safeToDelete: true,
            description: "iOS device symbols"
        ),
        CacheLocation(
            name: "CoreSimulator Caches",
            path: "~/Library/Developer/CoreSimulator/Caches",
            category: .developer,
            safeToDelete: true,
            description: "iOS Simulator caches"
        ),
        CacheLocation(
            name: "CocoaPods Cache",
            path: "~/Library/Caches/CocoaPods",
            category: .developer,
            safeToDelete: true,
            description: "CocoaPods package cache"
        ),
        CacheLocation(
            name: "Homebrew Cache",
            path: "~/Library/Caches/Homebrew",
            category: .developer,
            safeToDelete: true,
            description: "Homebrew package cache"
        ),
        CacheLocation(
            name: "npm Cache",
            path: "~/.npm/_cacache",
            category: .developer,
            safeToDelete: true,
            description: "npm package cache"
        ),
        CacheLocation(
            name: "Yarn Cache",
            path: "~/Library/Caches/Yarn",
            category: .developer,
            safeToDelete: true,
            description: "Yarn package cache"
        ),
        CacheLocation(
            name: "pip Cache",
            path: "~/Library/Caches/pip",
            category: .developer,
            safeToDelete: true,
            description: "Python pip cache"
        ),
        CacheLocation(
            name: "Gradle Cache",
            path: "~/.gradle/caches",
            category: .developer,
            safeToDelete: true,
            description: "Gradle build cache"
        )
    ]

    public static let applicationCaches: [CacheLocation] = [
        CacheLocation(
            name: "Slack Cache",
            path: "~/Library/Application Support/Slack/Cache",
            category: .application,
            safeToDelete: true,
            description: "Slack application cache"
        ),
        CacheLocation(
            name: "Discord Cache",
            path: "~/Library/Application Support/discord/Cache",
            category: .application,
            safeToDelete: true,
            description: "Discord application cache"
        ),
        CacheLocation(
            name: "VS Code Cache",
            path: "~/Library/Application Support/Code/Cache",
            category: .application,
            safeToDelete: true,
            description: "Visual Studio Code cache"
        ),
        CacheLocation(
            name: "Spotify Cache",
            path: "~/Library/Application Support/Spotify/PersistentCache",
            category: .application,
            safeToDelete: true,
            description: "Spotify music cache"
        ),
        CacheLocation(
            name: "Docker Cache",
            path: "~/Library/Containers/com.docker.docker/Data/vms",
            category: .application,
            safeToDelete: true,
            description: "Docker VM images"
        )
    ]

    public static var allCacheLocations: [CacheLocation] {
        userCaches + systemCaches + browserCaches + developerCaches + applicationCaches
    }

    // MARK: - Cache Analysis

    /// Analyze all caches and get their sizes
    public func analyzeAllCaches() async -> [CacheInfo] {
        var infos: [CacheInfo] = []

        for location in Self.allCacheLocations {
            if let info = await analyzeCacheLocation(location) {
                infos.append(info)
            }
        }

        cacheInfos = infos.sorted { $0.sizeBytes > $1.sizeBytes }
        totalCacheSize = infos.reduce(0) { $0 + $1.sizeBytes }

        return cacheInfos
    }

    /// Analyze a specific cache location
    public func analyzeCacheLocation(_ location: CacheLocation) async -> CacheInfo? {
        let expandedPath = (location.path as NSString).expandingTildeInPath

        // Handle wildcard paths
        let pathsToCheck: [String]
        if location.path.contains("*") {
            let baseDir = (location.path.components(separatedBy: "*").first ?? "") as NSString
            let expandedBase = baseDir.expandingTildeInPath
            let result = try? await executor.execute("ls -d \(expandedBase)* 2>/dev/null")
            pathsToCheck = result?.output.components(separatedBy: .newlines).filter { !$0.isEmpty } ?? []
        } else {
            pathsToCheck = [expandedPath]
        }

        var totalSize: UInt64 = 0
        var totalFiles = 0

        for path in pathsToCheck {
            // Get size
            let sizeResult = try? await executor.execute("du -sk \"\(path)\" 2>/dev/null | cut -f1")
            if let sizeStr = sizeResult?.output.trimmingCharacters(in: .whitespacesAndNewlines),
               let sizeKB = UInt64(sizeStr) {
                totalSize += sizeKB * 1024
            }

            // Get file count
            let countResult = try? await executor.execute("find \"\(path)\" -type f 2>/dev/null | wc -l")
            if let countStr = countResult?.output.trimmingCharacters(in: .whitespacesAndNewlines),
               let count = Int(countStr) {
                totalFiles += count
            }
        }

        guard totalSize > 0 || totalFiles > 0 else { return nil }

        return CacheInfo(
            location: location,
            sizeBytes: totalSize,
            fileCount: totalFiles,
            lastModified: nil
        )
    }

    /// Get total cache size
    public func getTotalCacheSize() async -> UInt64 {
        _ = await analyzeAllCaches()
        return totalCacheSize
    }

    // MARK: - Cache Cleaning

    /// Clear all caches
    public func clearAllCaches(
        includeSystem: Bool = false,
        includeBrowsers: Bool = true,
        includeDeveloper: Bool = true
    ) async throws -> CacheCleanupResult {

        let startTime = Date()
        var spaceFreed: UInt64 = 0
        var cacheCount = 0
        var errors: [String] = []

        // User caches (always safe)
        for location in Self.userCaches {
            let result = await clearCacheLocation(location)
            spaceFreed += result.freed
            if result.freed > 0 { cacheCount += 1 }
            if let error = result.error { errors.append(error) }
        }

        // System caches (optional, requires sudo for some)
        if includeSystem {
            for location in Self.systemCaches {
                let result = await clearCacheLocation(location, useSudo: true)
                spaceFreed += result.freed
                if result.freed > 0 { cacheCount += 1 }
                if let error = result.error { errors.append(error) }
            }
        }

        // Browser caches
        if includeBrowsers {
            for location in Self.browserCaches {
                let result = await clearCacheLocation(location)
                spaceFreed += result.freed
                if result.freed > 0 { cacheCount += 1 }
                if let error = result.error { errors.append(error) }
            }
        }

        // Developer caches
        if includeDeveloper {
            for location in Self.developerCaches {
                let result = await clearCacheLocation(location)
                spaceFreed += result.freed
                if result.freed > 0 { cacheCount += 1 }
                if let error = result.error { errors.append(error) }
            }
        }

        let duration = Date().timeIntervalSince(startTime)

        return CacheCleanupResult(
            spaceFreed: spaceFreed,
            cacheCount: cacheCount,
            errors: errors,
            duration: duration
        )
    }

    /// Clear user caches only
    public func clearUserCaches() async throws -> CacheCleanupResult {
        return try await clearAllCaches(
            includeSystem: false,
            includeBrowsers: false,
            includeDeveloper: false
        )
    }

    /// Clear browser caches only
    public func clearBrowserCaches() async throws -> CacheCleanupResult {
        let startTime = Date()
        var spaceFreed: UInt64 = 0
        var cacheCount = 0
        var errors: [String] = []

        for location in Self.browserCaches {
            let result = await clearCacheLocation(location)
            spaceFreed += result.freed
            if result.freed > 0 { cacheCount += 1 }
            if let error = result.error { errors.append(error) }
        }

        return CacheCleanupResult(
            spaceFreed: spaceFreed,
            cacheCount: cacheCount,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Clear developer caches only
    public func clearDeveloperCaches() async throws -> CacheCleanupResult {
        let startTime = Date()
        var spaceFreed: UInt64 = 0
        var cacheCount = 0
        var errors: [String] = []

        for location in Self.developerCaches {
            let result = await clearCacheLocation(location)
            spaceFreed += result.freed
            if result.freed > 0 { cacheCount += 1 }
            if let error = result.error { errors.append(error) }
        }

        // Also run package manager cleanup commands
        _ = try? await executor.execute("npm cache clean --force 2>/dev/null")
        _ = try? await executor.execute("yarn cache clean 2>/dev/null")
        _ = try? await executor.execute("pip cache purge 2>/dev/null")
        _ = try? await executor.execute("brew cleanup -s 2>/dev/null")

        return CacheCleanupResult(
            spaceFreed: spaceFreed,
            cacheCount: cacheCount,
            errors: errors,
            duration: Date().timeIntervalSince(startTime)
        )
    }

    /// Clear a specific cache location
    public func clearCacheLocation(_ location: CacheLocation, useSudo: Bool = false) async -> (freed: UInt64, error: String?) {
        let expandedPath = (location.path as NSString).expandingTildeInPath

        // Get size before
        let beforeSize = await getCacheSize(path: expandedPath)

        // Clear the cache
        let command = useSudo ?
            "sudo rm -rf \"\(expandedPath)\"/* 2>/dev/null" :
            "rm -rf \"\(expandedPath)\"/* 2>/dev/null"

        let result = try? await executor.execute(command)

        // Calculate space freed
        let afterSize = await getCacheSize(path: expandedPath)
        let freed = beforeSize > afterSize ? beforeSize - afterSize : 0

        let error = result?.isSuccess == false ? result?.error : nil

        return (freed, error)
    }

    /// Flush DNS cache
    public func flushDNSCache() async throws {
        _ = try await executor.executePrivileged(
            "dscacheutil -flushcache && killall -HUP mDNSResponder"
        )
    }

    /// Clear font caches
    public func clearFontCaches() async throws {
        _ = try await executor.execute("atsutil databases -remove 2>/dev/null")
        _ = try await executor.executePrivileged("atsutil databases -removeUser 2>/dev/null")
        _ = try await executor.executePrivileged("atsutil server -shutdown && atsutil server -ping")
    }

    // MARK: - Helpers

    private func getCacheSize(path: String) async -> UInt64 {
        let result = try? await executor.execute("du -sk \"\(path)\" 2>/dev/null | cut -f1")
        guard let sizeStr = result?.output.trimmingCharacters(in: .whitespacesAndNewlines),
              let sizeKB = UInt64(sizeStr) else {
            return 0
        }
        return sizeKB * 1024
    }
}

// MARK: - Cache Commands Reference

public enum CacheCommands {

    // User caches
    public static let clearUserCaches = "rm -rf ~/Library/Caches/*"
    public static let clearTempItems = "rm -rf ~/Library/Caches/TemporaryItems/*"

    // System caches
    public static let clearSystemCaches = "sudo rm -rf /Library/Caches/*"
    public static let clearPrivateTmp = "sudo rm -rf /private/var/tmp/*"
    public static let clearPrivateFolders = "sudo rm -rf /private/var/folders/*"

    // Browser caches
    public static let clearSafariCache = "rm -rf ~/Library/Caches/com.apple.Safari/*"
    public static let clearChromeCache = "rm -rf ~/Library/Caches/Google/Chrome/*"
    public static let clearFirefoxCache = "rm -rf ~/Library/Caches/Firefox/*"
    public static let clearEdgeCache = "rm -rf ~/Library/Caches/Microsoft\\ Edge/*"
    public static let clearBraveCache = "rm -rf ~/Library/Caches/BraveSoftware/*"
    public static let clearArcCache = "rm -rf ~/Library/Caches/company.thebrowser.Browser/*"

    // Developer caches
    public static let clearXcodeDerivedData = "rm -rf ~/Library/Developer/Xcode/DerivedData/*"
    public static let clearXcodeArchives = "rm -rf ~/Library/Developer/Xcode/Archives/*"
    public static let clearSimulatorCaches = "rm -rf ~/Library/Developer/CoreSimulator/Caches/*"
    public static let clearHomebrewCache = "rm -rf ~/Library/Caches/Homebrew/*"

    // Package manager cleanup
    public static let cleanNpm = "npm cache clean --force"
    public static let cleanYarn = "yarn cache clean"
    public static let cleanPip = "pip cache purge"
    public static let cleanBrew = "brew cleanup -s && brew autoremove"

    // DNS cache
    public static let flushDNS = "sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"

    // Font caches
    public static let clearFontCaches = "atsutil databases -remove && sudo atsutil databases -removeUser"
}
