import Foundation

/// Domain entity representing the synchronization status and state
/// Tracks sync operations, progress, and overall sync health
public struct SyncStatus {
    
    // MARK: - Core Properties
    
    /// Unique identifier for this sync status instance
    public let id: UUID
    
    /// Current synchronization state
    public let state: SyncState
    
    /// Overall sync progress (0.0 to 1.0)
    public let progress: Double
    
    /// Timestamp when the sync status was created
    public let createdAt: Date
    
    /// Timestamp when the sync status was last updated
    public let updatedAt: Date
    
    // MARK: - Operation Details
    
    /// Current or last sync operation details
    public let operation: SyncOperation?
    
    /// Number of items being synchronized
    public let totalItems: Int
    
    /// Number of items successfully synchronized
    public let completedItems: Int
    
    /// Number of items that failed to sync
    public let failedItems: Int
    
    // MARK: - Connection & Health
    
    /// Whether the device is connected to the network
    public let isConnected: Bool
    
    /// Whether real-time sync is active
    public let isRealtimeActive: Bool
    
    /// Last successful connection timestamp
    public let lastConnectedAt: Date?
    
    // MARK: - Error Information
    
    /// Last error encountered during sync
    public let lastError: SyncError?
    
    /// Timestamp of the last error
    public let lastErrorAt: Date?
    
    /// Number of retry attempts for current operation
    public let retryCount: Int
    
    /// Maximum retry attempts allowed
    public let maxRetries: Int
    
    // MARK: - Sync History
    
    /// Last successful full sync timestamp
    public let lastFullSyncAt: Date?
    
    /// Last successful incremental sync timestamp
    public let lastIncrementalSyncAt: Date?
    
    // MARK: - Initializer
    
    public init(
        id: UUID = UUID(),
        state: SyncState = .idle,
        progress: Double = 0.0,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        operation: SyncOperation? = nil,
        totalItems: Int = 0,
        completedItems: Int = 0,
        failedItems: Int = 0,
        isConnected: Bool = false,
        isRealtimeActive: Bool = false,
        lastConnectedAt: Date? = nil,
        lastError: SyncError? = nil,
        lastErrorAt: Date? = nil,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        lastFullSyncAt: Date? = nil,
        lastIncrementalSyncAt: Date? = nil
    ) {
        self.id = id
        self.state = state
        self.progress = max(0.0, min(1.0, progress))
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.operation = operation
        self.totalItems = totalItems
        self.completedItems = completedItems
        self.failedItems = failedItems
        self.isConnected = isConnected
        self.isRealtimeActive = isRealtimeActive
        self.lastConnectedAt = lastConnectedAt
        self.lastError = lastError
        self.lastErrorAt = lastErrorAt
        self.retryCount = retryCount
        self.maxRetries = maxRetries
        self.lastFullSyncAt = lastFullSyncAt
        self.lastIncrementalSyncAt = lastIncrementalSyncAt
    }
}

// MARK: - Supporting Types

public enum SyncState: String, CaseIterable, Codable, Equatable {
    case idle = "idle"
    case preparing = "preparing"
    case syncing = "syncing"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    /// Whether the sync is currently active
    public var isActive: Bool {
        switch self {
        case .preparing, .syncing:
            return true
        case .idle, .paused, .completed, .failed, .cancelled:
            return false
        }
    }
    
    /// Whether the sync can be resumed
    public var canResume: Bool {
        switch self {
        case .paused, .failed:
            return true
        case .idle, .preparing, .syncing, .completed, .cancelled:
            return false
        }
    }
    
    /// Whether the sync requires user intervention
    public var requiresIntervention: Bool {
        switch self {
        case .failed:
            return true
        case .idle, .preparing, .syncing, .paused, .completed, .cancelled:
            return false
        }
    }
}

public struct SyncOperation: Codable, Equatable {
    /// Unique identifier for the operation
    public let id: UUID
    
    /// Type of sync operation
    public let type: SyncOperationType
    
    /// Entity or model being synchronized
    public let entityType: String
    
    /// Number of items in this operation
    public let itemCount: Int
    
    /// Timestamp when operation was created
    public let createdAt: Date
    
    /// Timestamp when operation started
    public let startedAt: Date?
    
    /// Timestamp when operation completed
    public let completedAt: Date?
    
    /// Current status of the operation
    public let status: SyncOperationStatus
    
    /// Error if operation failed
    public let error: SyncError?
    
    public init(
        id: UUID = UUID(),
        type: SyncOperationType,
        entityType: String,
        itemCount: Int = 1,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        status: SyncOperationStatus = .pending,
        error: SyncError? = nil
    ) {
        self.id = id
        self.type = type
        self.entityType = entityType
        self.itemCount = itemCount
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.error = error
    }
}

public enum SyncOperationType: String, Codable, Equatable {
    case fullSync = "full_sync"
    case incrementalSync = "incremental_sync"
    case upload = "upload"
    case download = "download"
}

public enum SyncOperationStatus: String, Codable, Equatable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    /// Whether the operation is currently active
    public var isActive: Bool {
        return self == .running
    }
    
    /// Whether the operation has finished (successfully or not)
    public var isFinished: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        case .pending, .running:
            return false
        }
    }
}

