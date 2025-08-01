//
//  SyncRepositoryProtocol.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Protocol defining the interface for synchronization data access
/// Abstracts data operations for both local and remote sync operations
public protocol SyncRepositoryProtocol {
    
    // MARK: - Generic Data Operations
    
    /// Fetch records that need synchronization
    /// - Parameters:
    ///   - entityType: Type of entity to fetch
    ///   - limit: Maximum number of records to fetch
    /// - Returns: Array of sync snapshots for records needing sync
    func fetchRecordsNeedingSync<T: Syncable>(
        ofType entityType: T.Type,
        limit: Int?
    ) async throws -> [SyncSnapshot]
    
    /// Fetch a specific record by sync ID
    /// - Parameters:
    ///   - syncID: Unique sync identifier
    ///   - entityType: Type of entity to fetch
    /// - Returns: Sync snapshot if found, nil otherwise
    func fetchRecord<T: Syncable>(
        withSyncID syncID: UUID,
        ofType entityType: T.Type
    ) async throws -> SyncSnapshot?
    
    /// Fetch records modified after a specific date
    /// - Parameters:
    ///   - date: Date threshold for modification
    ///   - entityType: Type of entity to fetch
    ///   - limit: Maximum number of records to fetch
    /// - Returns: Array of sync snapshots
    func fetchRecordsModifiedAfter<T: Syncable>(
        _ date: Date,
        ofType entityType: T.Type,
        limit: Int?
    ) async throws -> [SyncSnapshot]
    
    /// Fetch deleted records (tombstones)
    /// - Parameters:
    ///   - entityType: Type of entity to fetch
    ///   - since: Optional date to filter from
    /// - Returns: Array of deleted record snapshots
    func fetchDeletedRecords<T: Syncable>(
        ofType entityType: T.Type,
        since: Date?
    ) async throws -> [SyncSnapshot]
    
    // MARK: - Sync Operations
    
    /// Upload local changes to remote
    /// - Parameters:
    ///   - snapshots: Local snapshots to upload
    /// - Returns: Upload results with success/failure information
    func uploadChanges(_ snapshots: [SyncSnapshot]) async throws -> [SyncUploadResult]
    
    /// Download remote changes
    /// - Parameters:
    ///   - entityType: Type of entity to download
    ///   - since: Optional timestamp to download changes since
    ///   - limit: Maximum number of changes to download
    /// - Returns: Array of remote snapshots
    func downloadChanges<T: Syncable>(
        ofType entityType: T.Type,
        since: Date?,
        limit: Int?
    ) async throws -> [SyncSnapshot]
    
    /// Apply remote changes to local storage
    /// - Parameters:
    ///   - snapshots: Remote snapshots to apply
    /// - Returns: Application results with success/failure information
    func applyRemoteChanges(_ snapshots: [SyncSnapshot]) async throws -> [SyncApplicationResult]
    
    /// Mark records as successfully synced
    /// - Parameters:
    ///   - syncIDs: IDs of records to mark as synced
    ///   - timestamp: Timestamp to set as last synced
    func markRecordsAsSynced(_ syncIDs: [UUID], at timestamp: Date) async throws
    
    // MARK: - Conflict Management
    
    /// Detect conflicts between local and remote data
    /// - Parameters:
    ///   - localSnapshots: Local record snapshots
    ///   - remoteSnapshots: Remote record snapshots
    /// - Returns: Array of detected conflicts
    func detectConflicts(
        local localSnapshots: [SyncSnapshot],
        remote remoteSnapshots: [SyncSnapshot]
    ) async throws -> [SyncConflict]
    
    /// Resolve conflicts and apply resolutions
    /// - Parameters:
    ///   - resolutions: Conflict resolutions to apply
    /// - Returns: Results of applying resolutions
    func applyConflictResolutions(_ resolutions: [ConflictResolution]) async throws -> [ConflictApplicationResult]
    
