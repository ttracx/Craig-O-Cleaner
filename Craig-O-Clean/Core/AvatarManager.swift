import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Manages user avatar image upload, local persistence, and iCloud sync
@Observable
class AvatarManager {
    static let shared = AvatarManager()

    // MARK: - Properties

    /// Current avatar image data
    private(set) var avatarImageData: Data?

    /// Avatar image as NSImage for display
    var avatarImage: NSImage? {
        guard let data = avatarImageData else { return nil }
        return NSImage(data: data)
    }

    // MARK: - Storage Keys

    private let localStorageKey = "com.craigoclean.avatar.imageData"
    private let iCloudStorageKey = "avatarImageData"

    // MARK: - Initialization

    private init() {
        loadAvatar()
        observeICloudChanges()
    }

    // MARK: - Public Methods

    /// Load avatar from persistent storage (local + iCloud)
    func loadAvatar() {
        // Try iCloud first (most up-to-date)
        if let iCloudData = loadFromICloud() {
            avatarImageData = iCloudData
            // Sync to local storage
            saveToLocalStorage(iCloudData)
            return
        }

        // Fallback to local storage
        if let localData = loadFromLocalStorage() {
            avatarImageData = localData
            // Sync to iCloud
            saveToICloud(localData)
        }
    }

    /// Save new avatar image
    func saveAvatar(_ imageData: Data) async throws {
        // Validate image data
        guard NSImage(data: imageData) != nil else {
            throw AvatarError.invalidImageData
        }

        // Compress if needed (limit to 2MB)
        let compressedData = try compressImageIfNeeded(imageData)

        // Update in-memory
        avatarImageData = compressedData

        // Save to local storage
        saveToLocalStorage(compressedData)

        // Save to iCloud
        saveToICloud(compressedData)
    }

    /// Delete avatar
    func deleteAvatar() {
        avatarImageData = nil

        // Remove from local storage
        UserDefaults.standard.removeObject(forKey: localStorageKey)

        // Remove from iCloud
        NSUbiquitousKeyValueStore.default.removeObject(forKey: iCloudStorageKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    // MARK: - Image Selection

    /// Open file picker to select avatar image
    func selectAvatarImage(completion: @escaping (Result<Data, Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .png, .jpeg, .heic]
        panel.message = "Select a profile picture"
        panel.prompt = "Choose"

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(.failure(AvatarError.userCancelled))
                return
            }

            do {
                let data = try Data(contentsOf: url)
                completion(.success(data))
            } catch {
                completion(.failure(AvatarError.failedToReadFile))
            }
        }
    }

    // MARK: - Private Methods - Local Storage

    private func loadFromLocalStorage() -> Data? {
        return UserDefaults.standard.data(forKey: localStorageKey)
    }

    private func saveToLocalStorage(_ data: Data) {
        UserDefaults.standard.set(data, forKey: localStorageKey)
    }

    // MARK: - Private Methods - iCloud Storage

    private func loadFromICloud() -> Data? {
        return NSUbiquitousKeyValueStore.default.data(forKey: iCloudStorageKey)
    }

    private func saveToICloud(_ data: Data) {
        NSUbiquitousKeyValueStore.default.set(data, forKey: iCloudStorageKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private func observeICloudChanges() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] notification in
            self?.handleICloudChange(notification)
        }
    }

    private func handleICloudChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
              changedKeys.contains(iCloudStorageKey) else {
            return
        }

        // Avatar changed in iCloud, reload
        if let iCloudData = loadFromICloud() {
            avatarImageData = iCloudData
            saveToLocalStorage(iCloudData)
        }
    }

    // MARK: - Image Compression

    private func compressImageIfNeeded(_ data: Data) throws -> Data {
        let maxSize: Int = 2 * 1024 * 1024 // 2MB

        guard data.count > maxSize else {
            return data
        }

        guard let image = NSImage(data: data) else {
            throw AvatarError.invalidImageData
        }

        // Calculate compression ratio
        let compressionRatio = Double(maxSize) / Double(data.count)
        let quality = max(0.1, min(1.0, compressionRatio))

        // Convert to JPEG with compression
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let compressedData = bitmapImage.representation(
                using: .jpeg,
                properties: [.compressionFactor: quality]
              ) else {
            throw AvatarError.compressionFailed
        }

        return compressedData
    }
}

// MARK: - Errors

enum AvatarError: LocalizedError {
    case invalidImageData
    case userCancelled
    case failedToReadFile
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The selected file is not a valid image."
        case .userCancelled:
            return "Image selection was cancelled."
        case .failedToReadFile:
            return "Failed to read the selected file."
        case .compressionFailed:
            return "Failed to compress the image."
        }
    }
}
