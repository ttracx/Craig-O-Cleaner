// MARK: - LoggingExtensions.swift
// Convenience extensions for easy logging throughout the app

import Foundation
import SwiftUI

// MARK: - View Extensions

extension View {
    /// Track a UI event when this view appears
    func trackViewAppear(_ viewName: String, metadata: [String: String] = [:]) -> some View {
        self.onAppear {
            AppLogger.shared.trackUIEvent(
                eventType: "view_appear",
                viewName: viewName,
                action: "appeared",
                metadata: metadata
            )
        }
    }
    
    /// Track a UI event when this view disappears
    func trackViewDisappear(_ viewName: String, metadata: [String: String] = [:]) -> some View {
        self.onDisappear {
            AppLogger.shared.trackUIEvent(
                eventType: "view_disappear",
                viewName: viewName,
                action: "disappeared",
                metadata: metadata
            )
        }
    }
}

// MARK: - Button Action Tracking

extension AppLogger {
    /// Track a button tap
    func trackButtonTap(viewName: String, buttonName: String, metadata: [String: String] = [:]) {
        trackUIEvent(
            eventType: "button_tap",
            viewName: viewName,
            action: buttonName,
            metadata: metadata
        )
    }
    
    /// Track a navigation event
    func trackNavigation(from: String, to: String, metadata: [String: String] = [:]) {
        trackUIEvent(
            eventType: "navigation",
            viewName: from,
            action: "navigate_to_\(to)",
            metadata: metadata
        )
    }
}

// MARK: - Error Logging Helpers

extension AppLogger {
    /// Log an error with full context
    func logError(
        _ error: Error,
        category: String,
        message: String,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.error(
            message,
            category: category,
            metadata: metadata,
            error: error
        )
    }
    
    /// Log a critical error
    func logCritical(
        _ error: Error,
        category: String,
        message: String,
        metadata: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        self.critical(
            message,
            category: category,
            metadata: metadata,
            error: error
        )
    }
}

// MARK: - Async Operation Tracking

extension AppLogger {
    /// Execute an async operation with performance tracking
    func trackAsyncOperation<T>(
        _ operation: String,
        category: String = "Async",
        metadata: [String: String] = [:],
        operationBlock: () async throws -> T
    ) async rethrows -> T {
        let tracker = startPerformanceTracking(operation: operation, metadata: metadata)
        defer { tracker.end() }
        
        do {
            let result = try await operationBlock()
            info("\(operation) completed successfully", category: category, metadata: metadata)
            return result
        } catch let caughtError {
            self.error("\(operation) failed", category: category, metadata: metadata, error: caughtError)
            throw caughtError
        }
    }
}

// MARK: - Service Integration Helpers

extension ProcessManager {
    func logOperation(_ operation: String, metadata: [String: String] = [:]) {
        AppLogger.shared.info(
            operation,
            category: "ProcessManager",
            metadata: metadata
        )
    }
}

extension MemoryOptimizerService {
    func logOperation(_ operation: String, metadata: [String: String] = [:]) {
        AppLogger.shared.info(
            operation,
            category: "MemoryOptimizer",
            metadata: metadata
        )
    }
}

extension SystemMetricsService {
    func logOperation(_ operation: String, metadata: [String: String] = [:]) {
        AppLogger.shared.info(
            operation,
            category: "SystemMetrics",
            metadata: metadata
        )
    }
}
