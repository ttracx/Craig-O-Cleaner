import Foundation

// MARK: - Automation Scheduler
/// Task scheduling and automation for macOS Silicon
/// Handles recurring tasks, triggers, and automated workflows

@MainActor
public final class AutomationScheduler: ObservableObject {

    // MARK: - Types

    public struct ScheduledTask: Identifiable, Sendable {
        public let id: UUID
        public let name: String
        public let description: String
        public let schedule: Schedule
        public let action: @Sendable () async -> Void
        public var isEnabled: Bool
        public var lastRun: Date?
        public var nextRun: Date?
        public var runCount: Int

        public enum Schedule: Sendable {
            case once(at: Date)
            case recurring(interval: TimeInterval)
            case daily(hour: Int, minute: Int)
            case weekly(dayOfWeek: Int, hour: Int, minute: Int)
            case monthly(dayOfMonth: Int, hour: Int, minute: Int)
            case onTrigger(Trigger)

            public enum Trigger: Sendable {
                case memoryPressure(threshold: Double)
                case diskSpaceLow(thresholdPercent: Double)
                case cpuHigh(threshold: Double, duration: TimeInterval)
                case batteryLow(threshold: Int)
                case networkChange
                case applicationLaunch(bundleId: String)
                case applicationQuit(bundleId: String)
            }
        }
    }

    public struct AutomationRule: Identifiable, Sendable {
        public let id: UUID
        public let name: String
        public let trigger: ScheduledTask.Schedule.Trigger
        public let actions: [AutomationAction]
        public var isEnabled: Bool
        public var lastTriggered: Date?

        public enum AutomationAction: Sendable {
            case cleanMemory
            case cleanCaches
            case cleanTemporaryFiles
            case closeBrowserTabs(memoryThresholdMB: Double)
            case killProcess(name: String)
            case runCommand(String)
            case notify(title: String, message: String)
            case executeScript(path: String)
        }
    }

    // MARK: - Properties

    @Published public private(set) var scheduledTasks: [ScheduledTask] = []
    @Published public private(set) var automationRules: [AutomationRule] = []
    @Published public private(set) var isRunning = false

    private var taskTimers: [UUID: Task<Void, Never>] = [:]
    private var triggerMonitors: [UUID: Task<Void, Never>] = [:]

    private let executor = CommandExecutor.shared

    // MARK: - Initialization

    public init() {}

    // MARK: - Task Scheduling

    /// Schedule a recurring task
    public func scheduleRecurring(
        name: String,
        description: String = "",
        interval: TimeInterval,
        action: @escaping @Sendable () async -> Void
    ) {
        let task = ScheduledTask(
            id: UUID(),
            name: name,
            description: description,
            schedule: .recurring(interval: interval),
            action: action,
            isEnabled: true,
            lastRun: nil,
            nextRun: Date().addingTimeInterval(interval),
            runCount: 0
        )

        scheduledTasks.append(task)
        startTaskTimer(task)
    }

    /// Schedule a daily task
    public func scheduleDaily(
        name: String,
        description: String = "",
        hour: Int,
        minute: Int,
        action: @escaping @Sendable () async -> Void
    ) {
        let task = ScheduledTask(
            id: UUID(),
            name: name,
            description: description,
            schedule: .daily(hour: hour, minute: minute),
            action: action,
            isEnabled: true,
            lastRun: nil,
            nextRun: calculateNextDailyRun(hour: hour, minute: minute),
            runCount: 0
        )

        scheduledTasks.append(task)
        startTaskTimer(task)
    }

    /// Schedule a one-time task
    public func scheduleOnce(
        name: String,
        description: String = "",
        at date: Date,
        action: @escaping @Sendable () async -> Void
    ) {
        let task = ScheduledTask(
            id: UUID(),
            name: name,
            description: description,
            schedule: .once(at: date),
            action: action,
            isEnabled: true,
            lastRun: nil,
            nextRun: date,
            runCount: 0
        )

        scheduledTasks.append(task)
        startTaskTimer(task)
    }

    /// Cancel a scheduled task
    public func cancelTask(id: UUID) {
        taskTimers[id]?.cancel()
        taskTimers.removeValue(forKey: id)
        scheduledTasks.removeAll { $0.id == id }
    }

