//
//  SyncStatusPublisher.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Combine
import SwiftUI

/// Reactive publisher that wraps SyncManager state for seamless SwiftUI integration
/// Provides clean, observable access to sync status, progress, and operations
@MainActor
public final class SyncStatusPublisher: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current sync status with detailed operation information
    @Published public private(set) var syncStatus: SyncStatus
    
    /// Whether sync is currently active
    @Published public private(set) var isSyncing: Bool
    
    /// Whether sync is enabled by user/policy
    @Published public private(set) var isSyncEnabled: Bool
    
    /// Current sync progress (0.0 to 1.0)
    @Published public private(set) var syncProgress: Double
    
    /// Last sync error encountered
    @Published public private(set) var lastSyncError: SyncError?
    
    /// Active sync operations by entity type
    @Published public private(set) var activeSyncOperations: [String: SyncOperation]
    
    /// Number of unresolved conflicts requiring user attention
    @Published public private(set) var unresolvedConflictsCount: Int
    
    // MARK: - Derived Published Properties
    
    /// Whether there are any active sync operations
    @Published public private(set) var hasActiveSyncOperations: Bool = false
    
    /// Whether sync is in error state
    @Published public private(set) var hasError: Bool = false
    
    /// User-friendly sync status description
    @Published public private(set) var statusDescription: String = "Ready"
    
    /// Sync progress percentage for display (0-100)
    @Published public private(set) var progressPercentage: Int = 0
    
    /// Whether conflicts need user attention
    @Published public private(set) var requiresConflictResolution: Bool = false
    
    // MARK: - Dependencies
    
    private let syncManager: SyncManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(syncManager: SyncManager) {
        self.syncManager = syncManager
        
        // Initialize with current values
        self.syncStatus = syncManager.syncStatus
        self.isSyncing = syncManager.isSyncing
        self.isSyncEnabled = syncManager.isSyncEnabled
        self.syncProgress = syncManager.syncProgress
        self.lastSyncError = syncManager.lastSyncError
        self.activeSyncOperations = syncManager.activeSyncOperations
        self.unresolvedConflictsCount = syncManager.unresolvedConflictsCount
        
        // Calculate derived properties
        updateDerivedProperties()
        
        // Setup reactive bindings
        setupPublisherBindings()
    }
    
    // MARK: - Public Computed Properties
    
    /// Whether sync is currently idle (not syncing and no errors)
    public var isIdle: Bool {
        !isSyncing && !hasError
    }
    
    /// Whether sync can be started (enabled and not currently syncing)
    public var canStartSync: Bool {
        isSyncEnabled && !isSyncing
    }
    
    /// Whether sync can be stopped (currently syncing)
    public var canStopSync: Bool {
        isSyncing
    }
    
    /// Current sync state from SyncStatus
    public var currentSyncState: SyncState {
        syncStatus.state
    }
    
    /// Time since last successful sync
    public var timeSinceLastSync: TimeInterval? {
        if let lastFullSync = syncStatus.lastFullSyncAt {
            return Date().timeIntervalSince(lastFullSync)
        } else if let lastIncrementalSync = syncStatus.lastIncrementalSyncAt {
            return Date().timeIntervalSince(lastIncrementalSync)
        }
        return nil
    }
    
    /// Formatted time since last sync for display
    public var formattedTimeSinceLastSync: String {
        guard let timeSince = timeSinceLastSync else {
            return "Never"
        }
        
        if timeSince < 60 {
            return "Just now"
        } else if timeSince < 3600 {
            let minutes = Int(timeSince / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeSince < 86400 {
            let hours = Int(timeSince / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(timeSince / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    // MARK: - Sync Control Methods
    
    /// Start sync operation
    public func startSync() async {
        do {
            try await syncManager.startSync()
        } catch {
            // Error handling is managed by SyncManager's published properties
            // The UI will react to lastSyncError being set
        }
    }
    
    /// Stop current sync operation
    public func stopSync() async {
        await syncManager.stopSync()
    }
    
    /// Pause sync operation
    public func pauseSync() async {
        await syncManager.pauseSync()
    }
    
    /// Resume paused sync operation
    public func resumeSync() async {
        do {
            try await syncManager.resumeSync()
        } catch {
            // Error handling is managed by SyncManager's published properties
        }
    }
    
    /// Enable or disable sync
    public func setSyncEnabled(_ enabled: Bool) async {
        await syncManager.setSyncEnabled(enabled)
    }
    
    /// Clear current sync error
    public func clearError() {
        syncManager.clearErrors()
    }
    
    // MARK: - Model Management
    
    /// Register a model type for synchronization
    public func registerModel<T: Syncable>(_ modelType: T.Type) {
        syncManager.registerModel(modelType)
    }
    
    /// Unregister a model type from synchronization
    public func unregisterModel<T: Syncable>(_ modelType: T.Type) {
        syncManager.unregisterModel(modelType)
    }
    
    /// Get all registered model types
    public var registeredModelTypes: Set<String> {
        syncManager.registeredModelTypes
    }
    
    // MARK: - Conflict Management
    
    /// Get unresolved conflicts for a specific entity type
    public func getUnresolvedConflicts<T: Syncable>(for entityType: T.Type) async throws -> [SyncConflict] {
        return try await syncManager.getUnresolvedConflicts(for: entityType)
    }
    
    /// Resolve conflicts using the configured resolver
    public func resolveConflicts(_ conflicts: [SyncConflict]) async throws -> [ConflictResolution] {
        return try await syncManager.resolveConflicts(conflicts)
    }
    
    // MARK: - Private Implementation
    
    private func setupPublisherBindings() {
        // Bind SyncManager's published properties to our published properties
        syncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        syncManager.$isSyncing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isSyncing in
                self?.isSyncing = isSyncing
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        syncManager.$isSyncEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isSyncEnabled = isEnabled
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        syncManager.$syncProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.syncProgress = progress
                self?.progressPercentage = Int(progress * 100)
            }
            .store(in: &cancellables)
        
        syncManager.$lastSyncError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.lastSyncError = error
                self?.hasError = error != nil
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        syncManager.$activeSyncOperations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] operations in
                self?.activeSyncOperations = operations
                self?.hasActiveSyncOperations = !operations.isEmpty
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        syncManager.$unresolvedConflictsCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.unresolvedConflictsCount = count
                self?.requiresConflictResolution = count > 0
            }
            .store(in: &cancellables)
    }
    
    private func updateDerivedProperties() {
        // Update status description based on current state
        if let error = lastSyncError {
            statusDescription = "Error: \(error.localizedDescription)"
        } else if isSyncing {
            if hasActiveSyncOperations {
                let operationCount = activeSyncOperations.count
                statusDescription = "Syncing \(operationCount) operation\(operationCount == 1 ? "" : "s")..."
            } else {
                statusDescription = "Starting sync..."
            }
        } else if !isSyncEnabled {
            statusDescription = "Sync disabled"
        } else {
            switch syncStatus.state {
            case .idle:
                statusDescription = "Ready"
            case .preparing:
                statusDescription = "Preparing..."
            case .syncing:
                statusDescription = "Syncing..."
            case .paused:
                statusDescription = "Paused"
            case .completed:
                statusDescription = "Completed"
            case .failed:
                statusDescription = "Failed"
            case .cancelled:
                statusDescription = "Cancelled"
            }
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - SwiftUI Convenience Extensions

public extension SyncStatusPublisher {
    
    /// SwiftUI binding for sync enabled state
    var syncEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.isSyncEnabled },
            set: { enabled in
                Task {
                    await self.setSyncEnabled(enabled)
                }
            }
        )
    }
    
    /// Color for current sync status (for UI indicators)
    var statusColor: Color {
        if hasError {
            return .red
        } else if isSyncing {
            return .blue
        } else if requiresConflictResolution {
            return .orange
        } else if isSyncEnabled {
            return .green
        } else {
            return .gray
        }
    }
    
    /// SF Symbol name for current sync status
    var statusIcon: String {
        if hasError {
            return "exclamationmark.triangle.fill"
        } else if isSyncing {
            return "arrow.triangle.2.circlepath"
        } else if requiresConflictResolution {
            return "exclamationmark.circle.fill"
        } else if isSyncEnabled {
            return "checkmark.circle.fill"
        } else {
            return "pause.circle.fill"
        }
    }
}

// MARK: - Combine Publishers

public extension SyncStatusPublisher {
    
    /// Publisher that emits when sync state changes significantly
    var syncStateChangePublisher: AnyPublisher<SyncState, Never> {
        $syncStatus
            .map(\.state)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when sync progress updates
    var progressPublisher: AnyPublisher<Double, Never> {
        $syncProgress
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when errors occur or are cleared
    var errorPublisher: AnyPublisher<SyncError?, Never> {
        $lastSyncError
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when conflicts need resolution
    var conflictResolutionPublisher: AnyPublisher<Bool, Never> {
        $requiresConflictResolution
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}