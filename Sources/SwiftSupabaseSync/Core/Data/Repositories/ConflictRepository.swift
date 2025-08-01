//
//  ConflictRepository.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Implementation of conflict detection, storage, and resolution repository
/// Manages sync conflicts between local and remote data sources
public final class ConflictRepository {
    
    // MARK: - Dependencies
    
    private let localDataSource: LocalDataSource
    private let remoteDataSource: SupabaseDataDataSource
    private let conflictResolver: ConflictResolvable
    private let logger: SyncLoggerProtocol?
    
    // MARK: - State Management
    
    /// In-memory conflict storage (in production, this would be persisted)
    private let conflictStore = ConflictStore()
    
    // MARK: - Initialization
    
    /// Initialize conflict repository
    /// - Parameters:
    ///   - localDataSource: Local data storage for conflict records
    ///   - remoteDataSource: Remote data source for conflict detection
    ///   - conflictResolver: Strategy for resolving conflicts
    ///   - logger: Optional logger for debugging
    public init(
        localDataSource: LocalDataSource,
        remoteDataSource: SupabaseDataDataSource,
        conflictResolver: ConflictResolvable? = nil,
        logger: SyncLoggerProtocol? = nil
    ) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
        self.conflictResolver = conflictResolver ?? StrategyBasedConflictResolver(strategy: .lastWriteWins)
        self.logger = logger
    }
    
    // MARK: - Conflict Detection
    
    /// Detect conflicts between local and remote snapshots
    /// - Parameters:
    ///   - entityType: Type of entity to check for conflicts
    ///   - localSnapshots: Local data snapshots
    ///   - remoteSnapshots: Remote data snapshots
    /// - Returns: Array of detected conflicts
    public func detectConflicts<T: Syncable>(
        for entityType: T.Type,
        between localSnapshots: [SyncSnapshot],
        and remoteSnapshots: [SyncSnapshot]
    ) async throws -> [SyncConflict] {
        logger?.debug("ConflictRepository: Detecting conflicts for \(entityType)")
        
        var conflicts: [SyncConflict] = []
        
        // Create lookup dictionary for efficient comparison
        let remoteDict = Dictionary(uniqueKeysWithValues: remoteSnapshots.map { ($0.syncID, $0) })
        
        for localSnapshot in localSnapshots {
            guard let remoteSnapshot = remoteDict[localSnapshot.syncID] else {
                // No remote counterpart - not a conflict
                continue
            }
            
            // Check for conflicts
            if let conflict = await detectConflict(
                between: localSnapshot,
                and: remoteSnapshot,
                entityType: String(describing: entityType)
            ) {
                conflicts.append(conflict)
                
                // Store the conflict for later resolution
                await conflictStore.store(conflict)
            }
        }
        
        logger?.info("ConflictRepository: Detected \(conflicts.count) conflicts")
        return conflicts
    }
    
    // MARK: - Conflict Storage & Retrieval
    
    /// Store a conflict for later resolution
    /// - Parameter conflict: The conflict to store
    public func storeConflict(_ conflict: SyncConflict) async throws {
        logger?.debug("ConflictRepository: Storing conflict for record \(conflict.recordID)")
        await conflictStore.store(conflict)
    }
    
    /// Get unresolved conflicts for a specific entity type
    /// - Parameters:
    ///   - entityType: Type of entity to get conflicts for
    ///   - limit: Maximum number of conflicts to return
    /// - Returns: Array of unresolved conflicts
    public func getUnresolvedConflicts<T: Syncable>(
        ofType entityType: T.Type,
        limit: Int? = nil
    ) async throws -> [SyncConflict] {
        logger?.debug("ConflictRepository: Getting unresolved conflicts for \(entityType)")
        
        let entityTypeName = String(describing: entityType)
        let conflicts = await conflictStore.getUnresolved(for: entityTypeName, limit: limit)
        
        logger?.info("ConflictRepository: Found \(conflicts.count) unresolved conflicts")
        return conflicts
    }
    
    /// Get a specific conflict by ID
    /// - Parameter conflictId: ID of the conflict to retrieve
    /// - Returns: The conflict if found, nil otherwise
    public func getConflictById(_ conflictId: UUID) async throws -> SyncConflict? {
        return await conflictStore.getById(conflictId)
    }
    
    // MARK: - Resolution Application
    
    /// Apply a single conflict resolution
    /// - Parameters:
    ///   - conflictId: ID of the conflict to resolve
    ///   - resolution: The resolution to apply
    /// - Returns: Result of applying the resolution
    public func applyConflictResolution(for conflictId: UUID, using resolution: ConflictResolution) async throws -> ConflictApplicationResult {
        logger?.debug("ConflictRepository: Applying resolution for conflict \(conflictId)")
        
        // Get the conflict
        guard let conflict = await conflictStore.getById(conflictId) else {
            logger?.error("ConflictRepository: Conflict \(conflictId) not found")
            return ConflictApplicationResult(
                resolution: resolution,
                success: false,
                error: SyncError.unknownError("Conflict not found")
            )
        }
        
        do {
            // Apply the resolution based on strategy
            let success = try await applyResolutionStrategy(resolution, for: conflict)
            
            if success {
                // Mark conflict as resolved
                await conflictStore.markResolved(conflictId, with: resolution)
                
                logger?.info("ConflictRepository: Successfully applied resolution for \(conflictId)")
                return ConflictApplicationResult(
                    resolution: resolution,
                    success: true
                )
            } else {
                return ConflictApplicationResult(
                    resolution: resolution,
                    success: false,
                    error: SyncError.unknownError("Resolution application failed")
                )
            }
            
        } catch {
            logger?.error("ConflictRepository: Failed to apply resolution - \(error.localizedDescription)")
            return ConflictApplicationResult(
                resolution: resolution,
                success: false,
                error: SyncError.unknownError(error.localizedDescription)
            )
        }
    }
    
    /// Apply multiple conflict resolutions
    /// - Parameter conflictResolutions: Dictionary mapping conflict IDs to their resolutions
    /// - Returns: Results of applying the resolutions
    public func applyConflictResolutions(_ conflictResolutions: [UUID: ConflictResolution]) async throws -> [ConflictApplicationResult] {
        logger?.debug("ConflictRepository: Applying \(conflictResolutions.count) resolutions")
        
        var results: [ConflictApplicationResult] = []
        
        for (conflictId, resolution) in conflictResolutions {
            let result = try await applyConflictResolution(for: conflictId, using: resolution)
            results.append(result)
        }
        
        let successCount = results.filter { $0.success }.count
        logger?.info("ConflictRepository: Applied \(successCount)/\(conflictResolutions.count) resolutions successfully")
        
        return results
    }
    
    // MARK: - Conflict History & Management
    
    /// Mark a conflict as resolved
    /// - Parameters:
    ///   - conflictId: ID of the conflict to mark as resolved
    ///   - resolution: The resolution that was applied
    public func markConflictAsResolved(_ conflictId: UUID, with resolution: ConflictResolution) async throws {
        logger?.debug("ConflictRepository: Marking conflict \(conflictId) as resolved")
        await conflictStore.markResolved(conflictId, with: resolution)
    }
    
    /// Get conflict resolution history
    /// - Parameters:
    ///   - entityType: Optional entity type to filter by
    ///   - limit: Maximum number of records to return
    /// - Returns: Array of resolution history records
    public func getConflictResolutionHistory(
        entityType: String? = nil,
        limit: Int? = nil
    ) async throws -> [ConflictResolutionRecord] {
        logger?.debug("ConflictRepository: Getting resolution history")
        return await conflictStore.getResolutionHistory(entityType: entityType, limit: limit)
    }
    
    /// Clean up resolved conflicts older than a specific date
    /// - Parameter date: Date threshold for cleanup
    public func cleanupResolvedConflicts(olderThan date: Date) async throws {
        logger?.debug("ConflictRepository: Cleaning up resolved conflicts older than \(date)")
        let cleaned = await conflictStore.cleanupResolved(olderThan: date)
        logger?.info("ConflictRepository: Cleaned up \(cleaned) resolved conflicts")
    }
    
    // MARK: - Automatic Resolution
    
    /// Attempt to automatically resolve conflicts
    /// - Parameter conflicts: Conflicts to attempt auto-resolution for
    /// - Returns: Results of auto-resolution attempts
    public func autoResolveConflicts(_ conflicts: [SyncConflict]) async throws -> AutoResolutionResult {
        logger?.debug("ConflictRepository: Attempting auto-resolution for \(conflicts.count) conflicts")
        
        // Filter conflicts that can be auto-resolved
        let (autoResolvable, manualRequired) = conflictResolver.filterAutoResolvableConflicts(conflicts)
        
        // Resolve each conflict
        var resolved: [ConflictResolution] = []
        var failed: [(SyncConflict, ConflictResolutionError)] = []
        
        for conflict in autoResolvable {
            do {
                let resolution = try await conflictResolver.resolveConflict(conflict)
                resolved.append(resolution)
                
                // Apply the resolution
                let result = try await applyConflictResolution(for: conflict.recordID, using: resolution)
                if !result.success {
                    failed.append((conflict, .resolutionValidationFailed))
                }
                
            } catch let error as ConflictResolutionError {
                failed.append((conflict, error))
            } catch {
                failed.append((conflict, .unknownError(error.localizedDescription)))
            }
        }
        
        // manualRequired already set from filterAutoResolvableConflicts
        
        logger?.info("ConflictRepository: Auto-resolved \(resolved.count)/\(conflicts.count) conflicts")
        
        return AutoResolutionResult(
            entityType: "mixed", // Mixed entity types
            totalConflicts: conflicts.count,
            autoResolvedCount: resolved.count,
            manualRequiredCount: manualRequired.count,
            success: failed.isEmpty,
            errors: failed.map { $0.1 }
        )
    }
    
    // MARK: - Private Methods
    
    /// Detect conflict between two snapshots
    private func detectConflict(
        between local: SyncSnapshot,
        and remote: SyncSnapshot,
        entityType: String
    ) async -> SyncConflict? {
        // Check for version conflict
        if local.version != remote.version && local.lastModified != remote.lastModified {
            // Determine conflict type
            let conflictType: ConflictType
            if local.isDeleted && !remote.isDeleted {
                conflictType = .deleteConflict
            } else if !local.isDeleted && remote.isDeleted {
                conflictType = .deleteConflict
            } else if local.contentHash != remote.contentHash {
                conflictType = .dataConflict
            } else {
                conflictType = .versionConflict
            }
            
            // Detect conflicted fields (simplified - in real implementation would diff the data)
            let conflictedFields = detectConflictedFields(local: local, remote: remote)
            
            return SyncConflict(
                entityType: entityType,
                recordID: local.syncID,
                localSnapshot: local,
                remoteSnapshot: remote,
                conflictType: conflictType,
                conflictedFields: conflictedFields,
                priority: determinePriority(conflictType)
            )
        }
        
        return nil
    }
    
    /// Detect which fields are conflicted
    private func detectConflictedFields(local: SyncSnapshot, remote: SyncSnapshot) -> Set<String> {
        // In a real implementation, this would compare the actual data fields
        // For now, return a basic set based on what's different
        var fields = Set<String>()
        
        if local.contentHash != remote.contentHash {
            fields.insert("content")
        }
        if local.isDeleted != remote.isDeleted {
            fields.insert("isDeleted")
        }
        if local.version != remote.version {
            fields.insert("version")
        }
        
        return fields
    }
    
    /// Determine priority based on conflict type
    private func determinePriority(_ type: ConflictType) -> ConflictPriority {
        switch type {
        case .deleteConflict:
            return .high
        case .permissionConflict:
            return .critical
        case .schemaConflict:
            return .high
        case .dataConflict:
            return .normal
        case .versionConflict:
            return .low
        }
    }
    
    /// Apply resolution strategy for a conflict
    private func applyResolutionStrategy(_ resolution: ConflictResolution, for conflict: SyncConflict) async throws -> Bool {
        switch resolution.strategy {
        case .localWins:
            // Keep local version - no remote update needed
            logger?.debug("ConflictRepository: Applying localWins strategy")
            return true
            
        case .remoteWins:
            // Apply remote version to local
            logger?.debug("ConflictRepository: Applying remoteWins strategy")
            let results = localDataSource.applyRemoteChanges([conflict.remoteSnapshot])
            return results.first?.success ?? false
            
        case .lastWriteWins:
            // Compare timestamps and apply the newer one
            logger?.debug("ConflictRepository: Applying lastWriteWins strategy")
            if conflict.localSnapshot.lastModified > conflict.remoteSnapshot.lastModified {
                return true // Local is newer
            } else {
                let results = localDataSource.applyRemoteChanges([conflict.remoteSnapshot])
                return results.first?.success ?? false
            }
            
        case .firstWriteWins:
            // Compare timestamps and apply the older one
            logger?.debug("ConflictRepository: Applying firstWriteWins strategy")
            if conflict.localSnapshot.lastModified < conflict.remoteSnapshot.lastModified {
                return true // Local is older
            } else {
                let results = localDataSource.applyRemoteChanges([conflict.remoteSnapshot])
                return results.first?.success ?? false
            }
            
        case .manual:
            // Manual resolution should have resolvedData
            logger?.debug("ConflictRepository: Applying manual resolution")
            if resolution.resolvedData != nil {
                // In real implementation, would apply the resolved data
                // For now, assume success if data is provided
                return true
            }
            return false
        }
    }
}

