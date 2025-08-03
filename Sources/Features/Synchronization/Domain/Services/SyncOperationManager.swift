//
//  SyncOperationManager.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Context information for a sync operation
internal struct SyncOperationContext {
    let id: UUID
    let type: SyncOperationType
    let entityType: String
    let user: User
    let policy: SyncPolicy
    let startedAt: Date
    var status: SyncContextStatus
    
    init(
        id: UUID,
        type: SyncOperationType,
        entityType: String,
        user: User,
        policy: SyncPolicy,
        startedAt: Date,
        status: SyncContextStatus = .running
    ) {
        self.id = id
        self.type = type
        self.entityType = entityType
        self.user = user
        self.policy = policy
        self.startedAt = startedAt
        self.status = status
    }
    
    /// Create a copy with updated status
    func withStatus(_ newStatus: SyncContextStatus) -> SyncOperationContext {
        var copy = self
        copy.status = newStatus
        return copy
    }
}

/// Status of a sync operation context
public enum SyncContextStatus: String, Codable, CaseIterable {
    case running = "running"
    case cancelled = "cancelled"
    case completed = "completed"
    case failed = "failed"
}

/// Actor responsible for managing concurrent sync operations
internal actor SyncOperationManager {
    // MARK: - Properties
    
    private var activeSyncOperations: [UUID: SyncOperationContext] = [:]
    private let maxConcurrentSyncs: Int
    
    // MARK: - Initialization
    
    init(maxConcurrentSyncs: Int) {
        self.maxConcurrentSyncs = maxConcurrentSyncs
    }
    
    // MARK: - Operation Management
    
    /// Register a new sync operation
    /// - Parameter context: Operation context to register
    /// - Throws: SyncError if maximum concurrent operations exceeded
    func registerOperation(_ context: SyncOperationContext) throws {
        guard activeSyncOperations.count < maxConcurrentSyncs else {
            throw SyncError.rateLimitExceeded
        }
        activeSyncOperations[context.id] = context
    }
    
    /// Unregister a completed sync operation
    /// - Parameter operationID: ID of operation to unregister
    func unregisterOperation(_ operationID: UUID) {
        activeSyncOperations.removeValue(forKey: operationID)
    }
    
    /// Get count of currently active sync operations
    /// - Returns: Number of active operations
    func getActiveSyncCount() -> Int {
        return activeSyncOperations.count
    }
    
    /// Get all active sync operations
    /// - Returns: Dictionary of active operations
    func getActiveOperations() -> [UUID: SyncOperationContext] {
        return activeSyncOperations
    }
    
    /// Cancel a specific sync operation
    /// - Parameter operationID: ID of operation to cancel
    /// - Returns: Cancellation result
    func cancelOperation(_ operationID: UUID) -> SyncCancellationResult {
        guard let context = activeSyncOperations[operationID] else {
            return SyncCancellationResult(
                success: false,
                operationID: operationID,
                error: .operationNotFound
            )
        }
        
        // Check if operation is already completed
        if context.status == .completed || context.status == .failed {
            return SyncCancellationResult(
                success: false,
                operationID: operationID,
                error: .operationAlreadyCompleted
            )
        }
        
        // Mark as cancelled
        activeSyncOperations[operationID] = context.withStatus(.cancelled)
        
        return SyncCancellationResult(
            success: true,
            operationID: operationID
        )
    }
    
    /// Cancel all active sync operations
    /// - Returns: Array of cancellation results
    func cancelAllOperations() -> [SyncCancellationResult] {
        let operationIDs = Array(activeSyncOperations.keys)
        return operationIDs.map { cancelOperation($0) }
    }
    
    /// Check if an operation can be started given current constraints
    /// - Returns: Whether a new operation can be started
    func canStartNewOperation() -> Bool {
        return activeSyncOperations.count < maxConcurrentSyncs
    }
    
    /// Get operations for a specific user
    /// - Parameter userID: User ID to filter by
    /// - Returns: Operations belonging to the user
    func getOperationsForUser(_ userID: UUID) -> [SyncOperationContext] {
        return activeSyncOperations.values.filter { $0.user.id == userID }
    }
    
    /// Get operations for a specific entity type
    /// - Parameter entityType: Entity type to filter by
    /// - Returns: Operations for the entity type
    func getOperationsForEntityType(_ entityType: String) -> [SyncOperationContext] {
        return activeSyncOperations.values.filter { $0.entityType == entityType }
    }
    
    /// Update operation status
    /// - Parameters:
    ///   - operationID: ID of operation to update
    ///   - status: New status to set
    func updateOperationStatus(_ operationID: UUID, status: SyncContextStatus) {
        guard let context = activeSyncOperations[operationID] else { return }
        activeSyncOperations[operationID] = context.withStatus(status)
    }
}

// MARK: - Extensions

internal extension SyncOperationManager {
    /// Get summary of active operations
    var summary: String {
        let count = activeSyncOperations.count
        if count == 0 {
            return "No active sync operations"
        }
        
        let byType = Dictionary(grouping: activeSyncOperations.values) { $0.type }
        let typesSummary = byType.map { type, operations in
            "\(type.rawValue): \(operations.count)"
        }.joined(separator: ", ")
        
        return "Active operations (\(count)/\(maxConcurrentSyncs)): \(typesSummary)"
    }
    
    /// Check if manager is at capacity
    var isAtCapacity: Bool {
        return activeSyncOperations.count >= maxConcurrentSyncs
    }
    
    /// Get the oldest active operation
    var oldestOperation: SyncOperationContext? {
        return activeSyncOperations.values.min { $0.startedAt < $1.startedAt }
    }
}