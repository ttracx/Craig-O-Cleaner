// MARK: - HelperMain.swift
// CraigOCleanHelper - Privileged Helper Tool Entry Point
// Main entry point for the SMJobBless-installed privileged helper

import Foundation
import os.log

// MARK: - Main Entry Point

/// Main entry point for the CraigOCleanHelper privileged tool
/// This helper is installed via SMJobBless and runs as root to execute
/// privileged operations like sync and purge

@main
struct HelperMain {
    static func main() {
        let logger = Logger(subsystem: kHelperToolMachServiceName, category: "Main")

        logger.info("CraigOCleanHelper starting...")

        // Create the XPC listener delegate
        let delegate = HelperXPCDelegate()

        // Create and configure the XPC listener
        // This uses the Mach service name specified in the launchd plist
        let listener = NSXPCListener(machServiceName: kHelperToolMachServiceName)
        listener.delegate = delegate

        logger.info("Starting XPC listener on \(kHelperToolMachServiceName)")

        // Resume the listener to start accepting connections
        listener.resume()

        // Run the run loop to keep the helper alive
        // The helper will exit when launchd terminates it
        logger.info("CraigOCleanHelper ready and waiting for connections")
        RunLoop.current.run()

        // This point should never be reached
        logger.info("CraigOCleanHelper exiting")
    }
}
