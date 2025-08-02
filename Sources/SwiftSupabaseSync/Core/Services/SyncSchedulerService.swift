//
//  SyncSchedulerService.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Combine

/// Intelligent sync scheduling service that manages when and how sync operations should be triggered
/// Considers network conditions, battery state, sync policies, and user activity patterns
@MainActor
public final class SyncSchedulerService: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared sync scheduler service instance
    public static let shared = SyncSchedulerService()
    
    // MARK: - Published Properties
    
    /// Current scheduling state
    @Published public private(set) var schedulingState: SchedulingState = .idle
    
    /// Active sync schedules by ID
    @Published public private(set) var activeSchedules: [String: SyncSchedule] = [:]
    
    /// Next scheduled sync operations
    @Published public private(set) var upcomingSchedules: [ScheduledSyncOperation] = []
    
    /// Current active sync policy being used
    @Published public private(set) var activeSyncPolicy: SyncPolicy = .balanced
    
    /// Whether automatic scheduling is enabled
    @Published public private(set) var isAutoSchedulingEnabled: Bool = true
    
    /// Last scheduling error
    @Published public private(set) var lastError: SchedulingError?
    
    // MARK: - Private Properties
    
    private let coordinationHub: CoordinationHub
    private let modelRegistry: ModelRegistryService
    private let networkMonitor: NetworkMonitor
    private let startSyncUseCase: StartSyncUseCaseProtocol
    private let logger: SyncLoggerProtocol?
    
    // State management
    private var cancellables = Set<AnyCancellable>()
    private var schedulingTimer: Timer?
    private var scheduledTasks: [String: Task<Void, Never>] = [:]
    // Async-safe state management using actor isolation
    
    // Configuration
    private let schedulingInterval: TimeInterval = 60.0 // Check every minute
    private let maxConcurrentScheduledSyncs: Int = 2
    
    // MARK: - Initialization
    
    private init(
        coordinationHub: CoordinationHub = .shared,
        modelRegistry: ModelRegistryService = .shared,
        networkMonitor: NetworkMonitor = .shared,
        startSyncUseCase: StartSyncUseCaseProtocol? = nil,
        logger: SyncLoggerProtocol? = nil
    ) {
        self.coordinationHub = coordinationHub
        self.modelRegistry = modelRegistry
        self.networkMonitor = networkMonitor
        self.startSyncUseCase = startSyncUseCase ?? DefaultStartSyncUseCase()
        self.logger = logger
        
        setupObservers()
        startSchedulingTimer()
    }
    
    // MARK: - Schedule Management
    
    /// Add a new sync schedule
    /// - Parameter schedule: Schedule to add
    public func addSchedule(_ schedule: SyncSchedule) {
        logger?.info("SyncScheduler: Adding schedule '\(schedule.name)' (\(schedule.id))")
        
        activeSchedules[schedule.id] = schedule
        
        // If schedule is immediate, trigger it now
        if schedule.trigger.isImmediate {
            Task {
                await triggerScheduledSync(scheduleId: schedule.id)
            }
        } else {
            updateUpcomingSchedules()
        }
        
        // Notify coordination hub
        coordinationHub.publish(CoordinationEvent(
            type: .coordinationRequired,
            data: [
                "action": "schedule_added",
                "scheduleId": schedule.id,
                "scheduleName": schedule.name
            ]
        ))
    }
    
    /// Remove a sync schedule
    /// - Parameter scheduleId: ID of schedule to remove
    public func removeSchedule(_ scheduleId: String) {
        logger?.debug("SyncScheduler: Removing schedule \(scheduleId)")
        
        // Cancel any running task for this schedule
        scheduledTasks[scheduleId]?.cancel()
        scheduledTasks.removeValue(forKey: scheduleId)
        
        activeSchedules.removeValue(forKey: scheduleId)
        updateUpcomingSchedules()
        
        // Notify coordination hub
        coordinationHub.publish(CoordinationEvent(
            type: .coordinationRequired,
            data: [
                "action": "schedule_removed",
                "scheduleId": scheduleId
            ]
        ))
    }
    
    /// Update an existing sync schedule
    /// - Parameters:
    ///   - scheduleId: ID of schedule to update
    ///   - schedule: Updated schedule configuration
    public func updateSchedule(_ scheduleId: String, with schedule: SyncSchedule) {
        guard activeSchedules[scheduleId] != nil else {
            logger?.warning("SyncScheduler: Attempt to update non-existent schedule \(scheduleId)")
            return
        }
        
        logger?.debug("SyncScheduler: Updating schedule \(scheduleId)")
        
        // Cancel existing task
        scheduledTasks[scheduleId]?.cancel()
        scheduledTasks.removeValue(forKey: scheduleId)
        
        // Update schedule
        activeSchedules[scheduleId] = schedule
        updateUpcomingSchedules()
    }
    
    /// Get all active schedules
    /// - Returns: Array of active sync schedules
    public func getAllSchedules() -> [SyncSchedule] {
        return Array(activeSchedules.values)
    }
    
    /// Get schedule by ID
    /// - Parameter scheduleId: Schedule ID to look up
    /// - Returns: Schedule if found
    public func getSchedule(_ scheduleId: String) -> SyncSchedule? {
        return activeSchedules[scheduleId]
    }
    
    // MARK: - Policy Management
    
    /// Update the active sync policy
    /// - Parameter policy: New sync policy to use
    public func updateSyncPolicy(_ policy: SyncPolicy) {
        activeSyncPolicy = policy
        
        logger?.info("SyncScheduler: Updated sync policy to '\(policy.name)'")
        
        // Re-evaluate all schedules with new policy
        updateUpcomingSchedules()
        
        // Notify coordination hub
        coordinationHub.publish(CoordinationEvent(
            type: .coordinationRequired,
            data: [
                "action": "policy_updated",
                "policyName": policy.name
            ]
        ))
    }
    
    /// Enable or disable automatic scheduling
    /// - Parameter enabled: Whether automatic scheduling should be enabled
    public func setAutoSchedulingEnabled(_ enabled: Bool) {
        isAutoSchedulingEnabled = enabled
        
        logger?.info("SyncScheduler: Auto-scheduling \(enabled ? "enabled" : "disabled")")
        
        if enabled {
            startSchedulingTimer()
            updateUpcomingSchedules()
        } else {
            stopSchedulingTimer()
            clearUpcomingSchedules()
        }
    }
    
    // MARK: - Manual Sync Triggers
    
    /// Trigger an immediate sync for all registered models
    /// - Parameters:
    ///   - user: User to sync for
    ///   - priority: Priority of the sync operation
    /// - Returns: Sync operation result
    public func triggerImmediateSync(for user: User, priority: SyncPriority = .normal) async -> SyncOperationResult {
        logger?.info("SyncScheduler: Triggering immediate sync for user \(user.id)")
        
        do {
            schedulingState = .scheduling
            
            let result = try await startSyncUseCase.startFullSync(for: user, using: activeSyncPolicy)
            
            schedulingState = .idle
            
            // Update scheduling based on result
            if result.success {
                await handleSuccessfulSync(result: result)
            } else {
                await handleFailedSync(result: result)
            }
            
            return result
            
        } catch {
            schedulingState = .error
            await setError(.syncExecutionFailed(error))
            
            logger?.error("SyncScheduler: Immediate sync failed: \(error)")
            
            return SyncOperationResult.failed(
                operation: SyncOperation(type: .fullSync, entityType: "all"),
                error: .unknownError(error.localizedDescription)
            )
        }
    }
    
    /// Trigger sync for a specific model type
    /// - Parameters:
    ///   - modelType: Model type to sync
    ///   - user: User to sync for
    ///   - priority: Priority of the sync operation
    /// - Returns: Sync operation result
    public func triggerModelSync<T: Syncable>(
        for modelType: T.Type,
        user: User,
        priority: SyncPriority = .normal
    ) async -> SyncOperationResult {
        logger?.info("SyncScheduler: Triggering model sync for \(modelType)")
        
        do {
            schedulingState = .scheduling
            
            let result = try await startSyncUseCase.startIncrementalSync(for: modelType, user: user, using: activeSyncPolicy)
            
            schedulingState = .idle
            
            return result
            
        } catch {
            schedulingState = .error
            await setError(.syncExecutionFailed(error))
            
            logger?.error("SyncScheduler: Model sync failed for \(modelType): \(error)")
            
            return SyncOperationResult.failed(
                operation: SyncOperation(type: .incrementalSync, entityType: String(describing: modelType)),
                error: .unknownError(error.localizedDescription)
            )
        }
    }
    
    // MARK: - Smart Scheduling
    
    /// Evaluate whether sync should be triggered now based on current conditions
    /// - Parameters:
    ///   - user: User to evaluate sync for
    ///   - entityType: Optional specific entity type to check
    /// - Returns: Scheduling recommendation
    public func evaluateSyncScheduling(for user: User, entityType: String? = nil) async -> SchedulingRecommendation {
        // Check basic eligibility
        do {
            let eligibility = try await startSyncUseCase.checkSyncEligibility(for: user, using: activeSyncPolicy)
            guard eligibility.isEligible else {
                return .`defer`(
                    reason: .conditionsNotMet,
                    retryAfter: activeSyncPolicy.retryDelayFor(attempt: 1),
                    recommendations: eligibility.recommendations
                )
            }
        } catch {
            return .`defer`(
                reason: .error,
                retryAfter: 300.0, // 5 minutes
                recommendations: ["Check authentication and network connectivity"]
            )
        }
        
        // Check network conditions
        let networkQuality = networkMonitor.networkQuality()
        guard networkQuality.allowsSync else {
            return .`defer`(
                reason: .networkUnavailable,
                retryAfter: 60.0,
                recommendations: ["Wait for network connectivity"]
            )
        }
        
        // Check if sync is allowed by policy
        let batteryLevel = await getBatteryLevel()
        let isBackground = await isAppInBackground()
        
        guard activeSyncPolicy.isSyncAllowed(
            isWifi: networkMonitor.connectionType == .wifi,
            batteryLevel: batteryLevel,
            isBackground: isBackground
        ) else {
            return .`defer`(
                reason: .policyRestriction,
                retryAfter: 300.0,
                recommendations: ["Check sync policy settings"]
            )
        }
        
        // Check for recent sync activity
        if let lastSyncTime = await getLastSyncTime(for: entityType) {
            let timeSinceLastSync = Date().timeIntervalSince(lastSyncTime)
            let minimumInterval = getMinimumSyncInterval()
            
            if timeSinceLastSync < minimumInterval {
                return .`defer`(
                    reason: .tooSoon,
                    retryAfter: minimumInterval - timeSinceLastSync,
                    recommendations: ["Wait for minimum sync interval"]
                )
            }
        }
        
        // Determine sync priority based on conditions
        let priority = calculateSyncPriority(
            networkQuality: networkQuality,
            batteryLevel: batteryLevel,
            timeSinceLastSync: await getTimeSinceLastSync(for: entityType)
        )
        
        return .recommend(
            priority: priority,
            estimatedDuration: estimateSyncDuration(for: entityType),
            recommendedBatchSize: calculateOptimalBatchSize()
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupObservers() {
        // Listen for coordination events
        coordinationHub.eventPublisher
            .sink { [weak self] event in
                Task { [weak self] in
                    await self?.handleCoordinationEvent(event)
                }
            }
            .store(in: &cancellables)
        
        // Listen for network changes
        networkMonitor.$isConnected
            .dropFirst()
            .sink { [weak self] isConnected in
                Task { [weak self] in
                    await self?.handleNetworkChange(isConnected: isConnected)
                }
            }
            .store(in: &cancellables)
        
        // Listen for model registry changes
        // Note: This would require ModelRegistryService to have an event publisher
        // For now, we'll use the coordination hub events
    }
    
    private func startSchedulingTimer() {
        stopSchedulingTimer()
        
        schedulingTimer = Timer.scheduledTimer(withTimeInterval: schedulingInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.evaluateScheduledSyncs()
            }
        }
    }
    
    private func stopSchedulingTimer() {
        schedulingTimer?.invalidate()
        schedulingTimer = nil
    }
    
    private func evaluateScheduledSyncs() async {
        guard isAutoSchedulingEnabled else { return }
        
        let schedules = Array(activeSchedules.values)
        
        for schedule in schedules {
            if await shouldTriggerSchedule(schedule) {
                await triggerScheduledSync(scheduleId: schedule.id)
            }
        }
        
        updateUpcomingSchedules()
    }
    
    private func shouldTriggerSchedule(_ schedule: SyncSchedule) async -> Bool {
        guard schedule.isEnabled && isAutoSchedulingEnabled else { return false }
        
        // Check if already running
        if scheduledTasks[schedule.id] != nil {
            return false
        }
        
        // Check trigger conditions
        switch schedule.trigger {
        case .interval(let seconds):
            if let lastRun = schedule.lastExecutedAt {
                return Date().timeIntervalSince(lastRun) >= seconds
            }
            return true
            
        case .time(let dateComponents):
            return shouldTriggerAtTime(dateComponents, lastExecuted: schedule.lastExecutedAt)
            
        case .networkChange:
            // This would be triggered by network observers, not the timer
            return false
            
        case .modelChange(let modelType):
            // This would be triggered by model change observers
            return await hasModelChanged(modelType, since: schedule.lastExecutedAt)
            
        case .immediate:
            // Immediate schedules are triggered when added
            return false
        }
    }
    
    private func triggerScheduledSync(scheduleId: String) async {
        guard let schedule = activeSchedules[scheduleId] else { return }
        
        logger?.info("SyncScheduler: Triggering scheduled sync '\(schedule.name)'")
        
        // Create scheduled task
        let task = Task {
            await executeScheduledSync(schedule: schedule)
        }
        
        scheduledTasks[scheduleId] = task
        await task.value
        
        // Clean up task
        scheduledTasks.removeValue(forKey: scheduleId)
        
        // Update schedule's last executed time
        var updatedSchedule = schedule
        updatedSchedule.lastExecutedAt = Date()
        activeSchedules[scheduleId] = updatedSchedule
        
        updateUpcomingSchedules()
    }
    
    private func executeScheduledSync(schedule: SyncSchedule) async {
        // This is a simplified implementation
        // In reality, we'd need user context and more sophisticated execution logic
        logger?.debug("SyncScheduler: Executing scheduled sync '\(schedule.name)'")
        
        // For now, we'll just log the execution
        // Real implementation would:
        // 1. Get appropriate user context
        // 2. Check current conditions
        // 3. Execute the sync with appropriate scope
        // 4. Handle results and schedule next execution
    }
    
    private func updateUpcomingSchedules() {
        var upcoming: [ScheduledSyncOperation] = []
        
        for schedule in activeSchedules.values {
            if let nextExecution = calculateNextExecution(for: schedule) {
                let operation = ScheduledSyncOperation(
                    id: UUID(),
                    scheduleId: schedule.id,
                    scheduleName: schedule.name,
                    scheduledFor: nextExecution,
                    estimatedDuration: schedule.estimatedDuration,
                    priority: schedule.priority
                )
                upcoming.append(operation)
            }
        }
        
        // Sort by scheduled time
        upcoming.sort { $0.scheduledFor < $1.scheduledFor }
        
        // Keep only next few operations
        upcomingSchedules = Array(upcoming.prefix(10))
    }
    
    private func clearUpcomingSchedules() {
        upcomingSchedules.removeAll()
        
        // Cancel all scheduled tasks
        for task in scheduledTasks.values {
            task.cancel()
        }
        scheduledTasks.removeAll()
    }
    
    private func calculateNextExecution(for schedule: SyncSchedule) -> Date? {
        let now = Date()
        
        switch schedule.trigger {
        case .interval(let seconds):
            if let lastExecuted = schedule.lastExecutedAt {
                return lastExecuted.addingTimeInterval(seconds)
            }
            return now
            
        case .time(let components):
            return nextDateMatching(components: components, after: schedule.lastExecutedAt ?? now)
            
        case .networkChange, .modelChange, .immediate:
            // These don't have predictable next execution times
            return nil
        }
    }
    
    private func handleCoordinationEvent(_ event: CoordinationEvent) async {
        switch event.type {
        case .networkStateChanged:
            if let isConnected = event.data["isConnected"] as? Bool {
                await handleNetworkChange(isConnected: isConnected)
            }
            
        case .authStateChanged:
            // Re-evaluate all schedules when auth state changes
            if isAutoSchedulingEnabled {
                await evaluateScheduledSyncs()
            }
            
        case .modelRegistered, .modelUnregistered:
            // Model registry changed, update schedules if needed
            updateUpcomingSchedules()
            
        default:
            break
        }
    }
    
    private func handleNetworkChange(isConnected: Bool) async {
        // Trigger network-based schedules when network becomes available
        if isConnected {
            let networkSchedules = activeSchedules.values.filter { schedule in
                if case .networkChange = schedule.trigger {
                    return true
                }
                return false
            }
            
            for schedule in networkSchedules {
                await triggerScheduledSync(scheduleId: schedule.id)
            }
        }
    }
    
    private func handleSuccessfulSync(result: SyncOperationResult) async {
        logger?.info("SyncScheduler: Sync completed successfully")
        // Could implement adaptive scheduling based on success patterns
    }
    
    private func handleFailedSync(result: SyncOperationResult) async {
        logger?.warning("SyncScheduler: Sync failed, adjusting future schedules")
        // Could implement backoff strategies for failed syncs
    }
    
    private func setError(_ error: SchedulingError) async {
        await MainActor.run {
            self.lastError = error
        }
    }
    
    // MARK: - Helper Methods
    
    private func shouldTriggerAtTime(_ components: DateComponents, lastExecuted: Date?) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        
        // Create target date for today
        var targetComponents = calendar.dateComponents([.year, .month, .day], from: now)
        targetComponents.hour = components.hour
        targetComponents.minute = components.minute
        targetComponents.second = components.second ?? 0
        
        guard let targetDate = calendar.date(from: targetComponents) else { return false }
        
        // If target time has passed today and we haven't executed since then
        if targetDate <= now {
            if let lastExecuted = lastExecuted {
                return lastExecuted < targetDate
            }
            return true
        }
        
        return false
    }
    
    private func hasModelChanged(_ modelType: String, since date: Date?) async -> Bool {
        // This would check with the model registry or change tracking system
        // For now, return false as placeholder
        return false
    }
    
    private func nextDateMatching(components: DateComponents, after date: Date) -> Date? {
        let calendar = Calendar.current
        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }
    
    private func getBatteryLevel() async -> Double {
        // This would get actual battery level from the device
        // For now, return a default value
        return 1.0
    }
    
    private func isAppInBackground() async -> Bool {
        // This would check actual app state
        // For now, return false
        return false
    }
    
    private func getLastSyncTime(for entityType: String?) async -> Date? {
        // This would query the sync repository for last sync time
        // For now, return nil
        return nil
    }
    
    private func getTimeSinceLastSync(for entityType: String?) async -> TimeInterval {
        if let lastSync = await getLastSyncTime(for: entityType) {
            return Date().timeIntervalSince(lastSync)
        }
        return TimeInterval.greatestFiniteMagnitude
    }
    
    private func getMinimumSyncInterval() -> TimeInterval {
        // Get from sync policy or default
        if case .interval(let seconds) = activeSyncPolicy.frequency {
            return seconds
        }
        return 300.0 // 5 minutes default
    }
    
    private func calculateSyncPriority(
        networkQuality: NetworkQuality,
        batteryLevel: Double,
        timeSinceLastSync: TimeInterval
    ) -> SyncPriority {
        if timeSinceLastSync > 3600 { // 1 hour
            return .high
        } else if networkQuality == .excellent && batteryLevel > 0.5 {
            return .normal
        } else {
            return .low
        }
    }
    
    private func estimateSyncDuration(for entityType: String?) -> TimeInterval {
        // This would use historical data to estimate duration
        // For now, return a default estimate
        return 30.0
    }
    
    private func calculateOptimalBatchSize() -> Int {
        // Calculate based on network quality and policy
        let baseSize = activeSyncPolicy.batchSize
        
        switch networkMonitor.networkQuality() {
        case .excellent:
            return baseSize
        case .good:
            return Int(Double(baseSize) * 0.8)
        case .fair:
            return Int(Double(baseSize) * 0.6)
        case .poor:
            return Int(Double(baseSize) * 0.4)
        default:
            return Int(Double(baseSize) * 0.5)
        }
    }
    
    // MARK: - Cleanup
    
    /// Clear all errors
    public func clearErrors() {
        Task {
            await MainActor.run {
                self.lastError = nil
            }
        }
    }
    
    /// Reset scheduler to initial state
    public func reset() {
        stopSchedulingTimer()
        clearUpcomingSchedules()
        activeSchedules.removeAll()
        schedulingState = .idle
        lastError = nil
        
        if isAutoSchedulingEnabled {
            startSchedulingTimer()
        }
    }
}

