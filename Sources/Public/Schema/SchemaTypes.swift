//
//  SchemaTypes.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Foundation
import Combine

// MARK: - Schema Validation Types

/// Schema validation result for public API
public struct PublicSchemaValidation: Sendable {
    
    /// Model name that was validated
    public let modelName: String
    
    /// Whether the schema is valid
    public let isValid: Bool
    
    /// Schema validation errors
    public let errors: [String]
    
    /// Schema validation warnings
    public let warnings: [String]
    
    /// When validation was performed
    public let validatedAt: Date
    
    /// Whether migration is required
    public let requiresMigration: Bool
    
    public init(
        modelName: String,
        isValid: Bool,
        errors: [String] = [],
        warnings: [String] = [],
        validatedAt: Date = Date(),
        requiresMigration: Bool = false
    ) {
        self.modelName = modelName
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.validatedAt = validatedAt
        self.requiresMigration = requiresMigration
    }
}

// MARK: - Schema Migration Types

/// Schema migration result for public API
public struct PublicSchemaMigration: Sendable {
    
    /// Model name that was migrated
    public let modelName: String
    
    /// Whether migration was successful
    public let success: Bool
    
    /// Migration changes applied
    public let changes: [String]
    
    /// When migration was performed
    public let migratedAt: Date
    
    /// Error message if migration failed
    public let errorMessage: String?
    
    public init(
        modelName: String,
        success: Bool,
        changes: [String] = [],
        migratedAt: Date = Date(),
        errorMessage: String? = nil
    ) {
        self.modelName = modelName
        self.success = success
        self.changes = changes
        self.migratedAt = migratedAt
        self.errorMessage = errorMessage
    }
}

// MARK: - Schema Information Types

/// Schema information for public API
public struct PublicSchemaInfo: Sendable {
    
    /// Model name
    public let modelName: String
    
    /// Whether model is registered for sync
    public let isRegistered: Bool
    
    /// Schema version
    public let version: String
    
    /// Number of columns in the schema
    public let columnCount: Int
    
    /// Whether schema is compatible with remote
    public let isCompatible: Bool
    
    /// Last validation timestamp
    public let lastValidated: Date?
    
    public init(
        modelName: String,
        isRegistered: Bool,
        version: String,
        columnCount: Int,
        isCompatible: Bool,
        lastValidated: Date? = nil
    ) {
        self.modelName = modelName
        self.isRegistered = isRegistered
        self.version = version
        self.columnCount = columnCount
        self.isCompatible = isCompatible
        self.lastValidated = lastValidated
    }
}

// MARK: - Schema Status Types

/// Schema operation status
public enum PublicSchemaStatus: String, CaseIterable, Sendable {
    case idle = "idle"
    case validating = "validating"
    case migrating = "migrating"
    case generating = "generating"
    case error = "error"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .idle: return "Ready"
        case .validating: return "Validating Schema"
        case .migrating: return "Migrating Schema"
        case .generating: return "Generating Schema"
        case .error: return "Schema Error"
        }
    }
    
    /// Whether schema operations are active
    public var isActive: Bool {
        switch self {
        case .validating, .migrating, .generating: return true
        case .idle, .error: return false
        }
    }
}

// MARK: - Schema Observer Protocol

/// Protocol for observing schema events
public protocol SchemaObserver: AnyObject {
    
    /// Called when schema validation completes
    /// - Parameter result: Validation result
    func schemaValidationCompleted(_ result: PublicSchemaValidation)
    
    /// Called when schema migration completes
    /// - Parameter result: Migration result
    func schemaMigrationCompleted(_ result: PublicSchemaMigration)
    
    /// Called when schema status changes
    /// - Parameters:
    ///   - status: New schema status
    ///   - modelName: Model name (nil for global status)
    func schemaStatusChanged(_ status: PublicSchemaStatus, for modelName: String?)
    
    /// Called when schema error occurs
    /// - Parameters:
    ///   - error: Schema error
    ///   - modelName: Model name where error occurred
    func schemaErrorOccurred(_ error: SwiftSupabaseSyncError, for modelName: String)
}

// MARK: - Schema Validation Extensions

public extension PublicSchemaValidation {
    
    /// Whether validation passed without errors
    var hasErrors: Bool {
        return !errors.isEmpty
    }
    
    /// Whether validation has warnings
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
    
    /// Combined error and warning count
    var issueCount: Int {
        return errors.count + warnings.count
    }
    
    /// Summary of validation status
    var statusSummary: String {
        if isValid {
            return hasWarnings ? "Valid (with \(warnings.count) warnings)" : "Valid"
        } else {
            return "Invalid (\(errors.count) errors)"
        }
    }
    
    /// Create a success validation result
    static func success(for modelName: String) -> PublicSchemaValidation {
        return PublicSchemaValidation(
            modelName: modelName,
            isValid: true,
            validatedAt: Date()
        )
    }
    
    /// Create a failure validation result
    static func failure(for modelName: String, errors: [String]) -> PublicSchemaValidation {
        return PublicSchemaValidation(
            modelName: modelName,
            isValid: false,
            errors: errors,
            validatedAt: Date(),
            requiresMigration: true
        )
    }
}

// MARK: - Schema Migration Extensions

public extension PublicSchemaMigration {
    
    /// Whether migration was successful
    var wasSuccessful: Bool {
        return success && errorMessage == nil
    }
    
    /// Whether migration had changes
    var hadChanges: Bool {
        return !changes.isEmpty
    }
    
    /// Summary of migration result
    var resultSummary: String {
        if success {
            return hadChanges ? "Success (\(changes.count) changes)" : "Success (no changes)"
        } else {
            return "Failed: \(errorMessage ?? "Unknown error")"
        }
    }
    
    /// Create a success migration result
    static func success(for modelName: String, changes: [String] = []) -> PublicSchemaMigration {
        return PublicSchemaMigration(
            modelName: modelName,
            success: true,
            changes: changes,
            migratedAt: Date()
        )
    }
    
    /// Create a failure migration result
    static func failure(for modelName: String, error: String) -> PublicSchemaMigration {
        return PublicSchemaMigration(
            modelName: modelName,
            success: false,
            migratedAt: Date(),
            errorMessage: error
        )
    }
}

// MARK: - Schema Info Extensions

public extension PublicSchemaInfo {
    
    /// Schema health status
    var healthStatus: String {
        if !isRegistered {
            return "⚪ Not Registered"
        } else if !isCompatible {
            return "❌ Incompatible"
        } else {
            return "✅ Compatible"
        }
    }
    
    /// Time since last validation
    var timeSinceValidation: String? {
        guard let lastValidated = lastValidated else { return nil }
        
        let interval = Date().timeIntervalSince(lastValidated)
        let minutes = Int(interval / 60)
        
        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes) minutes ago"
        } else {
            let hours = minutes / 60
            return "\(hours) hours ago"
        }
    }
    
    /// Schema summary line
    var summary: String {
        var parts: [String] = []
        
        parts.append("\(columnCount) columns")
        parts.append("v\(version)")
        
        if let timeString = timeSinceValidation {
            parts.append("validated \(timeString)")
        }
        
        return parts.joined(separator: " • ")
    }
}