//
//  SyncMetadataManager.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Manages sync metadata storage and retrieval
/// Handles sync status, timestamps, and state persistence
public actor SyncMetadataManager {
    
    // MARK: - Storage
    
    /// In-memory storage for sync metadata (in production, would use persistent storage)
    private var syncStatuses: [String: EntitySyncStatus] = [:]
    private var lastSyncTimestamps: [String: Date] = [:]
    private var syncOperations: [UUID: SyncOperationMetadata] = [:]
    
    /// Logger for debugging
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Initialization
    
    public init(logger: SyncLoggerProtocol? = nil) {
        self.logger = logger
    }
    
    // MARK: - Sync Status Management
    
    /// Get sync status for an entity type
    /// - Parameter entityType: The entity type name
    /// - Returns: Current sync status
    public func getSyncStatus(for entityType: String) -> EntitySyncStatus {
        if let status = syncStatuses[entityType] {
            return status
        }
        
        // Return default status if none exists
        return EntitySyncStatus(
            entityType: entityType,
            state: SyncState.idle,
            lastSyncAt: lastSyncTimestamps[entityType],
            pendingCount: 0
        )
    }
    
    /// Update sync status for an entity type
    /// - Parameters:
    ///   - status: New sync status
    ///   - entityType: The entity type name
    public func updateSyncStatus(_ status: EntitySyncStatus, for entityType: String) {
        syncStatuses[entityType] = status
        logger?.debug("SyncMetadataManager: Updated sync status for \(entityType): \(status.state)")
    }
    
    /// Update sync state for an entity type
    /// - Parameters:
    ///   - state: New sync state
    ///   - entityType: The entity type name
    ///   - pendingCount: Optional pending records count
    public func updateSyncState(_ state: SyncState, for entityType: String, pendingCount: Int? = nil) {
        let currentStatus = getSyncStatus(for: entityType)
        let newStatus = EntitySyncStatus(
            entityType: entityType,
            state: state,
            lastSyncAt: currentStatus.lastSyncAt,
            pendingCount: pendingCount ?? currentStatus.pendingCount
        )
        updateSyncStatus(newStatus, for: entityType)
    }
    
    // MARK: - Timestamp Management
    
    /// Get last sync timestamp for an entity type
    /// - Parameter entityType: The entity type name
    /// - Returns: Last sync timestamp or nil if never synced
    public func getLastSyncTimestamp(for entityType: String) -> Date? {
        return lastSyncTimestamps[entityType]
    }
    
    /// Set last sync timestamp for an entity type
    /// - Parameters:
    ///   - timestamp: The sync timestamp
    ///   - entityType: The entity type name
    public func setLastSyncTimestamp(_ timestamp: Date, for entityType: String) {
        lastSyncTimestamps[entityType] = timestamp
        
        // Update the sync status to reflect the new timestamp
        let currentStatus = getSyncStatus(for: entityType)
        let newStatus = EntitySyncStatus(
            entityType: entityType,
            state: currentStatus.state,
            lastSyncAt: timestamp,
            pendingCount: currentStatus.pendingCount
        )
        updateSyncStatus(newStatus, for: entityType)
        
        logger?.debug("SyncMetadataManager: Set last sync timestamp for \(entityType): \(timestamp)")
    }
    
    // MARK: - Sync Operation Tracking
    
    /// Start tracking a sync operation
    /// - Parameters:
    ///   - operationId: Unique operation ID
    ///   - entityType: Entity type being synced
    ///   - operationType: Type of sync operation
    /// - Returns: Sync operation metadata
    public func startSyncOperation(
        operationId: UUID = UUID(),
        entityType: String,
        operationType: SyncOperationType
    ) -> SyncOperationMetadata {
        let metadata = SyncOperationMetadata(
            id: operationId,
            entityType: entityType,
            operationType: operationType,
            startedAt: Date(),
            state: .running
        )
        
        syncOperations[operationId] = metadata
        
        // Update entity sync state to syncing
        updateSyncState(SyncState.syncing, for: entityType)
        
        logger?.debug("SyncMetadataManager: Started sync operation \(operationId) for \(entityType)")
        return metadata
    }
    
    /// Complete a sync operation
    /// - Parameters:
    ///   - operationId: Operation ID to complete
    ///   - success: Whether the operation was successful
    ///   - recordsProcessed: Number of records processed
    ///   - error: Optional error if operation failed
    public func completeSyncOperation(
        _ operationId: UUID,
        success: Bool,
        recordsProcessed: Int = 0,
        error: SyncError? = nil
    ) {
        guard var operation = syncOperations[operationId] else {
            logger?.warning("SyncMetadataManager: Attempted to complete unknown operation \(operationId)")
            return
        }
        
        // Update operation metadata
        operation.completedAt = Date()
        operation.state = success ? .completed : .failed
        operation.recordsProcessed = recordsProcessed
        operation.error = error
        syncOperations[operationId] = operation
        
        // Update entity sync state
        let newState: SyncState = success ? SyncState.completed : SyncState.failed
        updateSyncState(newState, for: operation.entityType)
        
        // If successful, update last sync timestamp
        if success {
            setLastSyncTimestamp(Date(), for: operation.entityType)
        }
        
        logger?.info("SyncMetadataManager: Completed sync operation \(operationId) - success: \(success)")
    }
    
    /// Get sync operation metadata
    /// - Parameter operationId: Operation ID to retrieve
    /// - Returns: Operation metadata if found
    public func getSyncOperation(_ operationId: UUID) -> SyncOperationMetadata? {
        return syncOperations[operationId]
    }
    
    /// Get all active sync operations
    /// - Returns: Array of active sync operations
    public func getActiveSyncOperations() -> [SyncOperationMetadata] {
        return syncOperations.values.filter { $0.state == .running }
    }
    
    // MARK: - Record Sync Tracking
    
    /// Track that specific records have been synced
    /// - Parameters:
    ///   - syncIDs: Array of sync IDs that were synced
    ///   - timestamp: Sync timestamp
    ///   - entityType: Entity type name
    public func markRecordsAsSynced(
        _ syncIDs: [UUID],
        at timestamp: Date,
        for entityType: String
    ) {
        // Update last sync timestamp
        setLastSyncTimestamp(timestamp, for: entityType)
        
        // Update pending count (simplified - would need actual count from data source)
        let currentStatus = getSyncStatus(for: entityType)
        let newPendingCount = max(0, currentStatus.pendingCount - syncIDs.count)
        
        let newStatus = EntitySyncStatus(
            entityType: entityType,
            state: currentStatus.state,
            lastSyncAt: timestamp,
            pendingCount: newPendingCount
        )
        updateSyncStatus(newStatus, for: entityType)
        
        logger?.debug("SyncMetadataManager: Marked \(syncIDs.count) records as synced for \(entityType)")
    }
    
    // MARK: - Cleanup
    
    /// Clean up old sync metadata
    /// - Parameter olderThan: Date threshold for cleanup
    public func cleanupOldMetadata(olderThan: Date) {
        let beforeCount = syncOperations.count
        
        // Remove old completed operations
        syncOperations = syncOperations.filter { _, operation in
            if let completedAt = operation.completedAt {
                return completedAt > olderThan
            }
            return true // Keep running operations
        }
        
        let removedCount = beforeCount - syncOperations.count
        logger?.info("SyncMetadataManager: Cleaned up \(removedCount) old sync operations")
    }
    
    /// Reset all metadata (useful for testing)
    public func reset() {
        syncStatuses.removeAll()
        lastSyncTimestamps.removeAll()
        syncOperations.removeAll()
        logger?.debug("SyncMetadataManager: Reset all metadata")
    }
}

// MARK: - Supporting Types

/// Metadata for tracking sync operations
public struct SyncOperationMetadata {
    public let id: UUID
    public let entityType: String
    public let operationType: SyncOperationType
    public let startedAt: Date
    public var completedAt: Date?
    public var state: SyncOperationState
    public var recordsProcessed: Int
    public var error: SyncError?
    
    public init(
        id: UUID,
        entityType: String,
        operationType: SyncOperationType,
        startedAt: Date,
        state: SyncOperationState = .pending,
        recordsProcessed: Int = 0,
        error: SyncError? = nil
    ) {
        self.id = id
        self.entityType = entityType
        self.operationType = operationType
        self.startedAt = startedAt
        self.state = state
        self.recordsProcessed = recordsProcessed
        self.error = error
    }
    
    /// Duration of the operation
    public var duration: TimeInterval {
        let endTime = completedAt ?? Date()
        return endTime.timeIntervalSince(startedAt)
    }
}

/// State of a sync operation
public enum SyncOperationState: String, CaseIterable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