// MARK: - Supporting Types

/// Current state of the sync scheduler
public enum SchedulingState: String, CaseIterable {
    case idle = "idle"
    case scheduling = "scheduling"
    case evaluating = "evaluating"
    case error = "error"
}

/// Sync schedule configuration
public struct SyncSchedule: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let trigger: ScheduleTrigger
    public let scope: SyncScope
    public let priority: SyncPriority
    public let isEnabled: Bool
    public let estimatedDuration: TimeInterval
    public var lastExecutedAt: Date?
    public let createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        trigger: ScheduleTrigger,
        scope: SyncScope = .all,
        priority: SyncPriority = .normal,
        isEnabled: Bool = true,
        estimatedDuration: TimeInterval = 30.0,
        lastExecutedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.scope = scope
        self.priority = priority
        self.isEnabled = isEnabled
        self.estimatedDuration = estimatedDuration
        self.lastExecutedAt = lastExecutedAt
        self.createdAt = createdAt
    }
}

/// Trigger conditions for sync schedules
public enum ScheduleTrigger: Equatable {
    case interval(TimeInterval)
    case time(DateComponents)
    case networkChange
    case modelChange(String)
    case immediate
    
    var isImmediate: Bool {
        if case .immediate = self {
            return true
        }
        return false
    }
}

