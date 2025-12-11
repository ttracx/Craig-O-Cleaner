import Foundation
import SwiftUI

@MainActor
final class LocalUserStore: ObservableObject {
    static let shared = LocalUserStore()

    @Published private(set) var profile: UserProfile?

    private let fileURL: URL

    private init() {
        // Application Support/<bundle-id>/user_profile.json
        let bundleId = Bundle.main.bundleIdentifier ?? "Craig-O-Clean"
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = baseDir.appendingPathComponent(bundleId, isDirectory: true)
        self.fileURL = appDir.appendingPathComponent("user_profile.json")

        loadFromDisk()
    }

    func setProfile(_ newProfile: UserProfile?) {
        profile = newProfile
        persistToDisk()
    }

    func updateProfile(_ mutate: (inout UserProfile) -> Void) {
        guard var existing = profile else { return }
        mutate(&existing)
        profile = existing
        persistToDisk()
    }

    private func loadFromDisk() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(UserProfile.self, from: data)
            profile = decoded
        } catch {
            // First run or unreadable file: treat as signed out.
            profile = nil
        }
    }

    private func persistToDisk() {
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            if let profile {
                let data = try JSONEncoder().encode(profile)
                try data.write(to: fileURL, options: [.atomic])
            } else {
                try? FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            // Avoid crashing on persistence issues.
            print("LocalUserStore: failed to persist profile: \(error)")
        }
    }
}

