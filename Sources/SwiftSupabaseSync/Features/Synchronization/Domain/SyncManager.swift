//
//  SyncManager.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Combine
import SwiftData

/// Main synchronization coordinator that manages sync operations and state
/// Provides high-level interface for sync operations with reactive state updates
@MainActor
public final class SyncManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current sync status
    @Published public private(set) var syncStatus: SyncStatus = SyncStatus()
    
    /// Whether sync is currently active
    @Published public private(set) var isSyncing: Bool = false
    
    /// Whether sync is enabled
    @Published public private(set) var isSyncEnabled: Bool = false
    
    /// Current sync progress (0.0 to 1.0)
    @Published public private(set) var syncProgress: Double = 0.0
    
    /// Last sync error
    @Published public private(set) var lastSyncError: SyncError?
    
    /// Active sync operations by entity type
    @Published public private(set) var activeSyncOperations: [String: SyncOperation] = [:]
    
    /// Unresolved conflicts count
    @Published public private(set) var unresolvedConflictsCount: Int = 0
    
    // MARK: - Dependencies
    
    private let syncRepository: SyncRepositoryProtocol
    private let startSyncUseCase: StartSyncUseCaseProtocol
    private let authManager: AuthManager
    private let conflictResolver: ConflictResolvable?
    private let coordinationHub: CoordinationHub
    private let modelRegistry: ModelRegistryService
    private let syncScheduler: SyncSchedulerService
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Configuration
    
    private var syncPolicy: SyncPolicy
    private let enableAutoSync: Bool
    private let syncInterval: TimeInterval
    private let maxRetries: Int
    
    // MARK: - State Management
    
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    private let syncQueue = DispatchQueue(label: "sync.manager.operations", qos: .userInitiated)
    
    // Active operation tracking
    private var activeOperations: [UUID: Task<Void, Never>] = [:]
    
    // MARK: - Initialization
    
    public init(
        syncRepository: SyncRepositoryProtocol,
        startSyncUseCase: StartSyncUseCaseProtocol,
        authManager: AuthManager,
        conflictResolver: ConflictResolvable? = nil,
        coordinationHub: CoordinationHub = CoordinationHub.shared,
        modelRegistry: ModelRegistryService = ModelRegistryService.shared,
        syncScheduler: SyncSchedulerService = SyncSchedulerService.shared,
        logger: SyncLoggerProtocol? = nil,
        syncPolicy: SyncPolicy = .balanced,
        enableAutoSync: Bool = true,
        syncInterval: TimeInterval = 300, // 5 minutes
        maxRetries: Int = 3
    ) {
        self.syncRepository = syncRepository
        self.startSyncUseCase = startSyncUseCase
        self.authManager = authManager
        self.conflictResolver = conflictResolver
        self.coordinationHub = coordinationHub
        self.modelRegistry = modelRegistry
        self.syncScheduler = syncScheduler
        self.logger = logger
        self.syncPolicy = syncPolicy
        self.enableAutoSync = enableAutoSync
        self.syncInterval = syncInterval
        self.maxRetries = maxRetries
        
        Task {
            await initialize()
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        logger?.debug("SyncManager: Initializing")
        
        // Observe authentication state
        observeAuthenticationState()
        
        // Observe coordination events
        observeCoordinationEvents()
        
        // Setup auto sync if enabled
        if enableAutoSync {
            setupAutoSync()
        }
        
        // Load previous sync status
        await loadSyncStatus()
    }
    
    // MARK: - Public Sync Methods
    
    /// Start synchronization for all registered models
    /// - Returns: Sync operation result
    @discardableResult
    public func startSync() async throws -> SyncOperationResult {
        guard let user = authManager.currentUser else {
            throw SyncError.subscriptionRequired
        }
        
        guard !isSyncing else {
            throw SyncError.unknownError("Sync already in progress")
        }
        
        logger?.info("SyncManager: Starting full sync")
        
        await setSyncing(true)
        await updateSyncStatus(.preparing)
        
        do {
            // Check sync eligibility
            let eligibility = try await startSyncUseCase.checkSyncEligibility(for: user, using: syncPolicy)
            guard eligibility.isEligible else {
                throw SyncError.unknownError(eligibility.reason?.rawValue ?? "Sync not allowed")
            }
            
            // Start full sync
            let result = try await syncScheduler.triggerImmediateSync(for: user)
            
            await processSyncResult(result)
            logger?.info("SyncManager: Full sync completed successfully")
            
            return result
            
        } catch {
            let syncError = error as? SyncError ?? SyncError.unknownError(error.localizedDescription)
            await handleSyncError(syncError)
            throw syncError
        }
    }
    
    /// Start incremental sync for specific entity type
    /// - Parameter entityType: Type of entity to sync
    /// - Returns: Sync operation result
    @discardableResult
    public func startIncrementalSync<T: Syncable>(for entityType: T.Type) async throws -> SyncOperationResult {
        guard let user = authManager.currentUser else {
            throw SyncError.subscriptionRequired
        }
        
        logger?.info("SyncManager: Starting incremental sync for \(T.tableName)")
        
        let operationID = UUID()
        await addActiveOperation(T.tableName, operationID: operationID)
        
        do {
            let result = try await syncScheduler.triggerModelSync(
                for: entityType,
                user: user
            )
            
            await removeActiveOperation(T.tableName)
            await updateProgress(for: T.tableName, progress: 1.0)
            
            return result
            
        } catch {
            await removeActiveOperation(T.tableName)
            let syncError = error as? SyncError ?? SyncError.unknownError(error.localizedDescription)
            throw syncError
        }
    }
    
    /// Stop all sync operations
    public func stopSync() async {
        logger?.info("SyncManager: Stopping sync")
        
        // Cancel all active operations
        for (_, task) in activeOperations {
            task.cancel()
        }
        activeOperations.removeAll()
        
        await setSyncing(false)
        await updateSyncStatus(.cancelled)
    }
    
    /// Pause sync operations
    public func pauseSync() async {
        guard isSyncing else { return }
        
        logger?.info("SyncManager: Pausing sync")
        await updateSyncStatus(.paused)
    }
    
    /// Resume sync operations
    public func resumeSync() async throws {
        guard syncStatus.state == .paused else { return }
        
        logger?.info("SyncManager: Resuming sync")
        try await startSync()
    }
    
    // MARK: - Model Registration
    
    /// Register a model type for synchronization
    /// - Parameter modelType: Type of model to register
    public func registerModel<T: Syncable>(_ modelType: T.Type) {
        do {
            _ = try modelRegistry.registerModel(modelType)
            logger?.debug("SyncManager: Registered model \(T.tableName) for sync")
        } catch {
            logger?.error("SyncManager: Failed to register model \(T.tableName): \(error)")
        }
    }
    
    /// Unregister a model type from synchronization
    /// - Parameter modelType: Type of model to unregister
    public func unregisterModel<T: Syncable>(_ modelType: T.Type) {
        _ = modelRegistry.unregisterModel(modelType)
        logger?.debug("SyncManager: Unregistered model \(T.tableName) from sync")
    }
    
    /// Get all registered model types
    public var registeredModelTypes: Set<String> {
        modelRegistry.allTableNames
    }
    
    // MARK: - Conflict Resolution
    
    /// Get unresolved conflicts for a specific entity type
    /// - Parameter entityType: Type of entity to get conflicts for
    /// - Returns: Array of unresolved conflicts
    public func getUnresolvedConflicts<T: Syncable>(for entityType: T.Type) async throws -> [SyncConflict] {
        return try await syncRepository.getUnresolvedConflicts(ofType: entityType, limit: nil)
    }
    
    /// Resolve conflicts using the configured resolver
    /// - Parameter conflicts: Conflicts to resolve
    /// - Returns: Array of conflict resolutions
    public func resolveConflicts(_ conflicts: [SyncConflict]) async throws -> [ConflictResolution] {
        guard let resolver = conflictResolver else {
            throw SyncError.unknownError("No conflict resolver configured")
        }
        
        logger?.info("SyncManager: Resolving \(conflicts.count) conflicts")
        
        var resolutions: [ConflictResolution] = []
        
        for conflict in conflicts {
            let resolution = try await resolver.resolveConflict(conflict)
            resolutions.append(resolution)
        }
        
        // Apply resolutions
        let results = try await syncRepository.applyConflictResolutions(resolutions)
        
        // Update unresolved conflicts count
        await updateUnresolvedConflictsCount()
        
        logger?.info("SyncManager: Resolved \(results.filter { $0.success }.count) conflicts successfully")
        
        return resolutions
    }
    
    // MARK: - Sync Configuration
    
    /// Update sync policy
    /// - Parameter policy: New sync policy to use
    public func updateSyncPolicy(_ policy: SyncPolicy) {
        self.syncPolicy = policy
        logger?.debug("SyncManager: Updated sync policy to \(policy)")
    }
    
    /// Enable or disable sync
    /// - Parameter enabled: Whether sync should be enabled
    public func setSyncEnabled(_ enabled: Bool) async {
        await MainActor.run {
            self.isSyncEnabled = enabled
        }
        
        if enabled && enableAutoSync {
            setupAutoSync()
        } else {
            syncTimer?.invalidate()
            syncTimer = nil
        }
        
        logger?.info("SyncManager: Sync \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Sync Status
    
    /// Get sync status for specific entity type
    /// - Parameter entityType: Type of entity to get status for
    /// - Returns: Entity sync status
    public func getSyncStatus<T: Syncable>(for entityType: T.Type) async throws -> EntitySyncStatus {
        return try await syncRepository.getSyncStatus(for: entityType)
    }
    
    /// Get last sync timestamp for entity type
    /// - Parameter entityType: Type of entity to get timestamp for
    /// - Returns: Last sync date or nil
    public func getLastSyncTimestamp<T: Syncable>(for entityType: T.Type) async throws -> Date? {
        return try await syncRepository.getLastSyncTimestamp(for: entityType)
    }
    
    // MARK: - Private State Management
    
    private func setSyncing(_ syncing: Bool) async {
        await MainActor.run {
            self.isSyncing = syncing
        }
    }
    
    private func updateSyncStatus(_ state: SyncState) async {
        await MainActor.run {
            self.syncStatus = SyncStatus(
                id: syncStatus.id,
                state: state,
                progress: syncStatus.progress,
                operation: syncStatus.operation,
                totalItems: syncStatus.totalItems,
                completedItems: syncStatus.completedItems,
                failedItems: syncStatus.failedItems,
                isConnected: syncStatus.isConnected,
                isRealtimeActive: syncStatus.isRealtimeActive,
                lastError: syncStatus.lastError,
                retryCount: syncStatus.retryCount
            )
        }
    }
    
    private func updateProgress(for entityType: String? = nil, progress: Double) async {
        await MainActor.run {
            if entityType == nil {
                self.syncProgress = progress
            }
            
            self.syncStatus = SyncStatus(
                id: syncStatus.id,
                state: syncStatus.state,
                progress: progress,
                operation: syncStatus.operation,
                totalItems: syncStatus.totalItems,
                completedItems: Int(Double(syncStatus.totalItems) * progress),
                failedItems: syncStatus.failedItems,
                isConnected: syncStatus.isConnected,
                isRealtimeActive: syncStatus.isRealtimeActive,
                lastError: syncStatus.lastError,
                retryCount: syncStatus.retryCount
            )
        }
    }
    
    private func addActiveOperation(_ entityType: String, operationID: UUID) async {
        await MainActor.run {
            let operation = SyncOperation(
                id: operationID,
                type: .incrementalSync,
                entityType: entityType,
                startedAt: Date(),
                status: .running
            )
            self.activeSyncOperations[entityType] = operation
        }
    }
    
    private func removeActiveOperation(_ entityType: String) async {
        await MainActor.run {
            _ = self.activeSyncOperations.removeValue(forKey: entityType)
        }
    }
    
    private func processSyncResult(_ result: SyncOperationResult) async {
        await MainActor.run {
            self.syncStatus = SyncStatus(
                id: syncStatus.id,
                state: result.success ? .completed : .failed,
                progress: 1.0,
                operation: result.operation,
                totalItems: result.uploadedCount + result.downloadedCount,
                completedItems: result.uploadedCount + result.downloadedCount,
                failedItems: result.errors.count,
                isConnected: true,
                isRealtimeActive: syncStatus.isRealtimeActive,
                lastError: result.errors.first,
                retryCount: 0,
                lastFullSyncAt: result.operation.type == .fullSync ? Date() : syncStatus.lastFullSyncAt,
                lastIncrementalSyncAt: result.operation.type == .incrementalSync ? Date() : syncStatus.lastIncrementalSyncAt
            )
            
            self.isSyncing = false
            self.syncProgress = 1.0
        }
        
        // Publish sync state change through coordination hub
        coordinationHub.publishSyncStateChanged(
            syncState: result.success ? .completed : .failed,
            isSyncing: false,
            progress: 1.0
        )
    }
    
    private func handleSyncError(_ error: SyncError) async {
        await MainActor.run {
            self.lastSyncError = error
            self.syncStatus = SyncStatus(
                id: syncStatus.id,
                state: .failed,
                progress: syncStatus.progress,
                operation: syncStatus.operation,
                totalItems: syncStatus.totalItems,
                completedItems: syncStatus.completedItems,
                failedItems: syncStatus.failedItems,
                isConnected: syncStatus.isConnected,
                isRealtimeActive: syncStatus.isRealtimeActive,
                lastError: error,
                lastErrorAt: Date(),
                retryCount: syncStatus.retryCount + 1
            )
            
            self.isSyncing = false
        }
        
        logger?.error("SyncManager: Sync failed with error: \(error)")
    }
    
    // MARK: - Auto Sync
    
    private func setupAutoSync() {
        syncTimer?.invalidate()
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performAutoSync()
            }
        }
    }
    
    private func performAutoSync() async {
        guard isSyncEnabled, !isSyncing else { return }
        guard authManager.isAuthenticated else { return }
        
        logger?.debug("SyncManager: Performing auto sync")
        
        do {
            try await startSync()
        } catch {
            logger?.error("SyncManager: Auto sync failed: \(error)")
        }
    }
    
    // MARK: - Persistence
    
    private func loadSyncStatus() async {
        // Load previous sync status from persistent storage
        // This would typically load from UserDefaults or a database
        logger?.debug("SyncManager: Loading sync status")
    }
    
    private func updateUnresolvedConflictsCount() async {
        let totalConflicts = 0
        
        // Use the ModelRegistry to get registered models and check conflicts
        let registeredTableNames = modelRegistry.allTableNames
        
        for _ in registeredTableNames {
            // In real implementation, this would check conflicts for each registered model
            // For now, we'll simulate by setting to 0
            // TODO: Implement actual conflict counting using repository
        }
        
        await MainActor.run {
            self.unresolvedConflictsCount = totalConflicts
        }
    }
    
    // MARK: - Observation
    
    private func observeAuthenticationState() {
        authManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                Task { [weak self] in
                    if !isAuthenticated {
                        await self?.stopSync()
                        await self?.setSyncEnabled(false)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func observeCoordinationEvents() {
        // Listen for network state changes
        coordinationHub.networkEventPublisher
            .sink { [weak self] event in
                Task { [weak self] in
                    await self?.handleNetworkEvent(event)
                }
            }
            .store(in: &cancellables)
        
        // Listen for subscription changes
        coordinationHub.subscriptionEventPublisher
            .sink { [weak self] event in
                Task { [weak self] in
                    await self?.handleSubscriptionEvent(event)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkEvent(_ event: CoordinationEvent) async {
        switch event.type {
        case .networkStateChanged:
            if let isConnected = event.data["isConnected"] as? Bool {
                if isConnected && !isSyncing && isSyncEnabled {
                    // Network reconnected, resume sync if needed
                    logger?.debug("SyncManager: Network reconnected, checking if sync should resume")
                    _ = try? await startSync()
                }
            }
        case .offlineModeActivated:
            await pauseSync()
        case .onlineModeActivated:
            if isSyncEnabled && !isSyncing {
                _ = try? await resumeSync()
            }
        default:
            break
        }
    }
    
    private func handleSubscriptionEvent(_ event: CoordinationEvent) async {
        switch event.type {
        case .subscriptionChanged:
            // Subscription changed, might affect sync capabilities
            logger?.debug("SyncManager: Subscription changed, may affect sync features")
        default:
            break
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        syncTimer?.invalidate()
        cancellables.removeAll()
        
        // Cancel all active operations
        for (_, task) in activeOperations {
            task.cancel()
        }
    }
}

// MARK: - Helper Extensions

// MARK: - Public Convenience Methods

public extension SyncManager {
    
    /// Whether any sync operation is in progress
    var hasActiveSyncOperations: Bool {
        !activeSyncOperations.isEmpty
    }
    
    /// Get progress for specific entity type
    func getProgress(for entityType: String) -> Double? {
        // Progress tracking would need to be implemented separately
        // as SyncOperation doesn't have a progress property
        nil
    }
    
    /// Clear sync errors
    func clearErrors() {
        Task {
            await MainActor.run {
                self.lastSyncError = nil
            }
        }
    }
    
    /// Force sync for specific models
    func syncModels<T: Syncable>(_ models: [T]) async throws {
        guard let user = authManager.currentUser else {
            throw SyncError.subscriptionRequired
        }
        
        let result = try await startSyncUseCase.startRecordSync(
            for: models,
            user: user,
            using: syncPolicy
        )
        
        await processSyncResult(result)
    }
}