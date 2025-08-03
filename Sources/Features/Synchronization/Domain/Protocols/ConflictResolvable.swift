//
//  ConflictResolvable.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Protocol for implementing custom conflict resolution strategies
/// Allows applications to define how sync conflicts should be resolved
public protocol ConflictResolvable {
    
    // MARK: - Core Conflict Resolution
    
    /// Resolve a conflict between local and remote versions of a record
    /// - Parameters:
    ///   - conflict: The conflict data containing both versions
    /// - Returns: Resolution result indicating how to resolve the conflict
    func resolveConflict(_ conflict: SyncConflict) async throws -> ConflictResolution
    
    /// Check if two records are in conflict
    /// - Parameters:
    ///   - local: The local version of the record
    ///   - remote: The remote version of the record
    /// - Returns: True if the records are in conflict
    func hasConflict(local: SyncSnapshot, remote: SyncSnapshot) -> Bool
    
    /// Prepare conflict data for resolution
    /// - Parameters:
    ///   - local: Local record snapshot
    ///   - remote: Remote record snapshot
    /// - Returns: Conflict data ready for resolution
    func prepareConflict(local: SyncSnapshot, remote: SyncSnapshot) -> SyncConflict
    
    // MARK: - Batch Conflict Resolution
    
    /// Resolve multiple conflicts at once
    /// - Parameter conflicts: Array of conflicts to resolve
    /// - Returns: Array of resolutions in the same order
    func resolveConflicts(_ conflicts: [SyncConflict]) async throws -> [ConflictResolution]
    
    /// Filter conflicts that can be auto-resolved
    /// - Parameter conflicts: Array of conflicts to filter
    /// - Returns: Tuple of (auto-resolvable, manual) conflicts
    func filterAutoResolvableConflicts(_ conflicts: [SyncConflict]) -> (autoResolvable: [SyncConflict], manual: [SyncConflict])
    
    // MARK: - Validation & Metadata
    
    /// Validate if a resolution is acceptable
    /// - Parameters:
    ///   - resolution: The proposed resolution
    ///   - conflict: The original conflict
    /// - Returns: True if the resolution is valid
    func validateResolution(_ resolution: ConflictResolution, for conflict: SyncConflict) -> Bool
    
    /// Get metadata about the conflict resolver's capabilities
    /// - Returns: Resolver capabilities and configuration
    func getResolverCapabilities() -> ConflictResolverCapabilities
}


// MARK: - Default Implementation

public extension ConflictResolvable {
    
    /// Default batch conflict resolution
    func resolveConflicts(_ conflicts: [SyncConflict]) async throws -> [ConflictResolution] {
        var resolutions: [ConflictResolution] = []
        
        for conflict in conflicts {
            let resolution = try await resolveConflict(conflict)
            resolutions.append(resolution)
        }
        
        return resolutions
    }
    
    /// Default conflict detection based on version and timestamps
    func hasConflict(local: SyncSnapshot, remote: SyncSnapshot) -> Bool {
        // No conflict if IDs don't match (shouldn't happen)
        guard local.syncID == remote.syncID else { return false }
        
        // No conflict if versions are the same
        if local.version == remote.version {
            return false
        }
        
        // Conflict if both were modified after last sync
        if let localSync = local.lastSynced,
           let remoteSync = remote.lastSynced {
            return local.lastModified > localSync && remote.lastModified > remoteSync
        }
        
        // Default to conflict if we can't determine
        return true
    }
    
    /// Default conflict preparation
    func prepareConflict(local: SyncSnapshot, remote: SyncSnapshot) -> SyncConflict {
        let conflictType: ConflictType
        
        if local.isDeleted || remote.isDeleted {
            conflictType = .deleteConflict
        } else if local.version != remote.version {
            conflictType = .versionConflict
        } else {
            conflictType = .dataConflict
        }
        
        return SyncConflict(
            entityType: local.tableName,
            recordID: local.syncID,
            localSnapshot: local,
            remoteSnapshot: remote,
            conflictType: conflictType
        )
    }
    
    /// Default auto-resolvable conflict filtering
    func filterAutoResolvableConflicts(_ conflicts: [SyncConflict]) -> (autoResolvable: [SyncConflict], manual: [SyncConflict]) {
        let capabilities = getResolverCapabilities()
        
        guard capabilities.supportsAutoResolution else {
            return (autoResolvable: [], manual: conflicts)
        }
        
        let autoResolvable = conflicts.filter { conflict in
            // Only auto-resolve simple conflicts
            return conflict.conflictType != .schemaConflict &&
                   conflict.conflictType != .permissionConflict &&
                   conflict.priority != .critical
        }
        
        let manual = conflicts.filter { conflict in
            return !autoResolvable.contains { $0.id == conflict.id }
        }
        
        return (autoResolvable: autoResolvable, manual: manual)
    }
    
    /// Default resolution validation
    func validateResolution(_ resolution: ConflictResolution, for conflict: SyncConflict) -> Bool {
        let capabilities = getResolverCapabilities()
        
        // Check if strategy is supported
        guard capabilities.supportedStrategies.contains(resolution.strategy) else {
            return false
        }
        
        // Check if conflict type is supported
        guard capabilities.supportedConflictTypes.contains(conflict.conflictType) else {
            return false
        }
        
        // Basic validation based on strategy
        switch resolution.strategy {
        case .localWins, .remoteWins:
            return resolution.chosenVersion != nil
        case .lastWriteWins, .firstWriteWins:
            return true
        case .manual:
            return resolution.resolvedData != nil || resolution.chosenVersion != nil
        }
    }
    
    /// Default capabilities
    func getResolverCapabilities() -> ConflictResolverCapabilities {
        return ConflictResolverCapabilities(
            supportedStrategies: [.lastWriteWins, .firstWriteWins, .localWins, .remoteWins],
            supportsBatchResolution: true,
            supportsAutoResolution: true,
            maxBatchSize: 50
        )
    }
}