    /// Get unresolved conflicts
    /// - Parameters:
    ///   - entityType: Type of entity to check for conflicts
    ///   - limit: Maximum number of conflicts to return
    /// - Returns: Array of unresolved conflicts
    func getUnresolvedConflicts<T: Syncable>(
        ofType entityType: T.Type,
        limit: Int?
    ) async throws -> [SyncConflict]
    
    // MARK: - Metadata & Status
    
    /// Get sync status for entity type
    /// - Parameter entityType: Type of entity to get status for
    /// - Returns: Current sync status
    func getSyncStatus<T: Syncable>(for entityType: T.Type) async throws -> EntitySyncStatus
    
    /// Update sync status
    /// - Parameters:
    ///   - status: New sync status to set
    ///   - entityType: Type of entity to update status for
    func updateSyncStatus<T: Syncable>(_ status: EntitySyncStatus, for entityType: T.Type) async throws
    
    /// Get last sync timestamp for entity type
    /// - Parameter entityType: Type of entity to get timestamp for
    /// - Returns: Last sync timestamp, nil if never synced
    func getLastSyncTimestamp<T: Syncable>(for entityType: T.Type) async throws -> Date?
    
    /// Set last sync timestamp for entity type
    /// - Parameters:
    ///   - timestamp: Timestamp to set
    ///   - entityType: Type of entity to set timestamp for
    func setLastSyncTimestamp<T: Syncable>(_ timestamp: Date, for entityType: T.Type) async throws
    
    // MARK: - Batch Operations
    
    /// Perform a full sync cycle for entity type
    /// - Parameters:
    ///   - entityType: Type of entity to sync
    ///   - policy: Sync policy to apply
    /// - Returns: Full sync result
    func performFullSync<T: Syncable>(
        ofType entityType: T.Type,
        using policy: SyncPolicy
    ) async throws -> FullSyncResult
    
    /// Perform incremental sync for entity type
    /// - Parameters:
    ///   - entityType: Type of entity to sync
    ///   - since: Timestamp to sync changes since
    ///   - policy: Sync policy to apply
    /// - Returns: Incremental sync result
    func performIncrementalSync<T: Syncable>(
        ofType entityType: T.Type,
        since: Date,
        using policy: SyncPolicy
    ) async throws -> IncrementalSyncResult
    
    // MARK: - Schema & Migration
    
    /// Check if remote schema matches local schema
    /// - Parameter entityType: Type of entity to check schema for
    /// - Returns: Schema comparison result
    func checkSchemaCompatibility<T: Syncable>(for entityType: T.Type) async throws -> SchemaCompatibilityResult
    
    /// Update remote schema to match local schema
    /// - Parameter entityType: Type of entity to update schema for
    /// - Returns: Schema update result
    func updateRemoteSchema<T: Syncable>(for entityType: T.Type) async throws -> SchemaUpdateResult
    
    // MARK: - Cleanup & Maintenance
    
    /// Clean up old sync metadata
    /// - Parameter olderThan: Date threshold for cleanup
    func cleanupSyncMetadata(olderThan: Date) async throws
    
    /// Compact sync history
    /// - Parameters:
    ///   - entityType: Type of entity to compact history for
    ///   - keepDays: Number of days of history to keep
    func compactSyncHistory<T: Syncable>(for entityType: T.Type, keepDays: Int) async throws
    
    /// Validate sync integrity
    /// - Parameter entityType: Type of entity to validate
    /// - Returns: Integrity validation result
    func validateSyncIntegrity<T: Syncable>(for entityType: T.Type) async throws -> SyncIntegrityResult
}

// MARK: - Supporting Types

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

public struct SchemaCompatibilityResult: Codable, Equatable {
    /// Entity type being checked
    public let entityType: String
    
    /// Whether schemas are compatible
    public let isCompatible: Bool
    
    /// Local schema version
    public let localSchemaVersion: String
    
