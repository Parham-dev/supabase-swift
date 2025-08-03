//
//  SyncAPI.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftData

// MARK: - Public Sync Status Enums

/// Public sync status enumeration for API consumers
public enum PublicSyncStatus: String, CaseIterable, Sendable {
    case idle = "idle"
    case preparing = "preparing"
    case syncing = "syncing"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    /// Whether sync is currently active
    public var isActive: Bool {
        switch self {
        case .preparing, .syncing: return true
        case .idle, .paused, .completed, .failed, .cancelled: return false
        }
    }
    
    /// Whether sync can be resumed
    public var canResume: Bool {
        switch self {
        case .paused, .failed: return true
        case .idle, .preparing, .syncing, .completed, .cancelled: return false
        }
    }
}

/// Public sync operation result for API consumers
public struct PublicSyncResult: Sendable {
    
    /// Whether the sync operation was successful
    public let success: Bool
    
    /// Number of records uploaded to server
    public let uploadedCount: Int
    
    /// Number of records downloaded from server
    public let downloadedCount: Int
    
    /// Number of conflicts encountered
    public let conflictCount: Int
    
    /// Operation duration in seconds
    public let duration: TimeInterval
    
    /// List of models that were synced
    public let syncedModels: [String]
    
    /// Human-readable summary of the operation
    public let summary: String
    
    /// When the operation completed
    public let completedAt: Date
    
    public init(
        success: Bool,
        uploadedCount: Int = 0,
        downloadedCount: Int = 0,
        conflictCount: Int = 0,
        duration: TimeInterval = 0,
        syncedModels: [String] = [],
        summary: String = "",
        completedAt: Date = Date()
    ) {
        self.success = success
        self.uploadedCount = uploadedCount
        self.downloadedCount = downloadedCount
        self.conflictCount = conflictCount
        self.duration = duration
        self.syncedModels = syncedModels
        self.summary = summary
        self.completedAt = completedAt
    }
}

// MARK: - Sync Observer Protocol

/// Protocol for observing sync state changes
public protocol SyncObserver: AnyObject {
    /// Called when sync status changes
    func syncStatusDidChange(_ status: PublicSyncStatus)
    
    /// Called when sync progress updates
    func syncProgressDidUpdate(_ progress: Double)
    
    /// Called when sync operation completes
    func syncDidComplete(_ result: PublicSyncResult)
    
    /// Called when sync encounters an error
    func syncDidFail(_ error: SwiftSupabaseSyncError)
    
    /// Called when conflicts are detected
    func syncDidDetectConflicts(_ conflicts: [ConflictInfo])
}

// MARK: - Sync Observer Manager

/// Internal manager for sync observers using weak references
internal final class SyncObserverManager: @unchecked Sendable {
    private var observers: [WeakSyncObserver] = []
    private let queue = DispatchQueue(label: "sync.observers", qos: .userInteractive)
    
    func addObserver(_ observer: SyncObserver) {
        queue.async {
            // Remove any nil references
            self.observers = self.observers.filter { $0.observer != nil }
            
            // Add new observer if not already present
            if !self.observers.contains(where: { $0.observer === observer }) {
                self.observers.append(WeakSyncObserver(observer: observer))
            }
        }
    }
    
    func removeObserver(_ observer: SyncObserver) {
        queue.async {
            self.observers = self.observers.filter { $0.observer !== observer }
        }
    }
    
    func notifyStatusChange(_ status: PublicSyncStatus) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncStatusDidChange(status)
            }
        }
    }
    
    func notifyProgressUpdate(_ progress: Double) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncProgressDidUpdate(progress)
            }
        }
    }
    
    func notifyCompletion(_ result: PublicSyncResult) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncDidComplete(result)
            }
        }
    }
    
    func notifyFailure(_ error: SwiftSupabaseSyncError) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncDidFail(error)
            }
        }
    }
    
    func notifyConflicts(_ conflicts: [ConflictInfo]) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncDidDetectConflicts(conflicts)
            }
        }
    }
}

/// Weak reference wrapper for sync observers
private struct WeakSyncObserver {
    weak var observer: SyncObserver?
}

