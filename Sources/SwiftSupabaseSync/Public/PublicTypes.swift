//
//  PublicTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation

// MARK: - Core Public Types

/// Information about a sync operation for public API consumers
public struct SyncOperationInfo: Sendable {
    
    /// Unique identifier for this sync operation
    public let id: UUID
    
    /// Type of sync operation being performed
    public let type: PublicSyncOperationType
    
    /// Models being synced (table names)
    public let models: [String]
    
    /// When the operation started
    public let startTime: Date
    
    /// Estimated completion time (nil if unknown)
    public let estimatedCompletion: Date?
    
    /// Current status of the operation
    public let status: PublicSyncOperationStatus
    
    /// Additional context information
    public let context: [String: String]
    
    public init(
        id: UUID = UUID(),
        type: PublicSyncOperationType,
        models: [String],
        startTime: Date = Date(),
        estimatedCompletion: Date? = nil,
        status: PublicSyncOperationStatus = .running,
        context: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.models = models
        self.startTime = startTime
        self.estimatedCompletion = estimatedCompletion
        self.status = status
        self.context = context
    }
}

/// Types of sync operations
public enum PublicSyncOperationType: String, CaseIterable, Sendable {
    case fullSync = "full_sync"
    case incrementalSync = "incremental_sync"
    case upload = "upload"
    case download = "download"
    case conflictResolution = "conflict_resolution"
    case schemaSync = "schema_sync"
    case cleanup = "cleanup"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .fullSync: return "Full Synchronization"
        case .incrementalSync: return "Incremental Sync"
        case .upload: return "Upload Changes"
        case .download: return "Download Updates"
        case .conflictResolution: return "Resolve Conflicts"
        case .schemaSync: return "Schema Synchronization"
        case .cleanup: return "Cleanup Operation"
        }
    }
}

/// Status of a sync operation
public enum PublicSyncOperationStatus: String, CaseIterable, Sendable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case paused = "paused"
    
    /// Whether the operation is actively running
    public var isActive: Bool {
        switch self {
        case .running, .pending: return true
        case .completed, .failed, .cancelled, .paused: return false
        }
    }
    
    /// Whether the operation finished successfully
    public var isSuccessful: Bool {
        return self == .completed
    }
}

/// Information about a conflict that was detected
public struct ConflictInfo: Sendable {
    
    /// Unique identifier for the conflict
    public let id: UUID
    
    /// Model type where conflict occurred
    public let modelType: String
    
    /// Identifier of the conflicting record
    public let recordID: String
    
    /// Local version data (simplified to avoid Sendable issues)
    public let localVersion: String
    
    /// Remote version data (simplified to avoid Sendable issues)
    public let remoteVersion: String
    
    /// When the conflict was detected
    public let detectedAt: Date
    
    /// Conflict resolution strategy that will be used
    public let resolutionStrategy: PublicConflictResolution
    
    public init(
        id: UUID = UUID(),
        modelType: String,
        recordID: String,
        localVersion: String,
        remoteVersion: String,
        detectedAt: Date = Date(),
        resolutionStrategy: PublicConflictResolution
    ) {
        self.id = id
        self.modelType = modelType
        self.recordID = recordID
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.detectedAt = detectedAt
        self.resolutionStrategy = resolutionStrategy
    }
}

/// Possible conflict resolution strategies
public enum PublicConflictResolution: String, CaseIterable, Sendable {
    case useLocal = "use_local"
    case useRemote = "use_remote"
    case merge = "merge"
    case askUser = "ask_user"
    case retry = "retry"
    case skip = "skip"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .useLocal: return "Keep Local Version"
        case .useRemote: return "Use Remote Version"
        case .merge: return "Merge Both Versions"
        case .askUser: return "Ask User to Decide"
        case .retry: return "Retry Operation"
        case .skip: return "Skip This Record"
        }
    }
}

/// Public user information
public struct UserInfo: Sendable {
    
    /// Unique user identifier
    public let id: UUID
    
    /// User's email address
    public let email: String
    
    /// Display name (optional)
    public let displayName: String?
    
    /// Avatar URL (optional)
    public let avatarURL: URL?
    
