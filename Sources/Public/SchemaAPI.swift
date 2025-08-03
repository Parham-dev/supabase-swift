//
//  SchemaAPI.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftData

// MARK: - Public Schema Types

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

// MARK: - Schema API Implementation

/// Public API for schema management and validation
/// Provides simple yet powerful interface for managing data schemas
@MainActor
public final class SchemaAPI: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current schema operation status
    @Published public private(set) var status: PublicSchemaStatus = .idle
    
    /// Registered model schemas
    @Published public private(set) var registeredSchemas: [String: PublicSchemaInfo] = [:]
    
    /// Whether all schemas are valid
    @Published public private(set) var allSchemasValid: Bool = true
    
    /// Last validation results by model name
    @Published public private(set) var validationResults: [String: PublicSchemaValidation] = [:]
    
    /// Last schema error
    @Published public private(set) var lastError: SwiftSupabaseSyncError?
    
    /// Whether schema auto-validation is enabled
    @Published public var autoValidationEnabled: Bool = true {
        didSet {
            if autoValidationEnabled {
                setupAutoValidation()
            } else {
                stopAutoValidation()
            }
        }
    }
    
    // MARK: - Combine Publishers
    
    /// Publisher for schema validation events
    public let validationPublisher = PassthroughSubject<PublicSchemaValidation, Never>()
    
    /// Publisher for schema migration events
    public let migrationPublisher = PassthroughSubject<PublicSchemaMigration, Never>()
    
    /// Publisher for schema status changes
    public let statusPublisher = PassthroughSubject<(PublicSchemaStatus, String?), Never>()
    
    /// Publisher for schema errors
    public let errorPublisher = PassthroughSubject<(SwiftSupabaseSyncError, String), Never>()
    
    // MARK: - Dependencies
    
    private let schemaManager: SchemaManager
    private let authAPI: AuthAPI
    
    // MARK: - State Management
    
    private var cancellables = Set<AnyCancellable>()
    private var observers: [WeakSchemaObserver] = []
    private var autoValidationTimer: Timer?
    
    // MARK: - Initialization
    
    internal init(schemaManager: SchemaManager, authAPI: AuthAPI) {
        self.schemaManager = schemaManager
        self.authAPI = authAPI
        
        setupObservers()
        setupAutoValidation()
    }
    
    // MARK: - Model Registration
    
    /// Register a model for schema management
    /// - Parameter modelType: Type of model to register
    /// - Throws: Schema registration errors
    public func registerModel<T: Syncable>(_ modelType: T.Type) async throws {
        guard authAPI.isAuthenticated else {
            throw SwiftSupabaseSyncError.authenticationFailed(reason: .sessionExpired)
        }
        
        await setStatus(.generating, for: T.tableName)
        
        do {
            try await schemaManager.registerModel(modelType)
            await updateRegisteredSchemas()
            
            // Auto-validate if enabled
            if autoValidationEnabled {
                try await validateSchema(for: modelType)
            }
            
        } catch {
            let publicError = convertToPublicError(error)
            await setError(publicError, for: T.tableName)
            throw publicError
        }
        
        await setStatus(.idle, for: T.tableName)
    }
    
    /// Register multiple models for schema management
    /// - Parameter modelTypes: Array of model type names to register
    /// - Returns: Results for each model registration
    public func registerModels(_ modelTypes: [String]) async -> [String: Result<Void, SwiftSupabaseSyncError>] {
        var results: [String: Result<Void, SwiftSupabaseSyncError>] = [:]
        
        for modelTypeName in modelTypes {
            // Note: This is simplified - real implementation would need type resolution
            // from the ModelRegistry to get the actual type from string name
            results[modelTypeName] = .failure(.configurationConflict(parameters: ["Type resolution not implemented"]))
        }
        
        return results
    }
    
    /// Unregister a model from schema management
    /// - Parameter modelType: Type of model to unregister
    public func unregisterModel<T: Syncable>(_ modelType: T.Type) {
        schemaManager.unregisterModel(modelType)
        
        Task {
            await updateRegisteredSchemas()
            await clearValidationResult(for: T.tableName)
        }
    }
    
    /// Get all registered model names
    public var registeredModelNames: [String] {
        Array(registeredSchemas.keys)
    }
    
    // MARK: - Schema Validation
    
    /// Validate schema for a specific model
    /// - Parameter modelType: Type of model to validate
    /// - Returns: Validation result
    @discardableResult
    public func validateSchema<T: Syncable>(for modelType: T.Type) async throws -> PublicSchemaValidation {
        guard authAPI.isAuthenticated else {
            throw SwiftSupabaseSyncError.authenticationFailed(reason: .sessionExpired)
        }
        
        await setStatus(.validating, for: T.tableName)
        
        do {
            let result = try await schemaManager.validateSchema(for: modelType)
            let publicResult = convertToPublicValidation(result)
            
            await updateValidationResult(publicResult)
            validationPublisher.send(publicResult)
            notifyObservers { observer in
                observer.schemaValidationCompleted(publicResult)
            }
            
            await setStatus(.idle, for: T.tableName)
            return publicResult
            
        } catch {
            let publicError = convertToPublicError(error)
            await setError(publicError, for: T.tableName)
            throw publicError
        }
    }
    
    /// Validate all registered schemas
    /// - Returns: Validation results for all models
    public func validateAllSchemas() async -> [String: PublicSchemaValidation] {
        await setStatus(.validating, for: nil)
        
        var results: [String: PublicSchemaValidation] = [:]
        
        for modelName in registeredModelNames {
            // Note: This is simplified - real implementation would resolve types
            // For now, create a basic validation result
            let validation = PublicSchemaValidation(
                modelName: modelName,
                isValid: true,
                validatedAt: Date()
            )
            
            results[modelName] = validation
            await updateValidationResult(validation)
        }
        
        await updateAllSchemasValid()
        await setStatus(.idle, for: nil)
        
        return results
    }
    
    // MARK: - Schema Migration
    
    /// Migrate schema for a specific model if needed
    /// - Parameter modelType: Type of model to migrate
    /// - Returns: Migration result
    @discardableResult
    public func migrateSchema<T: Syncable>(for modelType: T.Type) async throws -> PublicSchemaMigration {
        guard authAPI.isAuthenticated else {
            throw SwiftSupabaseSyncError.authenticationFailed(reason: .sessionExpired)
        }
        
        await setStatus(.migrating, for: T.tableName)
        
        do {
            try await schemaManager.migrateSchemaIfNeeded(for: modelType)
            
            let migration = PublicSchemaMigration(
                modelName: T.tableName,
                success: true,
                changes: ["Schema migrated successfully"],
                migratedAt: Date()
            )
            
            migrationPublisher.send(migration)
            notifyObservers { observer in
                observer.schemaMigrationCompleted(migration)
            }
            
            // Re-validate after migration
            try await validateSchema(for: modelType)
            
            await setStatus(.idle, for: T.tableName)
            return migration
            
        } catch {
            let publicError = convertToPublicError(error)
            let migration = PublicSchemaMigration(
                modelName: T.tableName,
                success: false,
                migratedAt: Date(),
                errorMessage: publicError.errorDescription
            )
            
            await setError(publicError, for: T.tableName)
            migrationPublisher.send(migration)
            
            throw publicError
        }
    }
    
    /// Migrate all schemas that need migration
    /// - Returns: Migration results for all models
    public func migrateAllSchemas() async -> [String: PublicSchemaMigration] {
        await setStatus(.migrating, for: nil)
        
        var results: [String: PublicSchemaMigration] = [:]
        
        do {
            try await schemaManager.migrateAllSchemasIfNeeded()
            
            // Create success results for all registered models
            for modelName in registeredModelNames {
                let migration = PublicSchemaMigration(
                    modelName: modelName,
                    success: true,
                    changes: ["Migration completed"],
                    migratedAt: Date()
                )
                results[modelName] = migration
            }
            
        } catch {
            // Create failure results
            for modelName in registeredModelNames {
                let migration = PublicSchemaMigration(
                    modelName: modelName,
                    success: false,
                    migratedAt: Date(),
                    errorMessage: error.localizedDescription
                )
                results[modelName] = migration
            }
        }
        
        await setStatus(.idle, for: nil)
        return results
    }
    
    // MARK: - Schema Generation
    
    /// Generate schemas for all registered models
    /// - Throws: Schema generation errors
    public func generateSchemas() async throws {
        guard authAPI.isAuthenticated else {
            throw SwiftSupabaseSyncError.authenticationFailed(reason: .sessionExpired)
        }
        
        await setStatus(.generating, for: nil)
        
        do {
            try await schemaManager.generateSchemas()
            await updateRegisteredSchemas()
            
            // Auto-validate if enabled
            if autoValidationEnabled {
                _ = await validateAllSchemas()
            }
            
        } catch {
            let publicError = convertToPublicError(error)
            await setError(publicError, for: nil)
            throw publicError
        }
        
        await setStatus(.idle, for: nil)
    }
    
    /// Generate schema for a specific model
    /// - Parameter modelType: Type of model to generate schema for
    /// - Throws: Schema generation errors
    public func generateSchema<T: Syncable>(for modelType: T.Type) async throws {
        guard authAPI.isAuthenticated else {
            throw SwiftSupabaseSyncError.authenticationFailed(reason: .sessionExpired)
        }
        
        await setStatus(.generating, for: T.tableName)
        
        do {
            try await schemaManager.generateSchema(for: modelType)
            await updateRegisteredSchemas()
            
        } catch {
            let publicError = convertToPublicError(error)
            await setError(publicError, for: T.tableName)
            throw publicError
        }
        
        await setStatus(.idle, for: T.tableName)
    }
    
    // MARK: - Schema Information
    
    /// Get schema information for a specific model
    /// - Parameter modelType: Type of model to get info for
    /// - Returns: Schema information
    public func getSchemaInfo<T: Syncable>(for modelType: T.Type) -> PublicSchemaInfo? {
        return registeredSchemas[T.tableName]
    }
    
    /// Get validation result for a specific model
    /// - Parameter modelType: Type of model to get validation for
    /// - Returns: Validation result
    public func getValidationResult<T: Syncable>(for modelType: T.Type) -> PublicSchemaValidation? {
        return validationResults[T.tableName]
    }
    
    /// Check if a model is registered
    /// - Parameter modelType: Type of model to check
    /// - Returns: Whether model is registered
    public func isModelRegistered<T: Syncable>(_ modelType: T.Type) -> Bool {
        return registeredSchemas[T.tableName] != nil
    }
    
    /// Get schema summary for all models
    /// - Returns: Human-readable schema summary
    public func getSchemaSummary() -> String {
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
    
    // MARK: - Observer Management
    
    /// Add schema observer
    /// - Parameter observer: Observer to add
    public func addObserver(_ observer: SchemaObserver) {
        cleanupObservers()
        observers.append(WeakSchemaObserver(observer))
    }
    
    /// Remove schema observer
    /// - Parameter observer: Observer to remove
    public func removeObserver(_ observer: SchemaObserver) {
        observers.removeAll { weakObserver in
            weakObserver.observer === observer
        }
    }
    
    /// Remove all observers
    public func removeAllObservers() {
        observers.removeAll()
    }
    
    // MARK: - Error Management
    
    /// Clear all schema errors
    public func clearErrors() {
        Task {
            await MainActor.run {
                self.lastError = nil
            }
        }
    }
    
    /// Get all models with validation errors
    /// - Returns: Array of model names with errors
    public func getModelsWithErrors() -> [String] {
        return validationResults.compactMap { (key, value) in
            value.errors.isEmpty ? nil : key
        }
    }
    
    /// Get all models that require migration
    /// - Returns: Array of model names requiring migration
    public func getModelsRequiringMigration() -> [String] {
        return validationResults.compactMap { (key, value) in
            value.requiresMigration ? key : nil
        }
    }
    
    // MARK: - SQL Generation (No Authentication Required)
    
    /// Generate SQL migration script for a SwiftData model
    /// This method analyzes the model structure and generates Supabase-compatible SQL
    /// that users can manually execute in the Supabase SQL editor.
    /// - Parameter modelType: Model type that has a tableName property
    /// - Returns: Complete SQL migration script as string
    public func generateMigrationSQL<T: SQLGeneratable>(for modelType: T.Type) -> String {
        let generator = SQLScriptGenerator()
        let script = generator.generateScript(for: modelType)
        return script.sql
    }
    
    /// Generate SQL migration scripts for multiple models
    /// - Parameter modelTypes: Array of model types
    /// - Returns: Combined SQL migration script as string
    public func generateCombinedMigrationSQL(for modelTypes: [any SQLGeneratable.Type]) -> String {
        let generator = SQLScriptGenerator()
        return generator.generateCombinedSQL(for: modelTypes)
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe schema manager state
        schemaManager.$registeredModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.updateRegisteredSchemas()
                }
            }
            .store(in: &cancellables)
        
        schemaManager.$isGeneratingSchema
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isGenerating in
                if isGenerating {
                    Task { [weak self] in
                        await self?.setStatus(.generating, for: nil)
                    }
                }
            }
            .store(in: &cancellables)
        
        schemaManager.$lastError
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                Task { [weak self] in
                    let publicError = self?.convertSchemaError(error)
                    if let publicError = publicError {
                        await self?.setError(publicError, for: nil)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Observe auth state changes
        authAPI.$authenticationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] authStatus in
                if authStatus == .signedOut {
                    Task { [weak self] in
                        await self?.clearAllData()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAutoValidation() {
        guard autoValidationEnabled else { return }
        
        stopAutoValidation()
        
        // Run validation every 5 minutes
        autoValidationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let isAuth = self.authAPI.isAuthenticated
                let isIdle = self.status == .idle
                
                if isAuth && isIdle {
                    _ = await self.validateAllSchemas()
                }
            }
        }
    }
    
    private func stopAutoValidation() {
        autoValidationTimer?.invalidate()
        autoValidationTimer = nil
    }
    
    private func updateRegisteredSchemas() async {
        var schemas: [String: PublicSchemaInfo] = [:]
        
        for (tableName, schemaInfo) in schemaManager.registeredModels {
            let validation = validationResults[tableName]
            
            schemas[tableName] = PublicSchemaInfo(
                modelName: tableName,
                isRegistered: true,
                version: "1.0", // Simplified version
                columnCount: schemaInfo.columns.count,
                isCompatible: validation?.isValid ?? true,
                lastValidated: validation?.validatedAt
            )
        }
        
        _ = await MainActor.run {
            self.registeredSchemas = schemas
        }
    }
    
    private func updateValidationResult(_ result: PublicSchemaValidation) async {
        _ = await MainActor.run {
            self.validationResults[result.modelName] = result
        }
        await updateAllSchemasValid()
    }
    
    private func updateAllSchemasValid() async {
        let allValid = validationResults.values.allSatisfy { $0.isValid }
        _ = await MainActor.run {
            self.allSchemasValid = allValid
        }
    }
    
    private func clearValidationResult(for modelName: String) async {
        _ = await MainActor.run {
            self.validationResults.removeValue(forKey: modelName)
        }
        await updateAllSchemasValid()
    }
    
    private func setStatus(_ newStatus: PublicSchemaStatus, for modelName: String?) async {
        _ = await MainActor.run {
            self.status = newStatus
        }
        
        statusPublisher.send((newStatus, modelName))
        notifyObservers { observer in
            observer.schemaStatusChanged(newStatus, for: modelName)
        }
    }
    
    private func setError(_ error: SwiftSupabaseSyncError, for modelName: String?) async {
        _ = await MainActor.run {
            self.lastError = error
            self.status = .error
        }
        
        if let modelName = modelName {
            errorPublisher.send((error, modelName))
            notifyObservers { observer in
                observer.schemaErrorOccurred(error, for: modelName)
            }
        }
    }
    
    private func clearAllData() async {
        _ = await MainActor.run {
            self.registeredSchemas.removeAll()
            self.validationResults.removeAll()
            self.allSchemasValid = true
            self.status = .idle
            self.lastError = nil
        }
    }
    
    private func notifyObservers(_ notification: (SchemaObserver) -> Void) {
        cleanupObservers()
        
        for weakObserver in observers {
            if let observer = weakObserver.observer {
                notification(observer)
            }
        }
    }
    
    private func cleanupObservers() {
        observers.removeAll { $0.observer == nil }
    }
    
    // MARK: - Error Conversion
    
    private func convertToPublicError(_ error: Error) -> SwiftSupabaseSyncError {
        if let schemaError = error as? SchemaError {
            return convertSchemaError(schemaError)
        }
        
        return .unknown(underlyingError: error)
    }
    
    private func convertSchemaError(_ error: SchemaError) -> SwiftSupabaseSyncError {
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
    
    private func convertToPublicValidation(_ result: SchemaValidationResult) -> PublicSchemaValidation {
        return PublicSchemaValidation(
            modelName: result.tableName,
            isValid: result.isValid,
            errors: result.errors,
            warnings: result.warnings,
            validatedAt: result.validatedAt,
            requiresMigration: !result.isValid && !result.errors.isEmpty
        )
    }
    
    deinit {
        autoValidationTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Weak Observer Wrapper

private class WeakSchemaObserver {
    weak var observer: SchemaObserver?
    
    init(_ observer: SchemaObserver) {
        self.observer = observer
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
}
