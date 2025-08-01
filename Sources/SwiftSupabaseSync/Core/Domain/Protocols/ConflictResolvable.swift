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

// MARK: - Supporting Types

public struct SyncConflict: Codable, Equatable, Identifiable {
    public let id = UUID()
    
    /// Type of entity in conflict
    public let entityType: String
    
    /// Unique identifier of the conflicted record
    public let recordID: UUID
    
    /// Local version of the record
    public let localSnapshot: SyncSnapshot
    
    /// Remote version of the record
    public let remoteSnapshot: SyncSnapshot
    
    /// Type of conflict detected
    public let conflictType: ConflictType
    
    /// Fields that are in conflict
    public let conflictedFields: Set<String>
    
    /// When the conflict was detected
    public let detectedAt: Date
    
    /// Priority of this conflict (higher numbers = higher priority)
    public let priority: ConflictPriority
    
    /// Additional metadata for custom resolution logic
    public let metadata: [String: Any]
    
    public init(
        entityType: String,
        recordID: UUID,
        localSnapshot: SyncSnapshot,
        remoteSnapshot: SyncSnapshot,
        conflictType: ConflictType = .dataConflict,
        conflictedFields: Set<String> = [],
        detectedAt: Date = Date(),
        priority: ConflictPriority = .normal,
        metadata: [String: Any] = [:]
    ) {
        self.entityType = entityType
        self.recordID = recordID
        self.localSnapshot = localSnapshot
        self.remoteSnapshot = remoteSnapshot
        self.conflictType = conflictType
        self.conflictedFields = conflictedFields
        self.detectedAt = detectedAt
        self.priority = priority
        self.metadata = metadata
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case entityType = "entity_type"
        case recordID = "record_id"
        case localSnapshot = "local_snapshot"
        case remoteSnapshot = "remote_snapshot"
        case conflictType = "conflict_type"
        case conflictedFields = "conflicted_fields"
        case detectedAt = "detected_at"
        case priority
        case metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entityType = try container.decode(String.self, forKey: .entityType)
        recordID = try container.decode(UUID.self, forKey: .recordID)
        localSnapshot = try container.decode(SyncSnapshot.self, forKey: .localSnapshot)
        remoteSnapshot = try container.decode(SyncSnapshot.self, forKey: .remoteSnapshot)
        conflictType = try container.decode(ConflictType.self, forKey: .conflictType)
        conflictedFields = try container.decode(Set<String>.self, forKey: .conflictedFields)
        detectedAt = try container.decode(Date.self, forKey: .detectedAt)
        priority = try container.decode(ConflictPriority.self, forKey: .priority)
        
        // Decode metadata safely
        if let metadataData = try container.decodeIfPresent(Data.self, forKey: .metadata) {
            metadata = (try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any]) ?? [:]
        } else {
            metadata = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entityType, forKey: .entityType)
        try container.encode(recordID, forKey: .recordID)
        try container.encode(localSnapshot, forKey: .localSnapshot)
        try container.encode(remoteSnapshot, forKey: .remoteSnapshot)
        try container.encode(conflictType, forKey: .conflictType)
        try container.encode(conflictedFields, forKey: .conflictedFields)
        try container.encode(detectedAt, forKey: .detectedAt)
        try container.encode(priority, forKey: .priority)
        
        // Encode metadata safely
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        try container.encode(metadataData, forKey: .metadata)
    }
    
    public static func == (lhs: SyncConflict, rhs: SyncConflict) -> Bool {
        return lhs.id == rhs.id &&
               lhs.recordID == rhs.recordID &&
               lhs.localSnapshot == rhs.localSnapshot &&
               lhs.remoteSnapshot == rhs.remoteSnapshot
    }
}

public struct ConflictResolution: Codable, Equatable {
    /// Strategy used to resolve the conflict
    public let strategy: ConflictResolutionStrategy
    
    /// The resolved record data (if merge or custom resolution)
    public let resolvedData: [String: Any]?
    
    /// Which version to use (for simple strategies)
    public let chosenVersion: ConflictVersion?
    
    /// Explanation of the resolution for logging/UI
    public let explanation: String
    
    /// Whether this resolution was automatic or required user input
    public let wasAutomatic: Bool
    
    /// Timestamp when resolution was created
    public let resolvedAt: Date
    
    /// Confidence level of the resolution (0.0 to 1.0)
    public let confidence: Double
    