/// Scope of sync operation
public enum SyncScope: Equatable {
    case all
    case models([String])
    case specific(String)
}

/// Priority of sync operation
public enum SyncPriority: String, CaseIterable, Comparable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    public static func < (lhs: SyncPriority, rhs: SyncPriority) -> Bool {
        let order: [SyncPriority] = [.low, .normal, .high, .urgent]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// Scheduled sync operation
public struct ScheduledSyncOperation: Identifiable {
    public let id: UUID
    public let scheduleId: String
    public let scheduleName: String
    public let scheduledFor: Date
    public let estimatedDuration: TimeInterval
    public let priority: SyncPriority
}

/// Scheduling recommendation result
public enum SchedulingRecommendation {
    case recommend(priority: SyncPriority, estimatedDuration: TimeInterval, recommendedBatchSize: Int)
    case `defer`(reason: DeferReason, retryAfter: TimeInterval, recommendations: [String])
}

/// Reasons for deferring sync
public enum DeferReason: String, CaseIterable {
    case conditionsNotMet = "conditions_not_met"
    case networkUnavailable = "network_unavailable"
    case policyRestriction = "policy_restriction"
    case tooSoon = "too_soon"
    case error = "error"
}

/// Scheduling errors
public enum SchedulingError: Error, LocalizedError {
    case scheduleNotFound(String)
    case invalidScheduleConfiguration(String)
    case syncExecutionFailed(Error)
    case schedulingDisabled
    case resourcesUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .scheduleNotFound(let id):
            return "Schedule not found: \(id)"
        case .invalidScheduleConfiguration(let reason):
            return "Invalid schedule configuration: \(reason)"
        case .syncExecutionFailed(let error):
            return "Sync execution failed: \(error.localizedDescription)"
        case .schedulingDisabled:
            return "Sync scheduling is disabled"
        case .resourcesUnavailable:
            return "Required resources are not available"
        }
    }
}