public enum SyncError: Error, LocalizedError, Codable, Equatable {
    case networkUnavailable
    case authenticationFailed
    case serverError(Int)
    case dataCorruption
    case quotaExceeded
    case rateLimitExceeded
    case subscriptionRequired
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .authenticationFailed:
            return "Authentication failed during sync"
        case .serverError(let code):
            return "Server error occurred (code: \(code))"
        case .dataCorruption:
            return "Data corruption detected"
        case .quotaExceeded:
            return "Storage quota exceeded"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .subscriptionRequired:
            return "Pro subscription required for this feature"
        case .unknownError(let message):
            return "Sync error: \(message)"
        }
    }
    
    /// Whether the error is recoverable with retry
    public var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .serverError, .rateLimitExceeded:
            return true
        case .authenticationFailed, .dataCorruption, .quotaExceeded, .subscriptionRequired, .unknownError:
            return false
        }
    }
    
    /// Recommended retry delay in seconds
    public var retryDelay: TimeInterval {
        switch self {
        case .networkUnavailable:
            return 5.0
        case .serverError:
            return 10.0
        case .rateLimitExceeded:
            return 60.0
        case .authenticationFailed, .dataCorruption, .quotaExceeded, .subscriptionRequired, .unknownError:
            return 0.0
        }
    }
}

// MARK: - SyncStatus Extensions

extension SyncStatus {
    /// Check if sync is currently active
    public var isActive: Bool {
        return state.isActive
    }
    
    /// Check if sync requires user intervention
    public var requiresIntervention: Bool {
        return state.requiresIntervention
    }
    
    /// Check if sync can be started
    public var canStart: Bool {
        return state == .idle && isConnected
    }
    
    /// Check if sync can be paused
    public var canPause: Bool {
        return state.isActive
    }
    
    /// Check if sync can be resumed
    public var canResume: Bool {
        return state.canResume && isConnected
    }
    
    /// Get remaining items to sync
    public var remainingItems: Int {
        return max(0, totalItems - completedItems)
    }
    
    /// Get overall sync success rate
    public var successRate: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(completedItems) / Double(totalItems)
    }
    
    /// Get error rate
    public var errorRate: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(failedItems) / Double(totalItems)
    }
    
    /// Create a copy with updated state
    public func withState(_ newState: SyncState) -> SyncStatus {
        SyncStatus(
            id: id,
            state: newState,
            progress: progress,
            createdAt: createdAt,
            updatedAt: Date(),
            operation: operation,
            totalItems: totalItems,
            completedItems: completedItems,
            failedItems: failedItems,
            isConnected: isConnected,
            isRealtimeActive: isRealtimeActive,
            lastConnectedAt: lastConnectedAt,
            lastError: lastError,
            lastErrorAt: lastErrorAt,
            retryCount: retryCount,
            maxRetries: maxRetries,
            lastFullSyncAt: lastFullSyncAt,
            lastIncrementalSyncAt: lastIncrementalSyncAt
        )
    }
    
    /// Create a copy with updated progress
    public func withProgress(_ newProgress: Double) -> SyncStatus {
        SyncStatus(
            id: id,
            state: state,
            progress: newProgress,
            createdAt: createdAt,
            updatedAt: Date(),
            operation: operation,
            totalItems: totalItems,
            completedItems: completedItems,
            failedItems: failedItems,
            isConnected: isConnected,
            isRealtimeActive: isRealtimeActive,
            lastConnectedAt: lastConnectedAt,
            lastError: lastError,
            lastErrorAt: lastErrorAt,
            retryCount: retryCount,
            maxRetries: maxRetries,
            lastFullSyncAt: lastFullSyncAt,
            lastIncrementalSyncAt: lastIncrementalSyncAt
        )
    }
    
    /// Create a copy with error information
    public func withError(_ error: SyncError) -> SyncStatus {
        SyncStatus(
            id: id,
            state: .failed,
            progress: progress,
            createdAt: createdAt,
            updatedAt: Date(),
            operation: operation,
            totalItems: totalItems,
            completedItems: completedItems,
            failedItems: failedItems,
            isConnected: isConnected,
            isRealtimeActive: isRealtimeActive,
            lastConnectedAt: lastConnectedAt,
            lastError: error,
            lastErrorAt: Date(),
            retryCount: retryCount,
            maxRetries: maxRetries,
            lastFullSyncAt: lastFullSyncAt,
            lastIncrementalSyncAt: lastIncrementalSyncAt
        )
    }
}

// MARK: - Equatable & Hashable

extension SyncStatus: Equatable {
    public static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        return lhs.id == rhs.id &&
               lhs.state == rhs.state &&
               lhs.progress == rhs.progress &&
               lhs.updatedAt == rhs.updatedAt
    }
}

extension SyncStatus: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(state)
        hasher.combine(progress)
        hasher.combine(updatedAt)
    }
}

// MARK: - Codable Support

extension SyncStatus: Codable {
    enum CodingKeys: String, CodingKey {
        case id, state, progress
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case operation
        case totalItems = "total_items"
        case completedItems = "completed_items"
        case failedItems = "failed_items"
        case isConnected = "is_connected"
        case isRealtimeActive = "is_realtime_active"
        case lastConnectedAt = "last_connected_at"
        case lastError = "last_error"
        case lastErrorAt = "last_error_at"
        case retryCount = "retry_count"
        case maxRetries = "max_retries"
        case lastFullSyncAt = "last_full_sync_at"
        case lastIncrementalSyncAt = "last_incremental_sync_at"
    }
}