    public init(
        strategy: ConflictResolutionStrategy,
        resolvedData: [String: Any]? = nil,
        chosenVersion: ConflictVersion? = nil,
        explanation: String,
        wasAutomatic: Bool = true,
        resolvedAt: Date = Date(),
        confidence: Double = 1.0
    ) {
        self.strategy = strategy
        self.resolvedData = resolvedData
        self.chosenVersion = chosenVersion
        self.explanation = explanation
        self.wasAutomatic = wasAutomatic
        self.resolvedAt = resolvedAt
        self.confidence = max(0.0, min(1.0, confidence))
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case strategy
        case resolvedData = "resolved_data"
        case chosenVersion = "chosen_version"
        case explanation
        case wasAutomatic = "was_automatic"
        case resolvedAt = "resolved_at"
        case confidence
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strategy = try container.decode(ConflictResolutionStrategy.self, forKey: .strategy)
        chosenVersion = try container.decodeIfPresent(ConflictVersion.self, forKey: .chosenVersion)
        explanation = try container.decode(String.self, forKey: .explanation)
        wasAutomatic = try container.decode(Bool.self, forKey: .wasAutomatic)
        resolvedAt = try container.decode(Date.self, forKey: .resolvedAt)
        confidence = try container.decode(Double.self, forKey: .confidence)
        
        // Decode resolved data safely
        if let resolvedDataEncoded = try container.decodeIfPresent(Data.self, forKey: .resolvedData) {
            resolvedData = try? JSONSerialization.jsonObject(with: resolvedDataEncoded) as? [String: Any]
        } else {
            resolvedData = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(strategy, forKey: .strategy)
        try container.encodeIfPresent(chosenVersion, forKey: .chosenVersion)
        try container.encode(explanation, forKey: .explanation)
        try container.encode(wasAutomatic, forKey: .wasAutomatic)
        try container.encode(resolvedAt, forKey: .resolvedAt)
        try container.encode(confidence, forKey: .confidence)
        
        // Encode resolved data safely
        if let resolvedData = resolvedData {
            let encodedData = try JSONSerialization.data(withJSONObject: resolvedData)
            try container.encode(encodedData, forKey: .resolvedData)
        }
    }
    
    public static func == (lhs: ConflictResolution, rhs: ConflictResolution) -> Bool {
        return lhs.strategy == rhs.strategy &&
               lhs.chosenVersion == rhs.chosenVersion &&
               lhs.explanation == rhs.explanation &&
               lhs.wasAutomatic == rhs.wasAutomatic
    }
}

public struct ConflictResolverCapabilities: Codable {
    /// Strategies this resolver supports
    public let supportedStrategies: Set<ConflictResolutionStrategy>
    
    /// Whether resolver can handle batch operations
    public let supportsBatchResolution: Bool
    
    /// Whether resolver can auto-resolve conflicts
    public let supportsAutoResolution: Bool
    
    /// Maximum number of conflicts that can be resolved in one batch
    public let maxBatchSize: Int
    
    /// Types of conflicts this resolver can handle
    public let supportedConflictTypes: Set<ConflictType>
    
    /// Custom metadata about resolver capabilities
    public let metadata: [String: String]
    
    public init(
        supportedStrategies: Set<ConflictResolutionStrategy>,
        supportsBatchResolution: Bool = true,
        supportsAutoResolution: Bool = true,
        maxBatchSize: Int = 100,
        supportedConflictTypes: Set<ConflictType> = Set(ConflictType.allCases),
        metadata: [String: String] = [:]
    ) {
        self.supportedStrategies = supportedStrategies
        self.supportsBatchResolution = supportsBatchResolution
        self.supportsAutoResolution = supportsAutoResolution
        self.maxBatchSize = maxBatchSize
        self.supportedConflictTypes = supportedConflictTypes
        self.metadata = metadata
    }
}

// MARK: - Enums

public enum ConflictType: String, CaseIterable, Codable {
    case dataConflict = "data_conflict"
    case deleteConflict = "delete_conflict"
    case versionConflict = "version_conflict"
    case schemaConflict = "schema_conflict"
    case permissionConflict = "permission_conflict"
    
