//
//  SyncRepositoryResultTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Sync Operation Result Types

/// Result of uploading a sync snapshot to remote storage
public struct SyncUploadResult: Codable, Equatable {
    /// The snapshot that was uploaded
    public let snapshot: SyncSnapshot
    
    /// Whether the upload was successful
    public let success: Bool
    
    /// Error if upload failed
    public let error: SyncError?
    
    /// Remote version after upload
    public let remoteVersion: Int?
    
    /// Upload timestamp
    public let uploadedAt: Date
    
    public init(
        snapshot: SyncSnapshot,
        success: Bool,
        error: SyncError? = nil,
        remoteVersion: Int? = nil,
        uploadedAt: Date = Date()
    ) {
        self.snapshot = snapshot
        self.success = success
        self.error = error
        self.remoteVersion = remoteVersion
        self.uploadedAt = uploadedAt
    }
}

/// Result of applying a remote sync snapshot to local storage
public struct SyncApplicationResult: Codable, Equatable {
    /// The snapshot that was applied
    public let snapshot: SyncSnapshot
    
    /// Whether the application was successful
    public let success: Bool
    
    /// Error if application failed
    public let error: SyncError?
    
    /// Whether a conflict was detected
    public let conflictDetected: Bool
    
    /// Application timestamp
    public let appliedAt: Date
    
    public init(
        snapshot: SyncSnapshot,
        success: Bool,
        error: SyncError? = nil,
        conflictDetected: Bool = false,
        appliedAt: Date = Date()
    ) {
        self.snapshot = snapshot
        self.success = success
        self.error = error
        self.conflictDetected = conflictDetected
        self.appliedAt = appliedAt
    }
}

/// Result of applying a conflict resolution to storage
public struct ConflictApplicationResult: Codable, Equatable {
    /// The resolution that was applied
    public let resolution: ConflictResolution
    
    /// Whether the application was successful
    public let success: Bool
    
    /// Error if application failed
    public let error: SyncError?
    
    /// Application timestamp
    public let appliedAt: Date
    
    public init(
        resolution: ConflictResolution,
        success: Bool,
        error: SyncError? = nil,
        appliedAt: Date = Date()
    ) {
        self.resolution = resolution
        self.success = success
        self.error = error
        self.appliedAt = appliedAt
    }
}

// MARK: - Status and Metadata Types

/// Synchronization status for a specific entity type
public struct EntitySyncStatus: Codable, Equatable {
    /// Entity type name
    public let entityType: String
    
    /// Current sync state
    public let state: SyncState
    
    /// Last sync timestamp
    public let lastSyncAt: Date?
    
    /// Number of records pending sync
    public let pendingCount: Int
    
    /// Number of unresolved conflicts
    public let conflictCount: Int
    
    /// Last error encountered
    public let lastError: SyncError?
    
    /// Status timestamp
    public let statusAt: Date
    
    public init(
        entityType: String,
        state: SyncState = .idle,
        lastSyncAt: Date? = nil,
        pendingCount: Int = 0,
        conflictCount: Int = 0,
        lastError: SyncError? = nil,
        statusAt: Date = Date()
    ) {
        self.entityType = entityType
        self.state = state
        self.lastSyncAt = lastSyncAt
        self.pendingCount = pendingCount
        self.conflictCount = conflictCount
        self.lastError = lastError
        self.statusAt = statusAt
    }
}

// MARK: - Batch Operation Results

/// Result of a full synchronization operation
public struct FullSyncResult: Codable, Equatable {
    /// Entity type that was synced
    public let entityType: String
    
    /// Whether the sync was successful
    public let success: Bool
    
    /// Number of records uploaded
    public let uploadedCount: Int
    
    /// Number of records downloaded
    public let downloadedCount: Int
    
    /// Number of conflicts detected
    public let conflictCount: Int
    
    /// Sync duration
    public let duration: TimeInterval
    
    /// Sync start timestamp
    public let startedAt: Date
    
    /// Sync completion timestamp
    public let completedAt: Date
    
    /// Error if sync failed
    public let error: SyncError?
    
