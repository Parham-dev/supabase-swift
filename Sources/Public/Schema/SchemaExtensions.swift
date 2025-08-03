//
//  SchemaExtensions.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Foundation

// MARK: - Error Conversion Extensions

extension SchemaAPI {
    
    /// Convert generic error to SwiftSupabaseSyncError
    internal func convertToPublicError(_ error: Error) -> SwiftSupabaseSyncError {
        if let schemaError = error as? SchemaError {
            return convertSchemaError(schemaError)
        }
        
        return .unknown(underlyingError: error)
    }
    
    /// Convert SchemaError to SwiftSupabaseSyncError
    internal func convertSchemaError(_ error: SchemaError) -> SwiftSupabaseSyncError {
        switch error {
        case .authenticationRequired:
            return .authenticationFailed(reason: .sessionExpired)
        case .modelNotRegistered(let model):
            return .configurationConflict(parameters: ["Model '\(model)' not registered"])
        case .schemaGenerationFailed(_, let reason):
            return .syncSchemaIncompatible(localVersion: "unknown", remoteVersion: reason)
        case .validationFailed(_, let reason):
            return .syncValidationFailed(errors: [reason])
        case .migrationFailed(let table, let reason):
            return .syncSchemaIncompatible(localVersion: table, remoteVersion: reason)
        case .migrationsDisabled:
            return .configurationConflict(parameters: ["Schema migrations disabled"])
        case .multipleErrors(let errors):
            return .syncValidationFailed(errors: errors.map { "\($0.key): \($0.value.localizedDescription)" })
        }
    }
    
    /// Convert SchemaValidationResult to PublicSchemaValidation
    internal func convertToPublicValidation(_ result: SchemaValidationResult) -> PublicSchemaValidation {
        return PublicSchemaValidation(
            modelName: result.tableName,
            isValid: result.isValid,
            errors: result.errors,
            warnings: result.warnings,
            validatedAt: result.validatedAt,
            requiresMigration: !result.isValid && !result.errors.isEmpty
        )
    }
}

// MARK: - Public Convenience Extensions

public extension SchemaAPI {
    
    /// Whether any schema operations are in progress
    var isActive: Bool {
        return status.isActive
    }
    
    /// Get summary of schema health
    var healthSummary: String {
        if !allSchemasValid {
            let errorCount = getModelsWithErrors().count
            let migrationCount = getModelsRequiringMigration().count
            return "⚠️ \(errorCount) errors, \(migrationCount) migrations needed"
        } else if registeredSchemas.isEmpty {
            return "ℹ️ No schemas registered"
        } else {
            return "✅ All schemas valid (\(registeredSchemas.count) models)"
        }
    }
    
    /// Validate and migrate all schemas in one operation
    /// - Returns: Dictionary of operation results
    func validateAndMigrateAll() async -> [String: Result<Void, SwiftSupabaseSyncError>] {
        var results: [String: Result<Void, SwiftSupabaseSyncError>] = [:]
        
        // First validate all
        let validations = await validateAllSchemas()
        
        // Then migrate those that need it
        for (modelName, validation) in validations {
            if validation.requiresMigration {
                // Note: This is simplified - real implementation would resolve types
                results[modelName] = .failure(.configurationConflict(parameters: ["Type resolution needed for migration"]))
            } else if validation.isValid {
                results[modelName] = .success(())
            } else {
                results[modelName] = .failure(.syncValidationFailed(errors: validation.errors))
            }
        }
        
        return results
    }
    
    /// Get schema summary for all models
    /// - Returns: Human-readable schema summary
    func getSchemaSummary() -> String {
        let totalModels = registeredSchemas.count
        let validModels = validationResults.values.filter { $0.isValid }.count
        let invalidModels = totalModels - validModels
        
        var summary = "Schema Summary:\n"
        summary += "• Total Models: \(totalModels)\n"
        summary += "• Valid Schemas: \(validModels)\n"
        
        if invalidModels > 0 {
            summary += "• Invalid Schemas: \(invalidModels)\n"
        }
        
        if status.isActive {
            summary += "• Status: \(status.description)\n"
        }
        
        return summary
    }
    
    /// Get all models with validation errors
    /// - Returns: Array of model names with errors
    func getModelsWithErrors() -> [String] {
        return validationResults.compactMap { (key, value) in
            value.errors.isEmpty ? nil : key
        }
    }
    
    /// Get all models that require migration
    /// - Returns: Array of model names requiring migration
    func getModelsRequiringMigration() -> [String] {
        return validationResults.compactMap { (key, value) in
            value.requiresMigration ? key : nil
        }
    }
    
    // Note: clearErrors() method moved to main SchemaAPI.swift file to access private properties
}

// MARK: - Model Information Extensions

public extension SchemaAPI {
    
    /// Get schema information for a specific model
    /// - Parameter modelType: Type of model to get info for
    /// - Returns: Schema information
    func getSchemaInfo<T: Syncable>(for modelType: T.Type) -> PublicSchemaInfo? {
        return registeredSchemas[T.tableName]
    }
    
    /// Get validation result for a specific model
    /// - Parameter modelType: Type of model to get validation for
    /// - Returns: Validation result
    func getValidationResult<T: Syncable>(for modelType: T.Type) -> PublicSchemaValidation? {
        return validationResults[T.tableName]
    }
    
    /// Check if a model is registered
    /// - Parameter modelType: Type of model to check
    /// - Returns: Whether model is registered
    func isModelRegistered<T: Syncable>(_ modelType: T.Type) -> Bool {
        return registeredSchemas[T.tableName] != nil
    }
    
    /// Get all registered model names
    var registeredModelNames: [String] {
        Array(registeredSchemas.keys)
    }
}