    /// Remote schema version
    public let remoteSchemaVersion: String
    
    /// Differences found
    public let differences: [SchemaDifference]
    
    /// Whether migration is required
    public let requiresMigration: Bool
    
    /// Check timestamp
    public let checkedAt: Date
    
    public init(
        entityType: String,
        isCompatible: Bool,
        localSchemaVersion: String,
        remoteSchemaVersion: String,
        differences: [SchemaDifference] = [],
        requiresMigration: Bool = false,
        checkedAt: Date = Date()
    ) {
        self.entityType = entityType
        self.isCompatible = isCompatible
        self.localSchemaVersion = localSchemaVersion
        self.remoteSchemaVersion = remoteSchemaVersion
        self.differences = differences
        self.requiresMigration = requiresMigration
        self.checkedAt = checkedAt
    }
}

public struct SchemaUpdateResult: Codable, Equatable {
    /// Entity type that was updated
    public let entityType: String
    
    /// Whether the update was successful
    public let success: Bool
    
    /// New schema version
    public let newSchemaVersion: String
    
    /// Changes applied
    public let appliedChanges: [SchemaChange]
    
    /// Update timestamp
    public let updatedAt: Date
    
    /// Error if update failed
    public let error: SyncError?
    
    public init(
        entityType: String,
        success: Bool,
        newSchemaVersion: String,
        appliedChanges: [SchemaChange] = [],
        updatedAt: Date = Date(),
        error: SyncError? = nil
    ) {
        self.entityType = entityType
        self.success = success
        self.newSchemaVersion = newSchemaVersion
        self.appliedChanges = appliedChanges
        self.updatedAt = updatedAt
        self.error = error
    }
}

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

// MARK: - Schema Types

public struct SchemaDifference: Codable, Equatable {
    /// Type of difference
    public let type: SchemaDifferenceType
    
    /// Field or property name
    public let fieldName: String
    
    /// Local value/type
    public let localValue: String
    
    /// Remote value/type
    public let remoteValue: String
    
    /// Description of the difference
    public let description: String
    
    public init(
        type: SchemaDifferenceType,
        fieldName: String,
        localValue: String,
        remoteValue: String,
        description: String
    ) {
        self.type = type
        self.fieldName = fieldName
        self.localValue = localValue
        self.remoteValue = remoteValue
        self.description = description
    }
}

public struct SchemaChange: Codable, Equatable {
    /// Type of change
    public let type: SchemaChangeType
    
    /// Field or property name
    public let fieldName: String
    
    /// Change description
    public let description: String
    
    /// SQL or migration script
    public let migrationScript: String?
    
    public init(
        type: SchemaChangeType,
        fieldName: String,
        description: String,
        migrationScript: String? = nil
    ) {
        self.type = type
        self.fieldName = fieldName
        self.description = description
        self.migrationScript = migrationScript
    }
}

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

// MARK: - Enums

public enum SchemaDifferenceType: String, CaseIterable, Codable {
    case fieldAdded = "field_added"
    case fieldRemoved = "field_removed"
    case fieldTypeChanged = "field_type_changed"
    case fieldNullabilityChanged = "field_nullability_changed"
    case indexAdded = "index_added"
    case indexRemoved = "index_removed"
}

public enum SchemaChangeType: String, CaseIterable, Codable {
    case addColumn = "add_column"
    case dropColumn = "drop_column"
    case alterColumn = "alter_column"
    case addIndex = "add_index"
    case dropIndex = "drop_index"
    case createTable = "create_table"
    case dropTable = "drop_table"
}

public enum IntegrityIssueType: String, CaseIterable, Codable {
    case missingRecord = "missing_record"
    case orphanedRecord = "orphaned_record"
    case versionMismatch = "version_mismatch"
    case checksumMismatch = "checksum_mismatch"
    case timestampInconsistency = "timestamp_inconsistency"
    case duplicateRecord = "duplicate_record"
}

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