    public init(
        entityType: String,
        success: Bool,
        uploadedCount: Int = 0,
        downloadedCount: Int = 0,
        conflictCount: Int = 0,
        duration: TimeInterval = 0,
        startedAt: Date = Date(),
        completedAt: Date = Date(),
        error: SyncError? = nil
    ) {
        self.entityType = entityType
        self.success = success
        self.uploadedCount = uploadedCount
        self.downloadedCount = downloadedCount
        self.conflictCount = conflictCount
        self.duration = duration
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.error = error
    }
}

/// Result of an incremental synchronization operation
public struct IncrementalSyncResult: Codable, Equatable {
    /// Entity type that was synced
    public let entityType: String
    
    /// Whether the sync was successful
    public let success: Bool
    
    /// Timestamp sync was performed from
    public let syncedFrom: Date
    
    /// Number of changes uploaded
    public let uploadedChanges: Int
    
    /// Number of changes downloaded
    public let downloadedChanges: Int
    
    /// Number of conflicts detected
    public let conflictCount: Int
    
    /// Sync duration
    public let duration: TimeInterval
    
    /// Sync timestamp
    public let syncedAt: Date
    
    /// Error if sync failed
    public let error: SyncError?
    
    public init(
        entityType: String,
        success: Bool,
        syncedFrom: Date,
        uploadedChanges: Int = 0,
        downloadedChanges: Int = 0,
        conflictCount: Int = 0,
        duration: TimeInterval = 0,
        syncedAt: Date = Date(),
        error: SyncError? = nil
    ) {
        self.entityType = entityType
        self.success = success
        self.syncedFrom = syncedFrom
        self.uploadedChanges = uploadedChanges
        self.downloadedChanges = downloadedChanges
        self.conflictCount = conflictCount
        self.duration = duration
        self.syncedAt = syncedAt
        self.error = error
    }
}

// MARK: - Integrity Validation Result

/// Result of sync integrity validation
public struct SyncIntegrityResult: Codable, Equatable {
    /// Entity type that was validated
    public let entityType: String
    
    /// Whether integrity is valid
    public let isValid: Bool
    
    /// Issues found
    public let issues: [IntegrityIssue]
    
    /// Number of records checked
    public let recordsChecked: Int
    
    /// Validation timestamp
    public let validatedAt: Date
    
    public init(
        entityType: String,
        isValid: Bool,
        issues: [IntegrityIssue] = [],
        recordsChecked: Int = 0,
        validatedAt: Date = Date()
    ) {
        self.entityType = entityType
        self.isValid = isValid
        self.issues = issues
        self.recordsChecked = recordsChecked
        self.validatedAt = validatedAt
    }
}

// MARK: - Integrity Issue Type

/// Represents a sync integrity issue
public struct IntegrityIssue: Codable, Equatable {
    /// Type of integrity issue
    public let type: IntegrityIssueType
    
    /// Record ID affected
    public let recordID: UUID?
    
    /// Description of the issue
    public let description: String
    
    /// Severity level
    public let severity: IntegrityIssueSeverity
    
    /// Whether the issue can be auto-repaired
    public let canAutoRepair: Bool
    
    public init(
        type: IntegrityIssueType,
        recordID: UUID? = nil,
        description: String,
        severity: IntegrityIssueSeverity = .medium,
        canAutoRepair: Bool = false
    ) {
        self.type = type
        self.recordID = recordID
        self.description = description
        self.severity = severity
        self.canAutoRepair = canAutoRepair
    }
}

// MARK: - Integrity Enums

/// Types of integrity issues that can be detected
public enum IntegrityIssueType: String, CaseIterable, Codable {
    case missingRecord = "missing_record"
    case orphanedRecord = "orphaned_record"
    case versionMismatch = "version_mismatch"
    case checksumMismatch = "checksum_mismatch"
    case timestampInconsistency = "timestamp_inconsistency"
    case duplicateRecord = "duplicate_record"
}

/// Severity levels for integrity issues
public enum IntegrityIssueSeverity: String, CaseIterable, Codable, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public static func < (lhs: IntegrityIssueSeverity, rhs: IntegrityIssueSeverity) -> Bool {
        let order: [IntegrityIssueSeverity] = [.low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}