    /// User metadata
    public let metadata: [String: String]
    
    /// When the user was created
    public let createdAt: Date
    
    /// Last sign-in time
    public let lastSignInAt: Date?
    
    /// Whether email is verified
    public let emailVerified: Bool
    
    /// User's subscription tier
    public let subscriptionTier: PublicSubscriptionTier
    
    public init(
        id: UUID,
        email: String,
        displayName: String? = nil,
        avatarURL: URL? = nil,
        metadata: [String: String] = [:],
        createdAt: Date,
        lastSignInAt: Date? = nil,
        emailVerified: Bool = false,
        subscriptionTier: PublicSubscriptionTier = .free
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.metadata = metadata
        self.createdAt = createdAt
        self.lastSignInAt = lastSignInAt
        self.emailVerified = emailVerified
        self.subscriptionTier = subscriptionTier
    }
}

/// Available subscription tiers
public enum PublicSubscriptionTier: String, CaseIterable, Sendable {
    case free = "free"
    case basic = "basic"
    case pro = "pro"
    case enterprise = "enterprise"
    
    /// Maximum number of synced devices for this tier
    public var maxDevices: Int {
        switch self {
        case .free: return 2
        case .basic: return 5
        case .pro: return 10
        case .enterprise: return 50
        }
    }
    
    /// Maximum sync frequency for this tier (in seconds)
    public var minSyncInterval: TimeInterval {
        switch self {
        case .free: return 300 // 5 minutes
        case .basic: return 60  // 1 minute
        case .pro: return 30    // 30 seconds
        case .enterprise: return 10 // 10 seconds
        }
    }
    
    /// Features available in this tier
    public var features: [SyncFeature] {
        switch self {
        case .free:
            return [.basicSync]
        case .basic:
            return [.basicSync, .realtimeSync]
        case .pro:
            return [.basicSync, .realtimeSync, .offlineSync, .conflictResolution]
        case .enterprise:
            return SyncFeature.allCases
        }
    }
}

/// Available sync features
public enum SyncFeature: String, CaseIterable, Sendable {
    case basicSync = "basic_sync"
    case realtimeSync = "realtime_sync"
    case offlineSync = "offline_sync"
    case conflictResolution = "conflict_resolution"
    case customSchemas = "custom_schemas"
    case advancedAuth = "advanced_auth"
    case analytics = "analytics"
    case customEndpoints = "custom_endpoints"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .basicSync: return "Basic Synchronization"
        case .realtimeSync: return "Real-time Updates"
        case .offlineSync: return "Offline Support"
        case .conflictResolution: return "Conflict Resolution"
        case .customSchemas: return "Custom Data Schemas"
        case .advancedAuth: return "Advanced Authentication"
        case .analytics: return "Sync Analytics"
        case .customEndpoints: return "Custom API Endpoints"
        }
    }
}

/// Network quality assessment
public enum PublicNetworkQuality: String, CaseIterable, Sendable {
    case excellent = "excellent"
    case good = "good" 
    case poor = "poor"
    case offline = "offline"
    
    /// Whether sync operations should be performed
    public var isSyncSuitable: Bool {
        switch self {
        case .excellent, .good: return true
        case .poor, .offline: return false
        }
    }
    
    /// Recommended batch size for this network quality
    public var recommendedBatchSize: Int {
        switch self {
        case .excellent: return 100
        case .good: return 50
        case .poor: return 10
        case .offline: return 0
        }
    }
}

/// Sync frequency options
public enum PublicSyncFrequency: Sendable {
    case manual
    case automatic
    case interval(TimeInterval)
    
    /// Default sync frequencies for different scenarios
    public static let immediate = PublicSyncFrequency.automatic
    public static let conservative = PublicSyncFrequency.interval(300) // 5 minutes
    public static let aggressive = PublicSyncFrequency.interval(30)   // 30 seconds
}

/// Sync policy configuration options
public enum SyncPolicyConfiguration: Sendable {
    case aggressive
    case balanced
    case conservative
    case custom(SyncPolicySettings)
    
