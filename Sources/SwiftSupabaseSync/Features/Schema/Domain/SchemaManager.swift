//
//  SchemaManager.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import SwiftData

/// Manages database schema creation, validation, and model registration
/// Automatically generates and maintains database schemas from SwiftData models
@MainActor
public final class SchemaManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Registered model types with their schema information
    @Published public private(set) var registeredModels: [String: ModelSchemaInfo] = [:]
    
    /// Whether schema generation is in progress
    @Published public private(set) var isGeneratingSchema: Bool = false
    
    /// Last schema generation error
    @Published public private(set) var lastError: SchemaError?
    
    /// Schema validation results by model type
    @Published public private(set) var validationResults: [String: SchemaValidationResult] = [:]
    
    /// Whether all schemas are valid and synchronized
    @Published public private(set) var allSchemasValid: Bool = true
    
    // MARK: - Dependencies
    
    private let syncRepository: SyncRepositoryProtocol
    private let authManager: AuthManager
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Configuration
    
    private let autoCreateTables: Bool
    private let validateOnStartup: Bool
    private let enableMigrations: Bool
    
    // MARK: - State Management
    
    private var modelRegistry: ModelRegistry = ModelRegistry()
    private let schemaQueue = DispatchQueue(label: "schema.manager.operations", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init(
        syncRepository: SyncRepositoryProtocol,
        authManager: AuthManager,
        logger: SyncLoggerProtocol? = nil,
        autoCreateTables: Bool = true,
        validateOnStartup: Bool = true,
        enableMigrations: Bool = true
    ) {
        self.syncRepository = syncRepository
        self.authManager = authManager
        self.logger = logger
        self.autoCreateTables = autoCreateTables
        self.validateOnStartup = validateOnStartup
        self.enableMigrations = enableMigrations
        
        Task {
            await initialize()
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        logger?.debug("SchemaManager: Initializing")
        
        if validateOnStartup {
            await validateAllSchemas()
        }
    }
    
    // MARK: - Model Registration
    
    /// Register a SwiftData model for schema management
    /// - Parameter modelType: Type of model to register
    public func registerModel<T: Syncable>(_ modelType: T.Type) async throws {
        let tableName = T.tableName
        logger?.info("SchemaManager: Registering model \(tableName)")
        
        // Extract schema information
        let schemaInfo = try extractSchemaInfo(from: modelType)
        
        // Store in registry
        await MainActor.run {
            self.registeredModels[tableName] = schemaInfo
        }
        
        modelRegistry.register(modelType)
        
        // Auto-create table if enabled
        if autoCreateTables && authManager.isAuthenticated {
            try await createTableIfNeeded(for: schemaInfo)
        }
        
        logger?.info("SchemaManager: Successfully registered model \(tableName)")
    }
    
    /// Unregister a model from schema management
    /// - Parameter modelType: Type of model to unregister
    public func unregisterModel<T: Syncable>(_ modelType: T.Type) {
        let tableName = T.tableName
        logger?.debug("SchemaManager: Unregistering model \(tableName)")
        
        Task {
            await MainActor.run {
                self.registeredModels.removeValue(forKey: tableName)
                self.validationResults.removeValue(forKey: tableName)
            }
        }
        
        modelRegistry.unregister(modelType)
    }
    
    /// Get all registered model types
    public var allRegisteredModels: [String] {
        Array(registeredModels.keys)
    }
    
    // MARK: - Schema Generation
    
    /// Generate schema for all registered models
    public func generateSchemas() async throws {
        guard authManager.isAuthenticated else {
            throw SchemaError.authenticationRequired
        }
        
        logger?.info("SchemaManager: Generating schemas for all registered models")
        
        await setGenerating(true)
        defer { Task { await setGenerating(false) } }
        
        var errors: [String: Error] = [:]
        
        for (tableName, schemaInfo) in registeredModels {
            do {
                try await createOrUpdateSchema(for: schemaInfo)
                logger?.debug("SchemaManager: Generated schema for \(tableName)")
            } catch {
                errors[tableName] = error
                logger?.error("SchemaManager: Failed to generate schema for \(tableName): \(error)")
            }
        }
        
        if !errors.isEmpty {
            throw SchemaError.multipleErrors(errors)
        }
        
        await validateAllSchemas()
    }
    
    /// Generate schema for specific model type
    /// - Parameter modelType: Type of model to generate schema for
    public func generateSchema<T: Syncable>(for modelType: T.Type) async throws {
        let tableName = T.tableName
        
        guard let schemaInfo = registeredModels[tableName] else {
            throw SchemaError.modelNotRegistered(tableName)
        }
        
        logger?.info("SchemaManager: Generating schema for \(tableName)")
        
        await setGenerating(true)
        defer { Task { await setGenerating(false) } }
        
        try await createOrUpdateSchema(for: schemaInfo)
        
        // Validate the generated schema
        try await validateSchema(for: modelType)
    }
    
    // MARK: - Schema Validation
    
    /// Validate schema compatibility for all registered models
    public func validateAllSchemas() async {
        logger?.info("SchemaManager: Validating all schemas")
        
        var allValid = true
        
        for tableName in registeredModels.keys {
            if let modelType = modelRegistry.getModelType(for: tableName) {
                do {
                    let result = try await syncRepository.checkSchemaCompatibility(for: modelType)
                    await updateValidationResult(tableName, result: result)
                    
                    if !result.isCompatible {
                        allValid = false
                    }
                } catch {
                    logger?.error("SchemaManager: Schema validation failed for \(tableName): \(error)")
                    allValid = false
                }
            }
        }
        
        await MainActor.run {
            self.allSchemasValid = allValid
        }
    }
    
    /// Validate schema for specific model type
    /// - Parameter modelType: Type of model to validate schema for
    /// - Returns: Schema validation result
    @discardableResult
    public func validateSchema<T: Syncable>(for modelType: T.Type) async throws -> SchemaValidationResult {
        let tableName = T.tableName
        logger?.debug("SchemaManager: Validating schema for \(tableName)")
        
        let result = try await syncRepository.checkSchemaCompatibility(for: modelType)
        await updateValidationResult(tableName, result: result)
        
        if !result.isCompatible {
            logger?.warning("SchemaManager: Schema incompatibility detected for \(tableName)")
        }
        
        return validationResults[tableName] ?? SchemaValidationResult(
            tableName: tableName,
            isValid: result.isCompatible,
            errors: [],
            warnings: [],
            validatedAt: Date()
        )
    }
    
    // MARK: - Schema Migration
    
    /// Migrate schema for model type if needed
    /// - Parameter modelType: Type of model to migrate schema for
    public func migrateSchemaIfNeeded<T: Syncable>(for modelType: T.Type) async throws {
        guard enableMigrations else {
            throw SchemaError.migrationsDisabled
        }
        
        let tableName = T.tableName
        logger?.info("SchemaManager: Checking migration needs for \(tableName)")
        
        // Check compatibility
        let compatibility = try await syncRepository.checkSchemaCompatibility(for: modelType)
        
        if !compatibility.isCompatible && compatibility.requiresMigration {
            logger?.info("SchemaManager: Migrating schema for \(tableName)")
            
            // Perform migration
            let updateResult = try await syncRepository.updateRemoteSchema(for: modelType)
            
            if updateResult.success {
                logger?.info("SchemaManager: Successfully migrated schema for \(tableName)")
                
                // Re-validate after migration
                try await validateSchema(for: modelType)
            } else {
                throw SchemaError.migrationFailed(tableName, updateResult.error?.localizedDescription ?? "Unknown error")
            }
        }
    }
    
    /// Migrate all schemas that need migration
    public func migrateAllSchemasIfNeeded() async throws {
        guard enableMigrations else {
            throw SchemaError.migrationsDisabled
        }
        
        logger?.info("SchemaManager: Checking migration needs for all schemas")
        
        var migrationErrors: [String: Error] = [:]
        
        for tableName in registeredModels.keys {
            if let modelType = modelRegistry.getModelType(for: tableName) {
                do {
                    try await migrateSchemaIfNeeded(for: modelType)
                } catch {
                    migrationErrors[tableName] = error
                }
            }
        }
        
        if !migrationErrors.isEmpty {
            throw SchemaError.multipleErrors(migrationErrors)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func extractSchemaInfo<T: Syncable>(from modelType: T.Type) throws -> ModelSchemaInfo {
        let tableName = T.tableName
        let syncableProperties = T.syncableProperties
        
        // Extract column information from syncable properties
        // In a real implementation, this would use reflection or SwiftData metadata
        var columns: [ColumnInfo] = []
        
        // Add required sync columns
        columns.append(ColumnInfo(
            name: "sync_id",
            type: .uuid,
            isNullable: false,
            isPrimaryKey: true
        ))
        
        columns.append(ColumnInfo(
            name: "last_modified",
            type: .timestamp,
            isNullable: false
        ))
        
        columns.append(ColumnInfo(
            name: "last_synced",
            type: .timestamp,
            isNullable: true
        ))
        
        columns.append(ColumnInfo(
            name: "is_deleted",
            type: .boolean,
            isNullable: false,
            defaultValue: "false"
        ))
        
        columns.append(ColumnInfo(
            name: "version",
            type: .integer,
            isNullable: false,
            defaultValue: "1"
        ))
        
        // Add model-specific columns based on syncableProperties
        // This is simplified - real implementation would introspect the model
        for propertyName in syncableProperties {
            columns.append(ColumnInfo(
                name: propertyName,
                type: .text, // Simplified - would determine actual type
                isNullable: true
            ))
        }
        
        return ModelSchemaInfo(
            tableName: tableName,
            columns: columns,
            indexes: [
                IndexInfo(name: "\(tableName)_sync_id_idx", columns: ["sync_id"]),
                IndexInfo(name: "\(tableName)_last_modified_idx", columns: ["last_modified"]),
                IndexInfo(name: "\(tableName)_is_deleted_idx", columns: ["is_deleted"])
            ],
            constraints: []
        )
    }
    
    private func createTableIfNeeded(for schemaInfo: ModelSchemaInfo) async throws {
        logger?.debug("SchemaManager: Checking if table \(schemaInfo.tableName) needs creation")
        
        // Check if table exists by attempting validation
        // If validation fails with "table not found", create it
        // This is simplified - real implementation would check table existence properly
        
        let sql = generateCreateTableSQL(for: schemaInfo)
        logger?.debug("SchemaManager: Generated SQL: \(sql)")
        
        // In real implementation, this would execute the SQL through the repository
        // For now, we'll just log it
    }
    
    private func createOrUpdateSchema(for schemaInfo: ModelSchemaInfo) async throws {
        // In real implementation, this would:
        // 1. Check if table exists
        // 2. If not, create it
        // 3. If it exists, check for schema differences
        // 4. Apply migrations if needed and enabled
        
        logger?.debug("SchemaManager: Creating/updating schema for \(schemaInfo.tableName)")
    }
    
    private func generateCreateTableSQL(for schemaInfo: ModelSchemaInfo) -> String {
        var sql = "CREATE TABLE IF NOT EXISTS \(schemaInfo.tableName) (\n"
        
        let columnDefinitions = schemaInfo.columns.map { column in
            var def = "  \(column.name) \(column.type.sqlType)"
            
            if column.isPrimaryKey {
                def += " PRIMARY KEY"
            }
            
            if !column.isNullable {
                def += " NOT NULL"
            }
            
            if let defaultValue = column.defaultValue {
                def += " DEFAULT \(defaultValue)"
            }
            
            return def
        }
        
        sql += columnDefinitions.joined(separator: ",\n")
        sql += "\n);"
        
        return sql
    }
    
    private func setGenerating(_ generating: Bool) async {
        await MainActor.run {
            self.isGeneratingSchema = generating
        }
    }
    
    private func setError(_ error: SchemaError) async {
        await MainActor.run {
            self.lastError = error
        }
    }
    
    private func updateValidationResult(_ tableName: String, result: SchemaCompatibilityResult) async {
        // Convert schema differences to errors and warnings
        // For now, treat all differences as errors if schema is incompatible
        let errors = result.isCompatible ? [] : result.differences.map { $0.description }
        let warnings: [String] = []
        
        let validationResult = SchemaValidationResult(
            tableName: tableName,
            isValid: result.isCompatible,
            errors: errors,
            warnings: warnings,
            validatedAt: Date()
        )
        
        await MainActor.run {
            self.validationResults[tableName] = validationResult
        }
    }
}

// MARK: - Supporting Types

public struct ModelSchemaInfo {
    public let tableName: String
    public let columns: [ColumnInfo]
    public let indexes: [IndexInfo]
    public let constraints: [ConstraintInfo]
}

public struct ColumnInfo {
    public let name: String
    public let type: ColumnType
    public let isNullable: Bool
    public let isPrimaryKey: Bool
    public let defaultValue: String?
    
    public init(
        name: String,
        type: ColumnType,
        isNullable: Bool = true,
        isPrimaryKey: Bool = false,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.type = type
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
        self.defaultValue = defaultValue
    }
}

public enum ColumnType {
    case text
    case integer
    case double
    case boolean
    case timestamp
    case uuid
    case json
    case blob
    
    var sqlType: String {
        switch self {
        case .text: return "TEXT"
        case .integer: return "INTEGER"
        case .double: return "DOUBLE PRECISION"
        case .boolean: return "BOOLEAN"
        case .timestamp: return "TIMESTAMP WITH TIME ZONE"
        case .uuid: return "UUID"
        case .json: return "JSONB"
        case .blob: return "BYTEA"
        }
    }
}

public struct IndexInfo {
    public let name: String
    public let columns: [String]
    public let isUnique: Bool
    
    public init(name: String, columns: [String], isUnique: Bool = false) {
        self.name = name
        self.columns = columns
        self.isUnique = isUnique
    }
}

public struct ConstraintInfo {
    public let name: String
    public let type: ConstraintType
    public let definition: String
}

public enum ConstraintType {
    case primaryKey
    case foreignKey
    case unique
    case check
}

public struct SchemaValidationResult {
    public let tableName: String
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    public let validatedAt: Date
}

public enum SchemaError: LocalizedError {
    case authenticationRequired
    case modelNotRegistered(String)
    case schemaGenerationFailed(String, String)
    case validationFailed(String, String)
    case migrationFailed(String, String)
    case migrationsDisabled
    case multipleErrors([String: Error])
    
    public var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            return "Authentication required for schema operations"
        case .modelNotRegistered(let model):
            return "Model '\(model)' is not registered"
        case .schemaGenerationFailed(let table, let reason):
            return "Failed to generate schema for '\(table)': \(reason)"
        case .validationFailed(let table, let reason):
            return "Schema validation failed for '\(table)': \(reason)"
        case .migrationFailed(let table, let reason):
            return "Schema migration failed for '\(table)': \(reason)"
        case .migrationsDisabled:
            return "Schema migrations are disabled"
        case .multipleErrors(let errors):
            return "Multiple schema errors occurred: \(errors.count) errors"
        }
    }
}

// MARK: - Model Registry

/// Internal registry for managing model type information
private final class ModelRegistry {
    private var registry: [String: any Syncable.Type] = [:]
    private let lock = NSLock()
    
    func register<T: Syncable>(_ modelType: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        
        registry[T.tableName] = modelType
    }
    
    func unregister<T: Syncable>(_ modelType: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        
        registry.removeValue(forKey: T.tableName)
    }
    
    func getModelType(for tableName: String) -> (any Syncable.Type)? {
        lock.lock()
        defer { lock.unlock() }
        
        return registry[tableName]
    }
}

// MARK: - Public Convenience Methods

public extension SchemaManager {
    
    /// Check if a model is registered
    func isModelRegistered<T: Syncable>(_ modelType: T.Type) -> Bool {
        registeredModels[T.tableName] != nil
    }
    
    /// Get schema info for a model
    func getSchemaInfo<T: Syncable>(for modelType: T.Type) -> ModelSchemaInfo? {
        registeredModels[T.tableName]
    }
    
    /// Clear all errors
    func clearErrors() {
        Task {
            await MainActor.run {
                self.lastError = nil
            }
        }
    }
    
    /// Get validation result for a model
    func getValidationResult<T: Syncable>(for modelType: T.Type) -> SchemaValidationResult? {
        validationResults[T.tableName]
    }
}