// MARK: - SyncAPI Main Class

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
    
    private let syncManager: SyncManager
    private let authAPI: AuthAPI
    private let observerManager = SyncObserverManager()
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
    
    // MARK: - Observer Management
    
    /// Add an observer for sync events
    /// - Parameter observer: The observer to add
    public func addObserver(_ observer: SyncObserver) {
        observerManager.addObserver(observer)
    }
    
    /// Remove an observer
    /// - Parameter observer: The observer to remove
    public func removeObserver(_ observer: SyncObserver) {
        observerManager.removeObserver(observer)
    }
    
    // MARK: - Utilities
    
    /// Check if sync can be started given current conditions
    /// - Returns: Whether sync is eligible to start
    public func canStartSync() async -> Bool {
        guard authAPI.isAuthenticated else { return false }
        guard isSyncEnabled else { return false }
        guard !isSyncing else { return false }
        
        return true
    }
    
    /// Get a summary of current sync state
    /// - Returns: Human-readable sync summary
    public func getSyncSummary() -> String {
        let statusText = status.rawValue.capitalized
        let modelsText = "\(registeredModels.count) models"
        let conflictsText = conflictCount > 0 ? ", \(conflictCount) conflicts" : ""
        let timeText = lastSyncTime.map { "Last sync: \(formatRelativeTime($0))" } ?? "Never synced"
        
        return "\(statusText) • \(modelsText)\(conflictsText) • \(timeText)"
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
    
    // MARK: - Private Conversion Methods
    
    private func convertToPublicStatus(_ internalStatus: SyncState) -> PublicSyncStatus {
        switch internalStatus {
        case .idle: return .idle
        case .preparing: return .preparing
        case .syncing: return .syncing
        case .paused: return .paused
        case .completed: return .completed
        case .failed: return .failed
        case .cancelled: return .cancelled
        }
    }
    
    private func convertToPublicResult(_ internalResult: SyncOperationResult) -> PublicSyncResult {
        let models = [internalResult.operation.entityType]
        let summary = internalResult.success 
            ? "Successfully synced \(internalResult.uploadedCount + internalResult.downloadedCount) items"
            : "Sync failed: \(internalResult.errors.first?.localizedDescription ?? "Unknown error")"
        
        return PublicSyncResult(
            success: internalResult.success,
            uploadedCount: internalResult.uploadedCount,
            downloadedCount: internalResult.downloadedCount,
            conflictCount: internalResult.conflictCount,
            duration: internalResult.duration,
            syncedModels: models,
            summary: summary,
            completedAt: internalResult.completedAt
        )
    }
    
    private func convertToPublicError(_ error: Error) -> SwiftSupabaseSyncError {
        if let syncError = error as? SyncError {
            switch syncError {
            case .networkUnavailable:
                return .networkUnavailable
            case .authenticationFailed:
                return .authenticationFailed(reason: .sessionExpired)
            case .serverError(let code):
                return .serverError(statusCode: code, message: "Server error")
            case .subscriptionRequired:
                return .subscriptionRequired(feature: .basicSync, currentTier: .free)
            case .unknownError(_):
                return .unknown(underlyingError: nil)
            default:
                return .unknown(underlyingError: syncError)
            }
        }
        
        return .unknown(underlyingError: error)
    }
    
    private func convertToPublicConflict(_ internalConflict: SyncConflict) -> ConflictInfo {
        // This would convert internal SyncConflict to public ConflictInfo
        // The exact implementation depends on the SyncConflict structure
        return ConflictInfo(
            modelType: "unknown", // Would be extracted from conflict
            recordID: "unknown",  // Would be extracted from conflict
            localVersion: "local_data",   // Would be serialized from conflict
            remoteVersion: "remote_data", // Would be serialized from conflict
            resolutionStrategy: .askUser
        )
    }
    
    private func convertToInternalPolicy(_ publicPolicy: SyncPolicyConfiguration) -> SyncPolicy {
        let settings = publicPolicy.settings
        
        return SyncPolicy(
            name: "Public API Policy",
            frequency: convertToInternalFrequency(settings.syncFrequency),
            wifiOnly: settings.requiresWifi,
            allowBackgroundSync: true, // Default for public API
            enableRealtimeSync: true,  // Default for public API
            maxRetries: settings.retryAttempts,
            batchSize: settings.batchSize
        )
    }
    
    private func convertToInternalFrequency(_ publicFrequency: PublicSyncFrequency) -> SyncFrequency {
        switch publicFrequency {
        case .automatic: return .automatic
        case .manual: return .manual
        case .interval(let seconds): return .interval(seconds)
        }
    }
    
    private func convertToPublicOperationInfo(_ entityStatus: EntitySyncStatus, modelType: String) -> SyncOperationInfo {
        let type: PublicSyncOperationType = .incrementalSync // Default for entity status
        let status = convertToPublicOperationStatus(entityStatus.state)
        
        return SyncOperationInfo(
            id: UUID(), // Generate new ID since EntitySyncStatus doesn't have one
            type: type,
            models: [modelType],
            startTime: entityStatus.lastSyncAt ?? entityStatus.statusAt,
            status: status
        )
    }
    
    private func convertToPublicOperationInfo(_ operation: SyncOperation) -> SyncOperationInfo {
        let type = convertToPublicOperationType(operation.type)
        let status = convertToPublicOperationStatus(operation.status)
        
        return SyncOperationInfo(
            id: operation.id,
            type: type,
            models: [operation.entityType],
            startTime: operation.startedAt ?? operation.createdAt,
            status: status
        )
    }
    
    private func convertToPublicOperationType(_ internalType: SyncOperationType) -> PublicSyncOperationType {
        switch internalType {
        case .fullSync: return .fullSync
        case .incrementalSync: return .incrementalSync
        case .upload: return .upload
        case .download: return .download
        }
    }
    
    private func convertToPublicOperationStatus(_ internalStatus: SyncState) -> PublicSyncOperationStatus {
        switch internalStatus {
        case .idle: return .pending
        case .preparing: return .pending
        case .syncing: return .running
        case .paused: return .paused
        case .completed: return .completed
        case .failed: return .failed
        case .cancelled: return .cancelled
        }
    }
    
    private func convertToPublicOperationStatus(_ internalStatus: SyncOperationStatus) -> PublicSyncOperationStatus {
        switch internalStatus {
        case .pending: return .pending
        case .running: return .running
        case .completed: return .completed
        case .failed: return .failed
        case .cancelled: return .cancelled
        }
    }
    
    // MARK: - Utility Functions
    
    private func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Public Extensions

public extension SyncAPI {
    
    /// Convenience method to start sync and wait for completion
    /// - Returns: Whether sync completed successfully
    @discardableResult
    func syncAndWait() async throws -> Bool {
        let result = try await startSync()
        return result.success
    }
    
    /// Convenience method to register multiple models by type
    /// - Parameter types: Variadic list of Syncable types to register
    func registerModels<T: Syncable>(_ types: T.Type...) {
        for type in types {
            registerModel(type)
        }
    }
}