    /// Get the settings for this policy
    public var settings: SyncPolicySettings {
        switch self {
        case .aggressive:
            return SyncPolicySettings(
                conflictResolution: .useLocal,
                retryAttempts: 5,
                batchSize: 100,
                syncFrequency: .automatic,
                requiresWifi: false,
                requiresCharging: false
            )
        case .balanced:
            return SyncPolicySettings(
                conflictResolution: .merge,
                retryAttempts: 3,
                batchSize: 50,
                syncFrequency: .interval(60),
                requiresWifi: false,
                requiresCharging: false
            )
        case .conservative:
            return SyncPolicySettings(
                conflictResolution: .askUser,
                retryAttempts: 2,
                batchSize: 25,
                syncFrequency: .interval(300),
                requiresWifi: true,
                requiresCharging: true
            )
        case .custom(let settings):
            return settings
        }
    }
}

/// Detailed sync policy settings
public struct SyncPolicySettings: Sendable {
    
    /// Default conflict resolution strategy
    public let conflictResolution: PublicConflictResolution
    
    /// Number of retry attempts for failed operations
    public let retryAttempts: Int
    
    /// Number of records to sync in each batch
    public let batchSize: Int
    
    /// How frequently to perform automatic sync
    public let syncFrequency: PublicSyncFrequency
    
    /// Whether to only sync on WiFi connections
    public let requiresWifi: Bool
    
    /// Whether to only sync when device is charging
    public let requiresCharging: Bool
    
    public init(
        conflictResolution: PublicConflictResolution = .merge,
        retryAttempts: Int = 3,
        batchSize: Int = 50,
        syncFrequency: PublicSyncFrequency = .interval(60),
        requiresWifi: Bool = false,
        requiresCharging: Bool = false
    ) {
        self.conflictResolution = conflictResolution
        self.retryAttempts = retryAttempts
        self.batchSize = batchSize
        self.syncFrequency = syncFrequency
        self.requiresWifi = requiresWifi
        self.requiresCharging = requiresCharging
    }
}

/// Log levels for the public logging interface
public enum PublicLogLevel: String, CaseIterable, Sendable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    /// Numeric priority (higher = more severe)
    public var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
    
    /// Whether this level should be logged in production
    public var shouldLogInProduction: Bool {
        return priority >= PublicLogLevel.warning.priority
    }
}

/// Available sync operations that can be performed
public enum PublicSyncOperation: String, CaseIterable, Sendable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case read = "read"
    case bulkInsert = "bulk_insert"
    case bulkUpdate = "bulk_update"
    case bulkDelete = "bulk_delete"
    case schema = "schema"
    
    /// Whether this operation modifies data
    public var isWriteOperation: Bool {
        switch self {
        case .create, .update, .delete, .bulkInsert, .bulkUpdate, .bulkDelete, .schema:
            return true
        case .read:
            return false
        }
    }
    
    /// Subscription tier required for this operation
    public var requiredTier: PublicSubscriptionTier {
        switch self {
        case .create, .update, .delete, .read:
            return .free
        case .bulkInsert, .bulkUpdate, .bulkDelete:
            return .basic
        case .schema:
            return .pro
        }
    }
}

// MARK: - Utility Types

/// Result type for async operations that might fail
public typealias SyncResult<T> = Result<T, SwiftSupabaseSyncError>

/// Completion handler for async operations
public typealias SyncCompletion<T> = (SyncResult<T>) -> Void

/// Progress callback for long-running operations
public typealias ProgressCallback = (Double) -> Void

/// Validation result for data integrity checks
public struct PublicValidationResult: Sendable {
    
    /// Whether validation passed
    public let isValid: Bool
    
    /// Error messages if validation failed
    public let errors: [String]
    
    /// Warnings that don't prevent operation
    public let warnings: [String]
    
    public init(isValid: Bool, errors: [String] = [], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
    
    /// Successful validation result
    public static let success = PublicValidationResult(isValid: true)
    
    /// Create a failed validation result
    public static func failure(errors: [String]) -> PublicValidationResult {
        return PublicValidationResult(isValid: false, errors: errors)
    }
    
    /// Create a result with warnings
    public static func warning(messages: [String]) -> PublicValidationResult {
        return PublicValidationResult(isValid: true, warnings: messages)
    }
}
