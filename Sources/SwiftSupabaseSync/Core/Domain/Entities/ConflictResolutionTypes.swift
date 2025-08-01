//
//  ConflictResolutionTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Result of a conflict resolution operation
public struct ConflictResolutionResult {
    /// The original conflict
    public let conflict: SyncConflict
    
    /// The resolution that was applied (if successful)
    public let resolution: ConflictResolution?
    
    /// Whether resolution was successful
    public let success: Bool
    
    /// When resolution was applied
    public let appliedAt: Date
    
    /// ID of user who resolved the conflict
    public let resolvedBy: UUID
    
    /// Error if resolution failed
    public let error: ConflictResolutionError?
    
    public init(
        conflict: SyncConflict,
        resolution: ConflictResolution?,
        success: Bool,
        appliedAt: Date = Date(),
        resolvedBy: UUID,
        error: ConflictResolutionError? = nil
    ) {
        self.conflict = conflict
        self.resolution = resolution
        self.success = success
        self.appliedAt = appliedAt
        self.resolvedBy = resolvedBy
        self.error = error
    }
}

/// Result of automatic conflict resolution operation
public struct AutoResolutionResult {
    /// Entity type that was processed
    public let entityType: String
    
    /// Total number of conflicts found
    public let totalConflicts: Int
    
    /// Number of conflicts auto-resolved
    public let autoResolvedCount: Int
    
    /// Number of conflicts requiring manual resolution
    public let manualRequiredCount: Int
    
    /// Whether auto-resolution was successful
    public let success: Bool
    
    /// Processing timestamp
    public let processedAt: Date
    
    /// Errors encountered during auto-resolution
    public let errors: [ConflictResolutionError]
    
    public init(
        entityType: String,
        totalConflicts: Int,
        autoResolvedCount: Int,
        manualRequiredCount: Int,
        success: Bool,
        processedAt: Date = Date(),
        errors: [ConflictResolutionError] = [],
        error: ConflictResolutionError? = nil
    ) {
        self.entityType = entityType
        self.totalConflicts = totalConflicts
        self.autoResolvedCount = autoResolvedCount
        self.manualRequiredCount = manualRequiredCount
        self.success = success
        self.processedAt = processedAt
        
        if let error = error {
            self.errors = [error]
        } else {
            self.errors = errors
        }
    }
}

/// Record of a resolved conflict for history tracking
public struct ConflictResolutionRecord: Identifiable {
    /// Unique record ID
    public let id: UUID
    
    /// ID of the conflict that was resolved
    public let conflictId: UUID
    
    /// Entity type that had the conflict
    public let entityType: String
    
    /// Strategy used for resolution
    public let strategy: ConflictResolutionStrategy
    
    /// Whether resolution was successful
    public let success: Bool
    
    /// When conflict was resolved
    public let resolvedAt: Date
    
    /// ID of user who resolved the conflict
    public let resolvedBy: UUID
    
    /// Error if resolution failed
    public let error: ConflictResolutionError?
    
    public init(
        id: UUID = UUID(),
        conflictId: UUID,
        entityType: String,
        strategy: ConflictResolutionStrategy,
        success: Bool,
        resolvedAt: Date = Date(),
        resolvedBy: UUID,
        error: ConflictResolutionError? = nil
    ) {
        self.id = id
        self.conflictId = conflictId
        self.entityType = entityType
        self.strategy = strategy
        self.success = success
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.error = error
    }
}

// MARK: - Error Extensions

extension ConflictResolutionError {
    static let autoResolutionDisabled = ConflictResolutionError.unknownError("Auto-resolution is disabled")
}