    public var displayName: String {
        switch self {
        case .dataConflict:
            return "Data Conflict"
        case .deleteConflict:
            return "Delete Conflict"
        case .versionConflict:
            return "Version Conflict"
        case .schemaConflict:
            return "Schema Conflict"
        case .permissionConflict:
            return "Permission Conflict"
        }
    }
}

public enum ConflictVersion: String, Codable {
    case local = "local"
    case remote = "remote"
    case merged = "merged"
}

public enum ConflictPriority: Int, CaseIterable, Codable, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    public static func < (lhs: ConflictPriority, rhs: ConflictPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
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

// MARK: - Built-in Conflict Resolvers

/// Simple strategy-based conflict resolver
public struct StrategyBasedConflictResolver: ConflictResolvable {
    private let strategy: ConflictResolutionStrategy
    
    public init(strategy: ConflictResolutionStrategy) {
        self.strategy = strategy
    }
    
    public func resolveConflict(_ conflict: SyncConflict) async throws -> ConflictResolution {
        switch strategy {
        case .lastWriteWins:
            let chosenVersion: ConflictVersion = conflict.localSnapshot.lastModified > conflict.remoteSnapshot.lastModified ? .local : .remote
            return ConflictResolution(
                strategy: .lastWriteWins,
                chosenVersion: chosenVersion,
                explanation: "Resolved using last write wins strategy"
            )
            
        case .firstWriteWins:
            let chosenVersion: ConflictVersion = conflict.localSnapshot.lastModified < conflict.remoteSnapshot.lastModified ? .local : .remote
            return ConflictResolution(
                strategy: .firstWriteWins,
                chosenVersion: chosenVersion,
                explanation: "Resolved using first write wins strategy"
            )
            
        case .localWins:
            return ConflictResolution(
                strategy: .localWins,
                chosenVersion: .local,
                explanation: "Resolved by keeping local version"
            )
            
        case .remoteWins:
            return ConflictResolution(
                strategy: .remoteWins,
                chosenVersion: .remote,
                explanation: "Resolved by keeping remote version"
            )
            
        case .manual:
            throw ConflictResolutionError.manualResolutionRequired(conflict)
        }
    }
    
    public func getResolverCapabilities() -> ConflictResolverCapabilities {
        return ConflictResolverCapabilities(
            supportedStrategies: [strategy],
            supportsBatchResolution: true,
            supportsAutoResolution: strategy != .manual,
            maxBatchSize: 100
        )
    }
}

// MARK: - Errors

public enum ConflictResolutionError: Error, LocalizedError {
    case unsupportedStrategy(ConflictResolutionStrategy)
    case invalidConflictData
    case manualResolutionRequired(SyncConflict)
    case resolutionValidationFailed
    case batchSizeExceeded(Int)
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedStrategy(let strategy):
            return "Unsupported conflict resolution strategy: \(strategy)"
        case .invalidConflictData:
            return "Invalid conflict data provided"
        case .manualResolutionRequired:
            return "Manual conflict resolution required"
        case .resolutionValidationFailed:
            return "Conflict resolution validation failed"
        case .batchSizeExceeded(let size):
            return "Batch size exceeded: \(size)"
        case .unknownError(let message):
            return "Conflict resolution error: \(message)"
        }
    }
}

// MARK: - Convenience Extensions

public extension SyncConflict {
    
    /// Get the newer snapshot based on modification date
    var newerSnapshot: SyncSnapshot {
        return localSnapshot.lastModified > remoteSnapshot.lastModified ? localSnapshot : remoteSnapshot
    }
    
    /// Get the older snapshot based on modification date
    var olderSnapshot: SyncSnapshot {
        return localSnapshot.lastModified < remoteSnapshot.lastModified ? localSnapshot : remoteSnapshot
    }
    
    /// Check if this is a delete conflict
    var isDeleteConflict: Bool {
        return conflictType == .deleteConflict || localSnapshot.isDeleted || remoteSnapshot.isDeleted
    }
    
    /// Get display-friendly conflict description
    var displayDescription: String {
        return "Conflict in \(entityType): \(conflictType.displayName)"
    }
}

public extension ConflictResolution {
    
    /// Create a simple local wins resolution
    static func localWins(explanation: String = "Local version kept") -> ConflictResolution {
        return ConflictResolution(
            strategy: .localWins,
            chosenVersion: .local,
            explanation: explanation
        )
    }
    
    /// Create a simple remote wins resolution
    static func remoteWins(explanation: String = "Remote version kept") -> ConflictResolution {
        return ConflictResolution(
            strategy: .remoteWins,
            chosenVersion: .remote,
            explanation: explanation
        )
    }
    
    /// Create a last write wins resolution
    static func lastWriteWins(chosenVersion: ConflictVersion, explanation: String = "Most recent version kept") -> ConflictResolution {
        return ConflictResolution(
            strategy: .lastWriteWins,
            chosenVersion: chosenVersion,
            explanation: explanation
        )
    }
}