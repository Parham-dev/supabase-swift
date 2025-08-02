//
//  SyncOperationsManager.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Manages core sync operations and workflows
/// Handles the orchestration of sync processes
internal final class SyncOperationsManager {
    
    // MARK: - Dependencies
    
    private let localDataSource: LocalDataSource
    private let remoteDataSource: SupabaseDataDataSource
    private let metadataManager: SyncMetadataManager
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Initialization
    
    public init(
        localDataSource: LocalDataSource,
        remoteDataSource: SupabaseDataDataSource,
        metadataManager: SyncMetadataManager,
        logger: SyncLoggerProtocol? = nil
    ) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
        self.metadataManager = metadataManager
        self.logger = logger
    }
    
    // MARK: - Core Sync Operations
    
    /// Perform a complete full sync for an entity type
    /// - Parameters:
    ///   - entityType: Type of entity to sync
    ///   - policy: Sync policy to apply
    /// - Returns: Full sync result
    public func performFullSync<T: Syncable>(
        ofType entityType: T.Type,
        using policy: SyncPolicy
    ) async throws -> FullSyncResult {
        let entityTypeName = String(describing: entityType)
        let operationId = UUID()
        
        logger?.info("SyncOperationsManager: Starting full sync for \(entityTypeName)")
        
        // Start tracking the operation
        let _ = await metadataManager.startSyncOperation(
            operationId: operationId,
            entityType: entityTypeName,
            operationType: .fullSync
        )
        
        do {
            let startTime = Date()
            var uploadedCount = 0
            var downloadedCount = 0
            var conflictCount = 0
            
            // Step 1: Clear sync metadata for fresh start
            await metadataManager.clearSyncMetadata(for: entityTypeName)
            
            // Step 2: Upload all local changes (including tombstones)
            let allLocalChanges = try localDataSource.fetchRecordsNeedingSync(entityType, limit: nil)
            if !allLocalChanges.isEmpty {
                let snapshots = allLocalChanges.map { convertToSyncSnapshot($0) }
                let uploadResults = try await uploadChanges(snapshots)
                uploadedCount = uploadResults.filter { $0.success }.count
                
                // Mark successful uploads as synced
                let successfulSyncIDs = uploadResults.compactMap { result in
                    result.success ? result.snapshot.syncID : nil
                }
                await metadataManager.markRecordsAsSynced(successfulSyncIDs, at: Date(), for: entityTypeName)
            }
            
            // Step 3: Download entire remote dataset
            let tableName = getTableName(for: entityType)
            // For full sync, we get everything by using epoch date
            let epochDate = Date(timeIntervalSince1970: 0)
            let allRemoteChanges = try await remoteDataSource.fetchRecordsModifiedAfter(epochDate, from: tableName, limit: policy.batchSize)
            
            if !allRemoteChanges.isEmpty {
                // Apply remote changes with conflict detection
                let applicationResults = localDataSource.applyRemoteChanges(allRemoteChanges)
                downloadedCount = applicationResults.filter { $0.success }.count
                conflictCount = applicationResults.filter { $0.conflictDetected }.count
            }
            
            // Step 4: Update sync timestamp
            await metadataManager.setLastSyncTimestamp(Date(), for: entityTypeName)
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Complete the operation
            await metadataManager.completeSyncOperation(
                operationId,
                success: true,
                recordsProcessed: uploadedCount + downloadedCount
            )
            
            let result = FullSyncResult(
                entityType: entityTypeName,
                success: true,
                uploadedCount: uploadedCount,
                downloadedCount: downloadedCount,
                conflictCount: conflictCount,
                duration: duration,
                startedAt: startTime,
                completedAt: Date()
            )
            
            logger?.info("SyncOperationsManager: Full sync completed - uploaded: \(uploadedCount), downloaded: \(downloadedCount), conflicts: \(conflictCount)")
            return result
            
        } catch {
            // Mark operation as failed
            await metadataManager.completeSyncOperation(
                operationId,
                success: false,
                error: error as? SyncError ?? SyncError.unknownError(error.localizedDescription)
            )
            
            logger?.error("SyncOperationsManager: Full sync failed - \(error.localizedDescription)")
            
            return FullSyncResult(
                entityType: entityTypeName,
                success: false,
                error: SyncError.unknownError(error.localizedDescription)
            )
        }
    }
    
    /// Perform incremental sync for an entity type
    /// - Parameters:
    ///   - entityType: Type of entity to sync
    ///   - since: Date to sync changes since
    ///   - policy: Sync policy to apply
    /// - Returns: Incremental sync result
    public func performIncrementalSync<T: Syncable>(
        ofType entityType: T.Type,
        since: Date,
        using policy: SyncPolicy
    ) async throws -> IncrementalSyncResult {
        let entityTypeName = String(describing: entityType)
        let operationId = UUID()
        
        logger?.info("SyncOperationsManager: Starting incremental sync for \(entityTypeName)")
        
        // Start tracking the operation
        let _ = await metadataManager.startSyncOperation(
            operationId: operationId,
            entityType: entityTypeName,
            operationType: .incrementalSync
        )
        
        do {
            let startTime = Date()
            var uploadedChanges = 0
            var downloadedChanges = 0
            var conflictCount = 0
            
            // Step 1: Upload local changes
            let localChanges = try localDataSource.fetchRecordsModifiedAfter(entityType, date: since, limit: policy.batchSize)
            if !localChanges.isEmpty {
                let snapshots = localChanges.map { convertToSyncSnapshot($0) }
                let uploadResults = try await uploadChanges(snapshots)
                uploadedChanges = uploadResults.filter { $0.success }.count
                
                // Mark successful uploads as synced
                let successfulSyncIDs = uploadResults.compactMap { result in
                    result.success ? result.snapshot.syncID : nil
                }
                await metadataManager.markRecordsAsSynced(successfulSyncIDs, at: Date(), for: entityTypeName)
            }
            
            // Step 2: Download remote changes
            let tableName = getTableName(for: entityType)
            let remoteChanges = try await remoteDataSource.fetchRecordsModifiedAfter(since, from: tableName, limit: policy.batchSize)
            
            if !remoteChanges.isEmpty {
                // Apply remote changes
                let applicationResults = localDataSource.applyRemoteChanges(remoteChanges)
                downloadedChanges = applicationResults.filter { $0.success }.count
                conflictCount = applicationResults.filter { $0.conflictDetected }.count
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Complete the operation
            await metadataManager.completeSyncOperation(
                operationId,
                success: true,
                recordsProcessed: uploadedChanges + downloadedChanges
            )
            
            let result = IncrementalSyncResult(
                entityType: entityTypeName,
                success: true,
                syncedFrom: since,
                uploadedChanges: uploadedChanges,
                downloadedChanges: downloadedChanges,
                conflictCount: conflictCount,
                duration: duration
            )
            
            logger?.info("SyncOperationsManager: Incremental sync completed - uploaded: \(uploadedChanges), downloaded: \(downloadedChanges)")
            return result
            
        } catch {
            // Mark operation as failed
            await metadataManager.completeSyncOperation(
                operationId,
                success: false,
                error: error as? SyncError ?? SyncError.unknownError(error.localizedDescription)
            )
            
            logger?.error("SyncOperationsManager: Incremental sync failed - \(error.localizedDescription)")
            
            return IncrementalSyncResult(
                entityType: entityTypeName,
                success: false,
                syncedFrom: since,
                error: SyncError.unknownError(error.localizedDescription)
            )
        }
    }
    
    /// Upload changes to remote
    /// - Parameter snapshots: Snapshots to upload
    /// - Returns: Upload results
    public func uploadChanges(_ snapshots: [SyncSnapshot]) async throws -> [SyncUploadResult] {
        logger?.debug("SyncOperationsManager: Uploading \(snapshots.count) changes")
        
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
                logger?.error("SyncOperationsManager: Failed to upload snapshot \(snapshot.syncID) - \(error.localizedDescription)")
                let uploadResult = SyncUploadResult(
                    snapshot: snapshot,
                    success: false,
                    error: SyncError.unknownError(error.localizedDescription)
                )
                results.append(uploadResult)
            }
        }
        
        let successCount = results.filter { $0.success }.count
        logger?.info("SyncOperationsManager: Upload completed - \(successCount)/\(results.count) successful")
        return results
    }
    
    /// Download changes from remote
    /// - Parameters:
    ///   - entityType: Type of entity to download
    ///   - since: Optional timestamp to download changes since
    ///   - limit: Maximum number of changes to download
    /// - Returns: Array of remote snapshots
    public func downloadChanges<T: Syncable>(
        ofType entityType: T.Type,
        since: Date?,
        limit: Int?
    ) async throws -> [SyncSnapshot] {
        let tableName = getTableName(for: entityType)
        logger?.debug("SyncOperationsManager: Downloading changes for \(entityType)")
        
        if let since = since {
            // Incremental download
            return try await remoteDataSource.fetchRecordsModifiedAfter(since, from: tableName, limit: limit)
        } else {
            // Full download - implement basic full table fetch
            // For now, fetch recent records (last 30 days) as a reasonable default
            let defaultSince = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
            logger?.warning("SyncOperationsManager: Full download using default 30-day window")
            return try await remoteDataSource.fetchRecordsModifiedAfter(defaultSince, from: tableName, limit: limit)
        }
    }
    
    /// Mark records as successfully synced with proper entity type resolution
    /// - Parameters:
    ///   - syncIDs: Array of sync IDs that were synced
    ///   - timestamp: Sync timestamp
    ///   - entityType: Entity type (now provided explicitly)
    public func markRecordsAsSynced<T: Syncable>(
        _ syncIDs: [UUID],
        at timestamp: Date,
        ofType entityType: T.Type
    ) async throws {
        let entityTypeName = String(describing: entityType)
        logger?.debug("SyncOperationsManager: Marking \(syncIDs.count) records as synced for \(entityTypeName)")
        
        // Update sync metadata in local data source
        do {
            try localDataSource.markRecordsAsSynced(syncIDs, at: timestamp, type: entityType)
        } catch {
            logger?.warning("SyncOperationsManager: Failed to mark records as synced: \(error)")
        }
        
        // Update metadata manager
        await metadataManager.markRecordsAsSynced(syncIDs, at: timestamp, for: entityTypeName)
    }
    
    // MARK: - Helper Methods
    
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
        // Use the entity's own contentHash implementation
        return entity.contentHash
    }
}