    /// Cancel task by name
    public func cancelTask(name: String) {
        if let task = scheduledTasks.first(where: { $0.name == name }) {
            cancelTask(id: task.id)
        }
    }

    /// Enable/disable a task
    public func setTaskEnabled(id: UUID, enabled: Bool) {
        guard let index = scheduledTasks.firstIndex(where: { $0.id == id }) else { return }

        scheduledTasks[index].isEnabled = enabled

        if enabled {
            startTaskTimer(scheduledTasks[index])
        } else {
            taskTimers[id]?.cancel()
            taskTimers.removeValue(forKey: id)
        }
    }

    // MARK: - Automation Rules

    /// Add an automation rule
    public func addRule(_ rule: AutomationRule) {
        automationRules.append(rule)

        if rule.isEnabled {
            startTriggerMonitor(rule)
        }
    }

    /// Create memory pressure rule
    public func addMemoryPressureRule(
        name: String,
        threshold: Double = 85,
        actions: [AutomationRule.AutomationAction]
    ) {
        let rule = AutomationRule(
            id: UUID(),
            name: name,
            trigger: .memoryPressure(threshold: threshold),
            actions: actions,
            isEnabled: true,
            lastTriggered: nil
        )

        addRule(rule)
    }

    /// Create disk space rule
    public func addDiskSpaceRule(
        name: String,
        threshold: Double = 90,
        actions: [AutomationRule.AutomationAction]
    ) {
        let rule = AutomationRule(
            id: UUID(),
            name: name,
            trigger: .diskSpaceLow(thresholdPercent: threshold),
            actions: actions,
            isEnabled: true,
            lastTriggered: nil
        )

        addRule(rule)
    }

    /// Remove a rule
    public func removeRule(id: UUID) {
        triggerMonitors[id]?.cancel()
        triggerMonitors.removeValue(forKey: id)
        automationRules.removeAll { $0.id == id }
    }

    // MARK: - Predefined Automations

    /// Set up default maintenance automation
    public func setupDefaultAutomation() {
        // Daily memory cleanup at 3 AM
        scheduleDaily(
            name: "daily_memory_cleanup",
            description: "Purge inactive memory daily",
            hour: 3,
            minute: 0
        ) {
            _ = try? await MemoryManager().purgeInactiveMemory()
        }

        // Weekly cache cleanup on Sunday at 4 AM
        let task = ScheduledTask(
            id: UUID(),
            name: "weekly_cache_cleanup",
            description: "Clear user caches weekly",
            schedule: .weekly(dayOfWeek: 1, hour: 4, minute: 0),
            action: {
                _ = try? await CacheManager().clearUserCaches()
            },
            isEnabled: true,
            lastRun: nil,
            nextRun: calculateNextWeeklyRun(dayOfWeek: 1, hour: 4, minute: 0),
            runCount: 0
        )
        scheduledTasks.append(task)
        startTaskTimer(task)

        // Memory pressure rule
        addMemoryPressureRule(
            name: "auto_memory_cleanup",
            threshold: 90,
            actions: [.cleanMemory, .closeBrowserTabs(memoryThresholdMB: 500)]
        )

        // Disk space rule
        addDiskSpaceRule(
            name: "auto_disk_cleanup",
            threshold: 95,
            actions: [.cleanTemporaryFiles, .cleanCaches]
        )
    }

    // MARK: - Private Methods

    private func startTaskTimer(_ task: ScheduledTask) {
        guard task.isEnabled else { return }

        let timerTask = Task {
            while !Task.isCancelled {
                guard let nextRun = task.nextRun else { break }

                let delay = nextRun.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                guard !Task.isCancelled else { break }

                // Execute the action
                await task.action()

                // Update task state
                await MainActor.run {
                    if let index = self.scheduledTasks.firstIndex(where: { $0.id == task.id }) {
                        self.scheduledTasks[index].lastRun = Date()
                        self.scheduledTasks[index].runCount += 1

                        // Calculate next run
                        switch task.schedule {
                        case .once:
                            self.scheduledTasks[index].isEnabled = false
                            self.scheduledTasks[index].nextRun = nil
                        case .recurring(let interval):
                            self.scheduledTasks[index].nextRun = Date().addingTimeInterval(interval)
                        case .daily(let hour, let minute):
                            self.scheduledTasks[index].nextRun = self.calculateNextDailyRun(hour: hour, minute: minute)
                        case .weekly(let day, let hour, let minute):
                            self.scheduledTasks[index].nextRun = self.calculateNextWeeklyRun(dayOfWeek: day, hour: hour, minute: minute)
                        case .monthly(let day, let hour, let minute):
                            self.scheduledTasks[index].nextRun = self.calculateNextMonthlyRun(dayOfMonth: day, hour: hour, minute: minute)
                        case .onTrigger:
                            break
                        }
                    }
                }

                // For one-time tasks, exit the loop
                if case .once = task.schedule {
                    break
                }
            }
        }

        taskTimers[task.id] = timerTask
    }

