//
//  SyncAPI.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftData

// MARK: - Main SyncAPI Class

/// Main public API for synchronization operations
/// Provides a clean, simple interface for developers to manage sync
@MainActor
public final class SyncAPI: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current sync status
    @Published public private(set) var status: PublicSyncStatus = .idle
    
    /// Whether sync is currently in progress
    @Published public private(set) var isSyncing: Bool = false
    
    /// Current sync progress (0.0 to 1.0)
    @Published public private(set) var progress: Double = 0.0
    
    /// Whether sync is enabled
    @Published public private(set) var isSyncEnabled: Bool = true
    
    /// Number of unresolved conflicts
    @Published public private(set) var conflictCount: Int = 0
    
    /// Last sync error (if any)
    @Published public private(set) var lastError: SwiftSupabaseSyncError?
    
    /// Currently active sync operations
    @Published public private(set) var activeOperations: [SyncOperationInfo] = []
    
    /// Last successful sync time
    @Published public private(set) var lastSyncTime: Date?
    
    // MARK: - Combine Publishers
    
    /// Publisher for sync status changes
    public var statusPublisher: AnyPublisher<PublicSyncStatus, Never> {
        $status.eraseToAnyPublisher()
    }
    
    /// Publisher for sync progress updates
    public var progressPublisher: AnyPublisher<Double, Never> {
        $progress.eraseToAnyPublisher()
    }
    
    /// Publisher for sync completion events
    public var completionPublisher: PassthroughSubject<PublicSyncResult, Never> = PassthroughSubject()
    
    /// Publisher for sync error events
    public var errorPublisher: PassthroughSubject<SwiftSupabaseSyncError, Never> = PassthroughSubject()
    
    /// Publisher for conflict detection events
    public var conflictPublisher: PassthroughSubject<[ConflictInfo], Never> = PassthroughSubject()
    
    // MARK: - Dependencies
    
    internal let syncManager: SyncManager
    internal let authAPI: AuthAPI
    internal let observerManager = SyncObserverManager()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    /// Current sync policy configuration
    public private(set) var syncPolicy: SyncPolicyConfiguration = .balanced
    
    /// Registered model types for sync
    public private(set) var registeredModels: Set<String> = []
    
    // MARK: - Initialization
    
    internal init(syncManager: SyncManager, authAPI: AuthAPI) {
        self.syncManager = syncManager
        self.authAPI = authAPI
        
        setupObservation()
    }
    
    // MARK: - Public Sync Methods
    
    /// Start full synchronization for all registered models
    /// - Returns: Result of the sync operation
    @discardableResult
    public func startSync() async throws -> PublicSyncResult {
        guard authAPI.isAuthenticated else {
            throw SwiftSupabaseSyncError.authenticationFailed(reason: .sessionExpired)
        }
        
        guard !isSyncing else {
            throw SwiftSupabaseSyncError.syncInProgress
        }
        
        do {
            let result = try await syncManager.startSync()
            let publicResult = convertToPublicResult(result)
            
            await MainActor.run {
                self.lastSyncTime = Date()
                self.lastError = nil
            }
            
            completionPublisher.send(publicResult)
            observerManager.notifyCompletion(publicResult)
            
            return publicResult
            
        } catch {
            let syncError = convertToPublicError(error)
            await MainActor.run {
                self.lastError = syncError
            }
            
            errorPublisher.send(syncError)
            observerManager.notifyFailure(syncError)
            
            throw syncError
        }
    }
    
    /// Start incremental sync for specific model type
    /// - Parameter modelType: The model type to sync
    /// - Returns: Result of the sync operation
    @discardableResult
    public func startIncrementalSync<T: Syncable>(for modelType: T.Type) async throws -> PublicSyncResult {
        guard authAPI.isAuthenticated else {
            throw SwiftSupabaseSyncError.authenticationFailed(reason: .sessionExpired)
        }
        
        do {
            let result = try await syncManager.startIncrementalSync(for: modelType)
            let publicResult = convertToPublicResult(result)
            
            completionPublisher.send(publicResult)
            observerManager.notifyCompletion(publicResult)
            
            return publicResult
            
        } catch {
            let syncError = convertToPublicError(error)
            errorPublisher.send(syncError)
            observerManager.notifyFailure(syncError)
            throw syncError
        }
    }
    
    /// Stop all sync operations
    public func stopSync() async {
        await syncManager.stopSync()
    }
    
    /// Pause ongoing sync operations
    public func pauseSync() async {
        await syncManager.pauseSync()
    }
    
    /// Resume paused sync operations
    public func resumeSync() async throws {
        guard authAPI.isAuthenticated else {
            throw SwiftSupabaseSyncError.authenticationFailed(reason: .sessionExpired)
        }
        
        try await syncManager.resumeSync()
    }
    
    // MARK: - Model Registration
    
    /// Register a model type for synchronization
    /// - Parameter modelType: The model type to register
    public func registerModel<T: Syncable>(_ modelType: T.Type) {
        syncManager.registerModel(modelType)
        registeredModels.insert(T.tableName)
    }
    
    /// Unregister a model type from synchronization
    /// - Parameter modelType: The model type to unregister
    public func unregisterModel<T: Syncable>(_ modelType: T.Type) {
        syncManager.unregisterModel(modelType)
        registeredModels.remove(T.tableName)
    }
    
    /// Register multiple model types at once
    /// - Parameter modelTypes: Array of model types to register
    public func registerModels(_ modelTypes: [any Syncable.Type]) {
        for modelType in modelTypes {
            syncManager.registerModel(modelType)
            registeredModels.insert(modelType.tableName)
        }
    }
    
    // MARK: - Conflict Management
    
    /// Get unresolved conflicts for a specific model type
    /// - Parameter modelType: The model type to check for conflicts
    /// - Returns: Array of conflict information
    public func getUnresolvedConflicts<T: Syncable>(for modelType: T.Type) async throws -> [ConflictInfo] {
        let conflicts = try await syncManager.getUnresolvedConflicts(for: modelType)
        return conflicts.map { convertToPublicConflict($0) }
    }
    
    /// Get all unresolved conflicts across all models
    /// - Returns: Array of all conflict information
    public func getAllUnresolvedConflicts() async -> [ConflictInfo] {
        let allConflicts: [ConflictInfo] = []
        
        // This would iterate through registered models and get conflicts
        // For now, return empty array as the implementation would require
        // more complex type handling
        
        return allConflicts
    }
    
    /// Resolve conflicts automatically using current policy
    /// - Parameter conflicts: Conflicts to resolve
    public func resolveConflicts(_ conflicts: [ConflictInfo]) async throws {
        // Convert public conflicts back to internal format and resolve
        // This would require mapping from ConflictInfo to SyncConflict
        // Implementation depends on the internal conflict resolution system
    }
    
    // MARK: - Configuration
    
    /// Update sync policy
    /// - Parameter policy: New sync policy to apply
    public func updateSyncPolicy(_ policy: SyncPolicyConfiguration) {
        self.syncPolicy = policy
        
        // Convert public policy to internal and apply
        let internalPolicy = convertToInternalPolicy(policy)
        syncManager.updateSyncPolicy(internalPolicy)
    }
    
    /// Enable or disable sync globally
    /// - Parameter enabled: Whether sync should be enabled
    public func setSyncEnabled(_ enabled: Bool) async {
        await syncManager.setSyncEnabled(enabled)
    }
    
    // MARK: - Sync Status & Information
    
    /// Get sync status for a specific model type
    /// - Parameter modelType: The model type to check
    /// - Returns: Sync status information
    public func getSyncStatus<T: Syncable>(for modelType: T.Type) async throws -> SyncOperationInfo {
        let status = try await syncManager.getSyncStatus(for: modelType)
        return convertToPublicOperationInfo(status, modelType: T.tableName)
    }
    
    /// Get last sync timestamp for a model type
    /// - Parameter modelType: The model type to check
    /// - Returns: Last sync date or nil if never synced
    public func getLastSyncTime<T: Syncable>(for modelType: T.Type) async throws -> Date? {
        return try await syncManager.getLastSyncTimestamp(for: modelType)
    }
    
    /// Clear sync errors and reset error state
    public func clearErrors() {
        lastError = nil
        syncManager.clearErrors()
    }
    
    // MARK: - Private Setup & Observation
    
    private func setupObservation() {
        // Observe sync manager state
        syncManager.$isSyncing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSyncing, on: self)
            .store(in: &cancellables)
        
        syncManager.$syncProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.progress = progress
                self?.observerManager.notifyProgressUpdate(progress)
            }
            .store(in: &cancellables)
        
        syncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] syncStatus in
                let publicStatus = self?.convertToPublicStatus(syncStatus.state) ?? .idle
                self?.status = publicStatus
                self?.observerManager.notifyStatusChange(publicStatus)
            }
            .store(in: &cancellables)
        
        syncManager.$unresolvedConflictsCount
            .receive(on: DispatchQueue.main)
            .assign(to: \.conflictCount, on: self)
            .store(in: &cancellables)
        
        syncManager.$isSyncEnabled
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSyncEnabled, on: self)
            .store(in: &cancellables)
        
        syncManager.$activeSyncOperations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] operations in
                self?.activeOperations = operations.values.compactMap { self?.convertToPublicOperationInfo($0) }
            }
            .store(in: &cancellables)
        
        // Observe auth state changes
        authAPI.$authenticationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authStatus in
                if authStatus == .signedOut {
                    Task { [weak self] in
                        await self?.stopSync()
                    }
                }
            }
            .store(in: &cancellables)
    }
}