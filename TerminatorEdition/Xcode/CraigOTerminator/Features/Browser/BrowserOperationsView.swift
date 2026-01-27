//
//  BrowserOperationsView.swift
//  CraigOTerminator
//
//  Created by Claude Code on 1/27/26.
//  Copyright © 2026 NeuralQuantum.ai / VibeCaaS. All rights reserved.
//

import SwiftUI

// MARK: - Browser Operations View

/// Main view for browser management operations
struct BrowserOperationsView: View {
    @State private var browserManager = BrowserManager()
    @State private var selectedBrowser: BrowserApp?
    @State private var showingPatternInput = false
    @State private var urlPattern = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isOperationInProgress = false
    @State private var operationResult = ""
    @State private var showingResult = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Browser list
            ScrollView {
                VStack(spacing: 12) {
                    if browserManager.browsers.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(browserManager.browsers) { browser in
                            BrowserRow(
                                browser: browser,
                                onSelectBrowser: { selectedBrowser = browser.app },
                                onCloseTabs: { handleCloseHeavyTabs(browser.app) },
                                onQuit: { handleQuit(browser.app) }
                            )
                        }
                    }
                }
                .padding()
            }

            // Actions footer
            if selectedBrowser != nil {
                Divider()
                actionsFooter
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .task {
            await browserManager.refreshAll()
        }
        .sheet(isPresented: $showingPatternInput) {
            patternInputSheet
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Operation Complete", isPresented: $showingResult) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(operationResult)
        }
        .overlay {
            if isOperationInProgress {
                ProgressView("Processing...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            Image(systemName: "safari")
                .font(.title2)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Browser Management")
                    .font(.headline)

                Text("\(browserManager.browsers.count) browser(s) installed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await browserManager.refreshAll()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .disabled(browserManager.isRefreshing)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "safari")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Browsers Found")
                .font(.headline)

            Text("Install Safari, Chrome, Edge, Brave, Arc, or Firefox to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions Footer

    private var actionsFooter: some View {
        VStack(spacing: 12) {
            if let browser = selectedBrowser {
                Text("Selected: \(browser.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Close Heavy Tabs") {
                        handleCloseHeavyTabs(browser)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Close by Pattern...") {
                        showingPatternInput = true
                    }
                    .buttonStyle(.bordered)

                    Button("Close All Tabs") {
                        handleCloseAllTabs(browser)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.regular)
            }
        }
        .padding()
    }

    // MARK: - Pattern Input Sheet

    private var patternInputSheet: some View {
        VStack(spacing: 20) {
            Text("Close Tabs by URL Pattern")
                .font(.headline)

            TextField("Enter URL pattern (e.g., youtube.com)", text: $urlPattern)
                .textFieldStyle(.roundedBorder)

            Text("All tabs containing this pattern in their URL will be closed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button("Cancel") {
                    showingPatternInput = false
                    urlPattern = ""
                }
                .buttonStyle(.bordered)

                Button("Close Tabs") {
                    if let browser = selectedBrowser {
                        handleCloseByPattern(browser, pattern: urlPattern)
                    }
                    showingPatternInput = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(urlPattern.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    // MARK: - Action Handlers

    private func handleCloseHeavyTabs(_ browser: BrowserApp) {
        Task {
            isOperationInProgress = true

            do {
                // Check permission first
                guard browserManager.hasPermission(for: browser) else {
                    await browserManager.requestPermission(for: browser)
                    isOperationInProgress = false
                    return
                }

                let count = try await browserManager.closeHeavyTabs(in: browser)

                operationResult = "Closed \(count) heavy tab(s) in \(browser.rawValue)"
                showingResult = true

                // Refresh browser info
                await browserManager.refreshAll()
            } catch let error as BrowserError {
                errorMessage = error.localizedDescription
                showingError = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isOperationInProgress = false
        }
    }

    private func handleCloseByPattern(_ browser: BrowserApp, pattern: String) {
        Task {
            isOperationInProgress = true

            do {
                // Check permission first
                guard browserManager.hasPermission(for: browser) else {
                    await browserManager.requestPermission(for: browser)
                    isOperationInProgress = false
                    return
                }

                let count = try await browserManager.closeTabs(in: browser, matching: pattern)

                operationResult = "Closed \(count) tab(s) matching '\(pattern)' in \(browser.rawValue)"
                showingResult = true

                // Refresh browser info
                await browserManager.refreshAll()
            } catch let error as BrowserError {
                errorMessage = error.localizedDescription
                showingError = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isOperationInProgress = false
            urlPattern = ""
        }
    }

    private func handleCloseAllTabs(_ browser: BrowserApp) {
        Task {
            isOperationInProgress = true

            do {
                // Check permission first
                guard browserManager.hasPermission(for: browser) else {
                    await browserManager.requestPermission(for: browser)
                    isOperationInProgress = false
                    return
                }

                let count = try await browserManager.closeAllTabs(in: browser)

                operationResult = "Closed \(count) tab(s) in \(browser.rawValue)"
                showingResult = true

                // Refresh browser info
                await browserManager.refreshAll()
            } catch let error as BrowserError {
                errorMessage = error.localizedDescription
                showingError = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isOperationInProgress = false
        }
    }

    private func handleQuit(_ browser: BrowserApp) {
        Task {
            isOperationInProgress = true

            do {
                try await browserManager.quit(browser)

                operationResult = "Quit \(browser.rawValue) successfully"
                showingResult = true

                // Refresh browser info
                await browserManager.refreshAll()
            } catch let error as BrowserError {
                errorMessage = error.localizedDescription
                showingError = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }

            isOperationInProgress = false
        }
    }
}

// MARK: - Browser Row

struct BrowserRow: View {
    let browser: BrowserInfo
    let onSelectBrowser: () -> Void
    let onCloseTabs: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: browser.icon)
                .font(.title2)
                .foregroundStyle(browser.isRunning ? .blue : .secondary)
                .frame(width: 32)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(browser.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    statusBadge
                    tabCountBadge
                    permissionBadge
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if browser.isRunning && browser.tabCount > 0 {
                    Button("Close Heavy") {
                        onCloseTabs()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!browser.hasPermission)
                }

                Button("Select") {
                    onSelectBrowser()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(browser.isRunning ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(browser.isRunning ? "Running" : "Not Running")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var tabCountBadge: some View {
        Group {
            if browser.isRunning && browser.tabCount > 0 {
                Text("\(browser.tabCount) tab\(browser.tabCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private var permissionBadge: some View {
        Group {
            if !browser.hasPermission {
                Label("No Permission", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BrowserOperationsView()
}
