//
//  SyncSchemaTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Schema Compatibility and Updates

/// Result of checking schema compatibility between local and remote
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

/// Result of updating remote schema to match local schema
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

// MARK: - Schema Difference and Change Types

/// Represents a difference between local and remote schemas
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

/// Represents a schema change to be applied
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

// MARK: - Schema Enums

/// Types of differences that can exist between schemas
public enum SchemaDifferenceType: String, CaseIterable, Codable {
    case fieldAdded = "field_added"
    case fieldRemoved = "field_removed"
    case fieldTypeChanged = "field_type_changed"
    case fieldNullabilityChanged = "field_nullability_changed"
    case indexAdded = "index_added"
    case indexRemoved = "index_removed"
}

/// Types of schema changes that can be applied
public enum SchemaChangeType: String, CaseIterable, Codable {
    case addColumn = "add_column"
    case dropColumn = "drop_column"
    case alterColumn = "alter_column"
    case addIndex = "add_index"
    case dropIndex = "drop_index"
    case createTable = "create_table"
    case dropTable = "drop_table"
}