// File: CraigOClean-vNext/CraigOClean/PrivilegedHelper/HelperTool/main.swift
// Craig-O-Clean - Privileged Helper Tool
// Stub implementation of the privileged helper daemon

import Foundation

/// NOTE: This is a STUB implementation for architecture demonstration.
/// The actual helper tool needs to be a separate target with:
/// - Proper code signing
/// - Embedded launchd plist
/// - SMAuthorizedClients configuration
/// - Sandboxing disabled (runs as root)

// MARK: - Helper Delegate

class HelperToolDelegate: NSObject, NSXPCListenerDelegate, HelperProtocol {

    // MARK: - NSXPCListenerDelegate

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Verify the connecting client's code signature
        // In production, validate that the client is signed by your team

        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self
        connection.resume()

        return true
    }

    // MARK: - HelperProtocol

    func getVersion(reply: @escaping (String) -> Void) {
        reply(HelperConstants.currentVersion)
    }

    func isReady(reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func deleteFiles(atPaths paths: [String], reply: @escaping (Bool, String?) -> Void) {
        var errors: [String] = []

        for path in paths {
            do {
                try FileManager.default.removeItem(atPath: path)
                NSLog("Deleted: \(path)")
            } catch {
                errors.append("\(path): \(error.localizedDescription)")
                NSLog("Failed to delete \(path): \(error)")
            }
        }

        if errors.isEmpty {
            reply(true, nil)
        } else {
            reply(false, errors.joined(separator: "; "))
        }
    }

    func calculateDirectorySize(atPath path: String, reply: @escaping (UInt64) -> Void) {
        var totalSize: UInt64 = 0

        if let enumerator = FileManager.default.enumerator(atPath: path) {
            while let file = enumerator.nextObject() as? String {
                let fullPath = (path as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? UInt64 {
                    totalSize += size
                }
            }
        }

        reply(totalSize)
    }

    func listDirectory(atPath path: String, reply: @escaping (Data?) -> Void) {
        var items: [[String: Any]] = []

        if let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            while let url = enumerator.nextObject() as? URL {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    items.append([
                        "path": url.path,
                        "size": size
                    ])
                }
            }
        }

        reply(try? JSONSerialization.data(withJSONObject: items))
    }

    func clearSystemCaches(reply: @escaping (UInt64, String?) -> Void) {
        // Clear various system caches
        let cachePaths = [
            "/Library/Caches",
            "/System/Library/Caches"
        ]

        var totalFreed: UInt64 = 0
        var errors: [String] = []

        for cachePath in cachePaths {
            let url = URL(fileURLWithPath: cachePath)

            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey]
            ) else {
                continue
            }

            for item in contents {
                do {
                    let size = try item.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    try FileManager.default.removeItem(at: item)
                    totalFreed += UInt64(size)
                    NSLog("Cleared cache: \(item.path)")
                } catch {
                    errors.append(error.localizedDescription)
                }
            }
        }

        reply(totalFreed, errors.isEmpty ? nil : errors.joined(separator: "; "))
    }

    func flushDNSCache(reply: @escaping (Bool) -> Void) {
        // Execute dscacheutil -flushcache
        let task = Process()
        task.launchPath = "/usr/bin/dscacheutil"
        task.arguments = ["-flushcache"]

        do {
            try task.run()
            task.waitUntilExit()
            reply(task.terminationStatus == 0)
        } catch {
            NSLog("Failed to flush DNS: \(error)")
            reply(false)
        }
    }

    func uninstallHelper(reply: @escaping (Bool) -> Void) {
        // Remove helper files
        do {
            try FileManager.default.removeItem(atPath: HelperConstants.helperToolLocation)
            try FileManager.default.removeItem(atPath: HelperConstants.launchdPlistLocation)

            // Unload from launchd
            let task = Process()
            task.launchPath = "/bin/launchctl"
            task.arguments = ["remove", HelperConstants.machServiceName]
            try task.run()
            task.waitUntilExit()

            reply(true)
        } catch {
            NSLog("Failed to uninstall: \(error)")
            reply(false)
        }
    }
}

// MARK: - Main Entry Point

/// NOTE: In production, uncomment the following to run as XPC service
/*
let delegate = HelperToolDelegate()
let listener = NSXPCListener(machServiceName: HelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()

NSLog("Craig-O-Clean Helper started")
RunLoop.main.run()
*/

// For now, just print stub message
print("""
Craig-O-Clean Privileged Helper Tool (STUB)

This is a stub implementation. To create a working helper:

1. Create a separate Xcode target for the helper tool
2. Configure code signing with your team ID
3. Create embedded Info.plist with SMAuthorizedClients
4. Create embedded launchd.plist
5. Add to main app's Info.plist as SMPrivilegedExecutables
6. Use SMJobBless to install

See docs/privileged-helper.md for detailed instructions.
""")