// MARK: - Default Implementation

/// Default implementation of StartSyncUseCaseProtocol for dependency injection
private struct DefaultStartSyncUseCase: StartSyncUseCaseProtocol {
    func startFullSync(for user: User, using policy: SyncPolicy) async throws -> SyncOperationResult {
        // This would be injected with the real implementation
        return SyncOperationResult(
            operation: SyncOperation(type: .fullSync, entityType: "all"),
            success: false,
            errors: [.unknownError("No StartSyncUseCase implementation provided")]
        )
    }
    
    func startIncrementalSync<T: Syncable>(
        for entityType: T.Type,
        user: User,
        using policy: SyncPolicy
    ) async throws -> SyncOperationResult {
        return SyncOperationResult(
            operation: SyncOperation(type: .incrementalSync, entityType: String(describing: entityType)),
            success: false,
            errors: [.unknownError("No StartSyncUseCase implementation provided")]
        )
    }
    
    func startRecordSync<T: Syncable>(
        for records: [T],
        user: User,
        using policy: SyncPolicy
    ) async throws -> SyncOperationResult {
        return SyncOperationResult(
            operation: SyncOperation(type: .upload, entityType: String(describing: T.self)),
            success: false
        )
    }
    
    func checkSyncEligibility(for user: User, using policy: SyncPolicy) async throws -> SyncEligibilityResult {
        return .ineligible(reason: .conditionsNotMet, recommendations: ["Configure sync dependencies"])
    }
    
    func cancelSync(operationID: UUID, for user: User) async throws -> SyncCancellationResult {
        return SyncCancellationResult(success: false, operationID: operationID, error: .operationNotFound)
    }
    
    func getSyncStatus<T: Syncable>(
        for entityType: T.Type?,
        user: User
    ) async throws -> SyncStatus {
        return SyncStatus()
    }
}

// MARK: - Extensions

extension SyncSchedule {
    /// Predefined schedule for automatic full sync every hour
    public static var hourlyFullSync: SyncSchedule {
        SyncSchedule(
            name: "Hourly Full Sync",
            trigger: .interval(3600),
            scope: .all,
            priority: .normal
        )
    }
    
    /// Predefined schedule for daily sync at 2 AM
    public static var dailySync: SyncSchedule {
        var components = DateComponents()
        components.hour = 2
        components.minute = 0
        
        return SyncSchedule(
            name: "Daily Sync",
            trigger: .time(components),
            scope: .all,
            priority: .low
        )
    }
    
    /// Predefined schedule for network-triggered sync
    public static var networkTriggeredSync: SyncSchedule {
        SyncSchedule(
            name: "Network Change Sync",
            trigger: .networkChange,
            scope: .all,
            priority: .normal
        )
    }
}