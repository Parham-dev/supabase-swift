//
//  SyncRepository.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Implementation of SyncRepositoryProtocol that bridges sync use cases with data sources
/// Coordinates between LocalDataSource, SupabaseDataDataSource, and SupabaseRealtimeDataSource
public final class SyncRepository: SyncRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let localDataSource: LocalDataSource
    private let remoteDataSource: SupabaseDataDataSource
    private let realtimeDataSource: SupabaseRealtimeDataSource?
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Initialization
    
    /// Initialize sync repository
    /// - Parameters:
    ///   - localDataSource: Local data storage for SwiftData operations
    ///   - remoteDataSource: Remote data source for Supabase API operations
    ///   - realtimeDataSource: Optional real-time data source for live updates
    ///   - logger: Optional logger for debugging
    public init(
        localDataSource: LocalDataSource,
        remoteDataSource: SupabaseDataDataSource,
        realtimeDataSource: SupabaseRealtimeDataSource? = nil,
        logger: SyncLoggerProtocol? = nil
    ) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
        self.realtimeDataSource = realtimeDataSource
        self.logger = logger
    }
    
    // MARK: - Generic Data Operations
    
    /// Fetch records that need synchronization
    public func fetchRecordsNeedingSync<T: Syncable>(
        ofType entityType: T.Type,
        limit: Int?
    ) async throws -> [SyncSnapshot] {
        logger?.debug("SyncRepository: Fetching records needing sync for \(entityType)")
        
        do {
            let records = try localDataSource.fetchRecordsNeedingSync(entityType, limit: limit)
            return records.map { convertToSyncSnapshot($0) }
            
        } catch {
            logger?.error("SyncRepository: Failed to fetch records needing sync - \(error.localizedDescription)")
            throw SyncRepositoryError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch a specific record by sync ID
    public func fetchRecord<T: Syncable>(
        withSyncID syncID: UUID,
        ofType entityType: T.Type
    ) async throws -> SyncSnapshot? {
        logger?.debug("SyncRepository: Fetching record with syncID: \(syncID)")
        
        do {
            guard let record = try localDataSource.fetchBySyncID(entityType, syncID: syncID) else {
                return nil
            }
            return convertToSyncSnapshot(record)
            
        } catch {
            logger?.error("SyncRepository: Failed to fetch record by syncID - \(error.localizedDescription)")
            throw SyncRepositoryError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch records modified after a specific date
    public func fetchRecordsModifiedAfter<T: Syncable>(
        _ date: Date,
        ofType entityType: T.Type,
        limit: Int?
    ) async throws -> [SyncSnapshot] {
        logger?.debug("SyncRepository: Fetching records modified after \(date)")
        
        do {
            let records = try localDataSource.fetchRecordsModifiedAfter(entityType, date: date, limit: limit)
            return records.map { convertToSyncSnapshot($0) }
            
        } catch {
            logger?.error("SyncRepository: Failed to fetch records modified after date - \(error.localizedDescription)")
            throw SyncRepositoryError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Fetch deleted records (tombstones)
    public func fetchDeletedRecords<T: Syncable>(
        ofType entityType: T.Type,
        since: Date?
    ) async throws -> [SyncSnapshot] {
        logger?.debug("SyncRepository: Fetching deleted records")
        
        do {
            let records = try localDataSource.fetchDeletedRecords(entityType, since: since)
            return records.map { convertToSyncSnapshot($0) }
            
        } catch {
            logger?.error("SyncRepository: Failed to fetch deleted records - \(error.localizedDescription)")
            throw SyncRepositoryError.fetchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Sync Operations
    
    /// Upload local changes to remote
    public func uploadChanges(_ snapshots: [SyncSnapshot]) async throws -> [SyncUploadResult] {
        logger?.debug("SyncRepository: Uploading \(snapshots.count) changes to remote")
        
        var results: [SyncUploadResult] = []
        
        for snapshot in snapshots {
            do {
                // Upload to remote using table name from snapshot
                let batchResults = try await remoteDataSource.batchUpsert([snapshot], into: snapshot.tableName)
                
                let uploadResult = SyncUploadResult(
                    snapshot: snapshot,
                    success: batchResults.first?.success ?? false,
                    error: batchResults.first?.error.map { SyncError.unknownError($0.localizedDescription) },
                    remoteVersion: snapshot.version + 1
                )
                results.append(uploadResult)
                
            } catch {
                logger?.error("SyncRepository: Failed to upload snapshot \(snapshot.syncID) - \(error.localizedDescription)")
                let uploadResult = SyncUploadResult(
                    snapshot: snapshot,
                    success: false,
                    error: SyncError.unknownError(error.localizedDescription)
                )
                results.append(uploadResult)
            }
        }
        
        logger?.info("SyncRepository: Upload completed - \(results.filter { $0.success }.count)/\(results.count) successful")
        return results
    }
    
    /// Download remote changes
    public func downloadChanges<T: Syncable>(
        ofType entityType: T.Type,
        since: Date?,
        limit: Int?
    ) async throws -> [SyncSnapshot] {
        logger?.debug("SyncRepository: Downloading changes for \(entityType)")
        
        do {
            let tableName = getTableName(for: entityType)
            
            if let since = since {
                return try await remoteDataSource.fetchRecordsModifiedAfter(since, from: tableName, limit: limit)
            } else {
                // For now, return empty - would need a different method for full download
                logger?.warning("SyncRepository: Full download not implemented, returning empty")
                return []
            }
            
        } catch {
            logger?.error("SyncRepository: Failed to download changes - \(error.localizedDescription)")
            throw SyncRepositoryError.downloadFailed(error.localizedDescription)
        }
    }
    
    /// Apply remote changes to local storage
    public func applyRemoteChanges(_ snapshots: [SyncSnapshot]) async throws -> [SyncApplicationResult] {
        logger?.debug("SyncRepository: Applying \(snapshots.count) remote changes to local storage")
        
        return localDataSource.applyRemoteChanges(snapshots)
    }
    
    /// Mark records as successfully synced
    public func markRecordsAsSynced(_ syncIDs: [UUID], at timestamp: Date) async throws {
        logger?.debug("SyncRepository: Marking \(syncIDs.count) records as synced")
        
        // This is tricky - we need the entity type, but the protocol doesn't provide it
        // For now, we'll need to find a way to handle this generically
        // This is a limitation that would need to be addressed in a real implementation
        logger?.warning("SyncRepository: markRecordsAsSynced needs entity type - implementation incomplete")
    }
    
    // MARK: - Conflict Management
    
    /// Detect conflicts between local and remote data
    public func detectConflicts(
        local localSnapshots: [SyncSnapshot],
        remote remoteSnapshots: [SyncSnapshot]
    ) async throws -> [SyncConflict] {
        logger?.debug("SyncRepository: Detecting conflicts between \(localSnapshots.count) local and \(remoteSnapshots.count) remote snapshots")
        
        var conflicts: [SyncConflict] = []
        
        // Group remote snapshots by syncID for efficient lookup
        let remoteDict = Dictionary(uniqueKeysWithValues: remoteSnapshots.map { ($0.syncID, $0) })
        
        for localSnapshot in localSnapshots {
            if let remoteSnapshot = remoteDict[localSnapshot.syncID] {
                // Check for version conflicts
                if localSnapshot.version != remoteSnapshot.version &&
                   localSnapshot.lastModified != remoteSnapshot.lastModified {
                    
                    let conflict = SyncConflict(
                        entityType: localSnapshot.tableName,
                        recordID: localSnapshot.syncID,
                        localSnapshot: localSnapshot,
                        remoteSnapshot: remoteSnapshot
                    )
                    conflicts.append(conflict)
                }
            }
        }
        
        logger?.info("SyncRepository: Detected \(conflicts.count) conflicts")
        return conflicts
    }
    
    /// Resolve conflicts and apply resolutions
    public func applyConflictResolutions(_ resolutions: [ConflictResolution]) async throws -> [ConflictApplicationResult] {
        logger?.debug("SyncRepository: Applying \(resolutions.count) conflict resolutions")
        
        var results: [ConflictApplicationResult] = []
        
        for resolution in resolutions {
            let result = ConflictApplicationResult(
                resolution: resolution,
                success: false,
                error: SyncError.unknownError("Conflict resolution not yet implemented")
            )
            results.append(result)
        }
        
        logger?.warning("SyncRepository: Conflict resolution not fully implemented")
        return results
    }
    
    /// Get unresolved conflicts
    public func getUnresolvedConflicts<T: Syncable>(
        ofType entityType: T.Type,
        limit: Int?
    ) async throws -> [SyncConflict] {
        logger?.debug("SyncRepository: Getting unresolved conflicts for \(entityType)")
        
        // For now, return empty - would need conflict storage
        logger?.warning("SyncRepository: Unresolved conflicts tracking not implemented")
        return []
    }
    
    // MARK: - Metadata & Status (Stub implementations)
    
    public func getSyncStatus<T: Syncable>(for entityType: T.Type) async throws -> EntitySyncStatus {
        return EntitySyncStatus(
            entityType: String(describing: entityType),
            state: .idle,
            lastSyncAt: nil,
            pendingCount: 0
        )
    }
    
    public func updateSyncStatus<T: Syncable>(_ status: EntitySyncStatus, for entityType: T.Type) async throws {
        logger?.debug("SyncRepository: Update sync status - not implemented")
    }
    
    public func getLastSyncTimestamp<T: Syncable>(for entityType: T.Type) async throws -> Date? {
        return nil
    }
    
    public func setLastSyncTimestamp<T: Syncable>(_ timestamp: Date, for entityType: T.Type) async throws {
        logger?.debug("SyncRepository: Set last sync timestamp - not implemented")
    }
    
    // MARK: - Batch Operations (Stub implementations)
    
    public func performFullSync<T: Syncable>(
        ofType entityType: T.Type,
        using policy: SyncPolicy
    ) async throws -> FullSyncResult {
        throw SyncRepositoryError.notImplemented("Full sync not yet implemented")
    }
    
    public func performIncrementalSync<T: Syncable>(
        ofType entityType: T.Type,
        since: Date,
        using policy: SyncPolicy
    ) async throws -> IncrementalSyncResult {
        throw SyncRepositoryError.notImplemented("Incremental sync not yet implemented")
    }
    
    // MARK: - Schema & Migration (Stub implementations)
    
    public func checkSchemaCompatibility<T: Syncable>(for entityType: T.Type) async throws -> SchemaCompatibilityResult {
        throw SyncRepositoryError.notImplemented("Schema compatibility check not yet implemented")
    }
    
    public func updateRemoteSchema<T: Syncable>(for entityType: T.Type) async throws -> SchemaUpdateResult {
        throw SyncRepositoryError.notImplemented("Remote schema update not yet implemented")
    }
    
    // MARK: - Cleanup & Maintenance (Stub implementations)
    
    public func cleanupSyncMetadata(olderThan: Date) async throws {
        logger?.debug("SyncRepository: Cleanup sync metadata - not implemented")
    }
    
    public func compactSyncHistory<T: Syncable>(for entityType: T.Type, keepDays: Int) async throws {
        logger?.debug("SyncRepository: Compact sync history - not implemented")
    }
    
    public func validateSyncIntegrity<T: Syncable>(for entityType: T.Type) async throws -> SyncIntegrityResult {
        throw SyncRepositoryError.notImplemented("Sync integrity validation not yet implemented")
    }
    
    // MARK: - Private Helper Methods
    
    /// Convert a Syncable entity to SyncSnapshot
    private func convertToSyncSnapshot<T: Syncable>(_ entity: T) -> SyncSnapshot {
        return SyncSnapshot(
            syncID: entity.syncID,
            tableName: getTableName(for: T.self),
            version: entity.version,
            lastModified: entity.lastModified,
            lastSynced: entity.lastSynced,
            isDeleted: entity.isDeleted,
            contentHash: generateContentHash(for: entity),
            conflictData: [:]
        )
    }
    
    /// Get table name for entity type
    private func getTableName<T: Syncable>(for entityType: T.Type) -> String {
        // Simple pluralization - in real implementation would be more sophisticated
        let typeName = String(describing: entityType)
        return typeName.lowercased() + "s"
    }
    
    /// Generate content hash for entity
    private func generateContentHash<T: Syncable>(for entity: T) -> String {
        // Simple hash - in real implementation would hash actual content
        return "\(entity.syncID)_\(entity.version)_\(entity.lastModified.timeIntervalSince1970)"
    }
}

// MARK: - Sync Repository Error

/// Errors that can occur in SyncRepository operations
public enum SyncRepositoryError: Error, LocalizedError, Equatable {
    case fetchFailed(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case applyFailed(String)
    case updateFailed(String)
    case conflictDetectionFailed(String)
    case conflictResolutionFailed(String)
    case schemaError(String)
    case notImplemented(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .applyFailed(let message):
            return "Apply changes failed: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        case .conflictDetectionFailed(let message):
            return "Conflict detection failed: \(message)"
        case .conflictResolutionFailed(let message):
            return "Conflict resolution failed: \(message)"
        case .schemaError(let message):
            return "Schema error: \(message)"
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .unknown(let message):
            return "Unknown sync repository error: \(message)"
        }
    }
}