    private func startTriggerMonitor(_ rule: AutomationRule) {
        let monitorTask = Task {
            let checkInterval: TimeInterval = 30 // Check every 30 seconds

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }

                let shouldTrigger = await checkTriggerCondition(rule.trigger)

                if shouldTrigger {
                    await executeRuleActions(rule)
                    await MainActor.run {
                        if let index = self.automationRules.firstIndex(where: { $0.id == rule.id }) {
                            self.automationRules[index].lastTriggered = Date()
                        }
                    }
                    // Cooldown period
                    try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                }
            }
        }

        triggerMonitors[rule.id] = monitorTask
    }

    private func checkTriggerCondition(_ trigger: ScheduledTask.Schedule.Trigger) async -> Bool {
        switch trigger {
        case .memoryPressure(let threshold):
            let usage = await MemoryManager().getMemoryUsagePercent()
            return usage > threshold

        case .diskSpaceLow(let threshold):
            let usage = await DiskManager().getDiskUsagePercent()
            return usage > threshold

        case .cpuHigh(let threshold, _):
            let usage = await DiagnosticsManager().getCPUUsage()
            return usage > threshold

        case .batteryLow(let threshold):
            let info = await DiagnosticsManager().getBatteryInfo()
            return info?.chargePercent ?? 100 < threshold

        case .networkChange, .applicationLaunch, .applicationQuit:
            return false // Would need system event monitoring
        }
    }

    private func executeRuleActions(_ rule: AutomationRule) async {
        for action in rule.actions {
            switch action {
            case .cleanMemory:
                _ = try? await MemoryManager().purgeInactiveMemory()

            case .cleanCaches:
                _ = try? await CacheManager().clearUserCaches()

            case .cleanTemporaryFiles:
                _ = try? await DiskManager().cleanTemporaryFiles()

            case .closeBrowserTabs(let threshold):
                _ = try? await BrowserManager().closeAllResourceHeavyTabs(memoryThresholdMB: threshold)

            case .killProcess(let name):
                _ = try? await ProcessManager().terminateAllByName(name, force: false)

            case .runCommand(let command):
                _ = try? await executor.execute(command)

            case .notify(let title, let message):
                _ = try? await executor.execute(
                    "osascript -e 'display notification \"\(message)\" with title \"\(title)\"'"
                )

            case .executeScript(let path):
                _ = try? await executor.execute("bash \"\(path)\"")
            }
        }
    }

    private func calculateNextDailyRun(hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0

        var nextRun = calendar.date(from: components) ?? Date()

        if nextRun <= Date() {
            nextRun = calendar.date(byAdding: .day, value: 1, to: nextRun) ?? nextRun
        }

        return nextRun
    }

    private func calculateNextWeeklyRun(dayOfWeek: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = dayOfWeek
        components.hour = hour
        components.minute = minute

        return calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? Date()
    }

    private func calculateNextMonthlyRun(dayOfMonth: Int, hour: Int, minute: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: Date())
        components.day = dayOfMonth
        components.hour = hour
        components.minute = minute

        var nextRun = calendar.date(from: components) ?? Date()

        if nextRun <= Date() {
            components.month = (components.month ?? 1) + 1
            nextRun = calendar.date(from: components) ?? nextRun
        }

        return nextRun
    }

    // MARK: - Cleanup

    public func stopAllTasks() {
        for timer in taskTimers.values {
            timer.cancel()
        }
        taskTimers.removeAll()

        for monitor in triggerMonitors.values {
            monitor.cancel()
        }
        triggerMonitors.removeAll()
    }

    deinit {
        Task { @MainActor in
            stopAllTasks()
        }
    }
}