// MARK: - Conflict Store

/// Thread-safe in-memory conflict storage
private actor ConflictStore {
    private var conflicts: [UUID: SyncConflict] = [:]
    private var resolutions: [UUID: ConflictResolution] = [:]
    private var history: [ConflictResolutionRecord] = []
    
    func store(_ conflict: SyncConflict) {
        conflicts[conflict.recordID] = conflict
    }
    
    func getById(_ id: UUID) -> SyncConflict? {
        return conflicts[id]
    }
    
    func getUnresolved(for entityType: String? = nil, limit: Int? = nil) -> [SyncConflict] {
        var unresolved = conflicts.values.filter { conflict in
            !resolutions.keys.contains(conflict.recordID)
        }
        
        if let entityType = entityType {
            unresolved = unresolved.filter { $0.entityType == entityType }
        }
        
        if let limit = limit {
            return Array(unresolved.prefix(limit))
        }
        
        return Array(unresolved)
    }
    
    func markResolved(_ conflictId: UUID, with resolution: ConflictResolution) {
        resolutions[conflictId] = resolution
        
        // Add to history
        if let conflict = conflicts[conflictId] {
            let record = ConflictResolutionRecord(
                conflictId: conflictId,
                entityType: conflict.entityType,
                strategy: resolution.strategy,
                success: true,
                resolvedAt: Date(),
                resolvedBy: UUID() // System user ID - in real implementation, would track actual user
            )
            history.append(record)
        }
    }
    
    func getResolutionHistory(entityType: String? = nil, limit: Int? = nil) -> [ConflictResolutionRecord] {
        var records = history
        
        if let entityType = entityType {
            records = records.filter { $0.entityType == entityType }
        }
        
        // Sort by most recent first
        records.sort { $0.resolvedAt > $1.resolvedAt }
        
        if let limit = limit {
            return Array(records.prefix(limit))
        }
        
        return records
    }
    
    func cleanupResolved(olderThan date: Date) -> Int {
        let beforeCount = conflicts.count
        
        // Remove resolved conflicts older than date
        conflicts = conflicts.filter { id, conflict in
            if let resolution = resolutions[id] {
                return resolution.resolvedAt > date
            }
            return true // Keep unresolved conflicts
        }
        
        // Clean up orphaned resolutions
        resolutions = resolutions.filter { id, _ in
            conflicts.keys.contains(id)
        }
        
        // Clean up old history
        history = history.filter { $0.resolvedAt > date }
        
        return beforeCount - conflicts.count
    }
}