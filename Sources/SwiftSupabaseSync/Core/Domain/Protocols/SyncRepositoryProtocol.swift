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


