//
//  ModelRegistryService.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Combine
import SwiftData

/// Centralized service for managing Syncable model registration across all managers
/// Provides single source of truth for model types, schema information, and lifecycle management
@MainActor
public final class ModelRegistryService: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared model registry service instance
    public static let shared = ModelRegistryService()
    
    // MARK: - Published Properties
    
    /// All registered models with their metadata
    @Published public private(set) var registeredModels: [String: ModelRegistration] = [:]
    
    /// Count of registered models
    @Published public private(set) var modelCount: Int = 0
    
    /// Last registration error
    @Published public private(set) var lastError: ModelRegistryError?
    
    /// Whether model discovery is in progress
    @Published public private(set) var isDiscovering: Bool = false
    
    // MARK: - Private Properties
    
    private let coordinationHub: CoordinationHub
    private let lock = NSRecursiveLock()
    private var cancellables = Set<AnyCancellable>()
    private var modelObservers: [String: Set<WeakObserver>] = [:]
    
    // MARK: - Initialization
    
    private init(coordinationHub: CoordinationHub = .shared) {
        self.coordinationHub = coordinationHub
        setupCoordination()
    }
    
    // MARK: - Model Registration
    
    /// Register a Syncable model type
    /// - Parameter modelType: The model type to register
    /// - Returns: Registration result with metadata
    @discardableResult
    public func registerModel<T: Syncable>(_ modelType: T.Type) throws -> ModelRegistration {
        lock.lock()
        defer { lock.unlock() }
        
        let tableName = T.tableName
        
        // Check if already registered
        if let existing = registeredModels[tableName] {
            return existing
        }
        
        // Create registration
        let registration = try createRegistration(for: modelType)
        
        // Store registration
        registeredModels[tableName] = registration
        modelCount = registeredModels.count
        
        // Notify coordination hub
        Task {
            coordinationHub.publish(CoordinationEvent(
                type: .modelRegistered,
                data: [
                    "tableName": tableName,
                    "modelType": String(describing: modelType),
                    "registration": registration
                ]
            ))
        }
        
        // Notify observers
        notifyObservers(for: tableName, event: .registered(registration))
        
        return registration
    }
    
    /// Unregister a Syncable model type
    /// - Parameter modelType: The model type to unregister
    /// - Returns: True if model was unregistered, false if not found
    @discardableResult
    public func unregisterModel<T: Syncable>(_ modelType: T.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let tableName = T.tableName
        
        guard let registration = registeredModels.removeValue(forKey: tableName) else {
            return false
        }
        
        modelCount = registeredModels.count
        
        // Clean up observers
        modelObservers.removeValue(forKey: tableName)
        
        // Notify coordination hub
        Task {
            coordinationHub.publish(CoordinationEvent(
                type: .modelUnregistered,
                data: [
                    "tableName": tableName,
                    "modelType": String(describing: modelType),
                    "registration": registration
                ]
            ))
        }
        
        // Notify observers
        notifyObservers(for: tableName, event: .unregistered(registration))
        
        return true
    }
    
    /// Bulk register multiple model types
    /// - Parameter modelTypes: Array of model types to register
    /// - Returns: Dictionary of registration results
    public func registerModels(_ modelTypes: [any Syncable.Type]) -> [String: Result<ModelRegistration, ModelRegistryError>] {
        var results: [String: Result<ModelRegistration, ModelRegistryError>] = [:]
        
        for modelType in modelTypes {
            let tableName = modelTypeToTableName(modelType)
            do {
                let registration = try registerModelType(modelType)
                results[tableName] = .success(registration)
            } catch let error as ModelRegistryError {
                results[tableName] = .failure(error)
            } catch {
                results[tableName] = .failure(.registrationFailed(tableName, error))
            }
        }
        
        return results
    }
    
    // MARK: - Model Discovery
    
    /// Discover and register all Syncable models from a SwiftData container
    /// - Parameter container: SwiftData model container to scan
    /// - Returns: Number of models discovered and registered
    public func discoverModels(from container: ModelContainer) async -> Int {
        await setDiscovering(true)
        defer { Task { await setDiscovering(false) } }
        
        var discoveredCount = 0
        
        // Get all model types from container
        let schema = container.schema
        
        // SwiftData Schema structure may vary, using simplified approach
        // For now, skip automatic discovery and just return 0
        // Real implementation would inspect schema properly
        
        // Placeholder loop - would iterate over actual models
        let modelNames = ["PlaceholderModel"] // Would get from schema inspection
        
        for modelName in modelNames where false { // Skip execution for now
            // Check if model conforms to Syncable
            // Note: This is a simplified check - real implementation would use runtime introspection
            let modelName = modelName // Use the modelName from the loop
            
            do {
                // Try to register discovered model
                // This is a placeholder - real implementation would need proper type resolution
                let tableName = modelName.lowercased()
                
                if registeredModels[tableName] == nil {
                    // Create a generic registration for discovered model
                    let registration = ModelRegistration(
                        tableName: tableName,
                        modelTypeName: modelName,
                        syncableProperties: [], // Would be discovered from schema
                        registeredAt: Date(),
                        registeredBy: .discovery
                    )
                    
                    registeredModels[tableName] = registration
                    discoveredCount += 1
                }
            } catch {
                await setError(.discoveryFailed(modelName, error))
            }
        }
        
        await MainActor.run {
            self.modelCount = self.registeredModels.count
        }
        
        return discoveredCount
    }
    
    // MARK: - Model Queries
    
    /// Get registration for a specific model type
    /// - Parameter modelType: Model type to query
    /// - Returns: Registration if found
    public func getRegistration<T: Syncable>(for modelType: T.Type) -> ModelRegistration? {
        lock.lock()
        defer { lock.unlock() }
        
        return registeredModels[T.tableName]
    }
    
    /// Get registration by table name
    /// - Parameter tableName: Table name to query
    /// - Returns: Registration if found
    public func getRegistration(for tableName: String) -> ModelRegistration? {
        lock.lock()
        defer { lock.unlock() }
        
        return registeredModels[tableName]
    }
    
    /// Check if a model type is registered
    /// - Parameter modelType: Model type to check
    /// - Returns: True if registered
    public func isRegistered<T: Syncable>(_ modelType: T.Type) -> Bool {
        return getRegistration(for: modelType) != nil
    }
    
    /// Get all registered table names
    /// - Returns: Set of all registered table names
    public var allTableNames: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        
        return Set(registeredModels.keys)
    }
    
    /// Get all registered model type names
    /// - Returns: Set of all registered model type names
    public var allModelTypeNames: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        
        return Set(registeredModels.values.map { $0.modelTypeName })
    }
    
    /// Get registrations filtered by registration source
    /// - Parameter source: Registration source to filter by
    /// - Returns: Filtered registrations
    public func getRegistrations(registeredBy source: RegistrationSource) -> [ModelRegistration] {
        lock.lock()
        defer { lock.unlock() }
        
        return registeredModels.values.filter { $0.registeredBy == source }
    }
    
    // MARK: - Model Validation
    
    /// Validate that all registered models have compatible schemas
    /// - Returns: Validation results for each model
    public func validateAllModels() -> [String: ValidationResult] {
        lock.lock()
        defer { lock.unlock() }
        
        var results: [String: ValidationResult] = [:]
        
        for (tableName, registration) in registeredModels {
            results[tableName] = validateRegistration(registration)
        }
        
        return results
    }
    
    /// Validate dependencies between registered models
    /// - Returns: Dependency validation results
    public func validateModelDependencies() -> DependencyValidationResult {
        lock.lock()
        defer { lock.unlock() }
        
        // Check for circular dependencies and missing dependencies
        var missingDependencies: [String: Set<String>] = [:]
        let circularDependencies: [(String, String)] = []
        
        // Simplified dependency checking
        for (tableName, registration) in registeredModels {
            // Check if all referenced models are registered
            let dependencies = extractDependencies(from: registration)
            let missing = dependencies.subtracting(allTableNames)
            
            if !missing.isEmpty {
                missingDependencies[tableName] = missing
            }
        }
        
        return DependencyValidationResult(
            isValid: missingDependencies.isEmpty && circularDependencies.isEmpty,
            missingDependencies: missingDependencies,
            circularDependencies: circularDependencies
        )
    }
    
    // MARK: - Observation
    
    /// Add observer for model registration changes
    /// - Parameters:
    ///   - tableName: Table name to observe (nil for all models)
    ///   - observer: Observer to add
    public func addObserver(for tableName: String?, observer: ModelRegistryObserver) {
        let targetTableName = tableName ?? "*"
        
        if modelObservers[targetTableName] == nil {
            modelObservers[targetTableName] = []
        }
        
        modelObservers[targetTableName]?.insert(WeakObserver(observer))
    }
    
    /// Remove observer
    /// - Parameters:
    ///   - tableName: Table name being observed
    ///   - observer: Observer to remove
    public func removeObserver(for tableName: String?, observer: ModelRegistryObserver) {
        let targetTableName = tableName ?? "*"
        
        if var observers = modelObservers[targetTableName] {
            observers = observers.filter { weakObserver in
                weakObserver.observer !== observer
            }
            modelObservers[targetTableName] = observers
        }
    }
    
    // MARK: - Private Implementation
    
    private func createRegistration<T: Syncable>(for modelType: T.Type) throws -> ModelRegistration {
        let tableName = T.tableName
        let syncableProperties = T.syncableProperties
        
        // Validate model type
        guard !tableName.isEmpty else {
            throw ModelRegistryError.invalidTableName(tableName)
        }
        
        guard !syncableProperties.isEmpty else {
            throw ModelRegistryError.noSyncableProperties(tableName)
        }
        
        return ModelRegistration(
            tableName: tableName,
            modelTypeName: String(describing: modelType),
            syncableProperties: syncableProperties,
            registeredAt: Date(),
            registeredBy: .explicit
        )
    }
    
    private func registerModelType(_ modelType: any Syncable.Type) throws -> ModelRegistration {
        let tableName = modelTypeToTableName(modelType)
        let syncableProperties = modelTypeToSyncableProperties(modelType)
        
        if registeredModels[tableName] != nil {
            return registeredModels[tableName]!
        }
        
        let registration = ModelRegistration(
            tableName: tableName,
            modelTypeName: String(describing: modelType),
            syncableProperties: syncableProperties,
            registeredAt: Date(),
            registeredBy: .explicit
        )
        
        registeredModels[tableName] = registration
        modelCount = registeredModels.count
        
        return registration
    }
    
    private func modelTypeToTableName(_ modelType: any Syncable.Type) -> String {
        // This is a simplified implementation
        // Real implementation would need proper reflection
        return String(describing: modelType).lowercased()
    }
    
    private func modelTypeToSyncableProperties(_ modelType: any Syncable.Type) -> [String] {
        // This is a simplified implementation
        // Real implementation would use runtime introspection
        return []
    }
    
    private func validateRegistration(_ registration: ModelRegistration) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Basic validation
        if registration.tableName.isEmpty {
            errors.append("Empty table name")
        }
        
        if registration.syncableProperties.isEmpty {
            warnings.append("No syncable properties defined")
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func extractDependencies(from registration: ModelRegistration) -> Set<String> {
        // Simplified dependency extraction
        // Real implementation would analyze property types for relationships
        return []
    }
    
    private func setupCoordination() {
        // Listen for coordination events that might affect model registry
        coordinationHub.eventPublisher
            .sink { [weak self] event in
                Task { [weak self] in
                    await self?.handleCoordinationEvent(event)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleCoordinationEvent(_ event: CoordinationEvent) async {
        switch event.type {
        case .authStateChanged:
            // Auth state might affect model availability
            break
        case .schemaChanged:
            // Schema changes might require model revalidation
            _ = validateAllModels()
        default:
            break
        }
    }
    
    private func notifyObservers(for tableName: String, event: ModelRegistryEvent) {
        // Notify specific table observers
        if let observers = modelObservers[tableName] {
            for weakObserver in observers {
                weakObserver.observer?.modelRegistryDidChange(event)
            }
        }
        
        // Notify global observers
        if let observers = modelObservers["*"] {
            for weakObserver in observers {
                weakObserver.observer?.modelRegistryDidChange(event)
            }
        }
        
        // Clean up nil observers
        cleanupObservers()
    }
    
    private func cleanupObservers() {
        for (tableName, observers) in modelObservers {
            let activeObservers = observers.filter { $0.observer != nil }
            if activeObservers.count != observers.count {
                modelObservers[tableName] = Set(activeObservers)
            }
        }
    }
    
    private func setError(_ error: ModelRegistryError) async {
        await MainActor.run {
            self.lastError = error
        }
    }
    
    private func setDiscovering(_ discovering: Bool) async {
        await MainActor.run {
            self.isDiscovering = discovering
        }
    }
    
    // MARK: - Cleanup
    
    /// Clear all registered models
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        registeredModels.removeAll()
        modelCount = 0
        modelObservers.removeAll()
        lastError = nil
    }
    
    /// Clear errors
    public func clearErrors() {
        Task {
            await MainActor.run {
                self.lastError = nil
            }
        }
    }
}

// MARK: - Supporting Types

/// Model registration information
public struct ModelRegistration: Identifiable, Equatable {
    public let id: UUID
    public let tableName: String
    public let modelTypeName: String
    public let syncableProperties: [String]
    public let registeredAt: Date
    public let registeredBy: RegistrationSource
    
    public init(
        id: UUID = UUID(),
        tableName: String,
        modelTypeName: String,
        syncableProperties: [String],
        registeredAt: Date,
        registeredBy: RegistrationSource
    ) {
        self.id = id
        self.tableName = tableName
        self.modelTypeName = modelTypeName
        self.syncableProperties = syncableProperties
        self.registeredAt = registeredAt
        self.registeredBy = registeredBy
    }
}

/// Source of model registration
public enum RegistrationSource: String, CaseIterable {
    case explicit = "explicit"          // Manually registered
    case discovery = "discovery"        // Auto-discovered
    case migration = "migration"        // Registered during migration
}

/// Model registry events
public enum ModelRegistryEvent {
    case registered(ModelRegistration)
    case unregistered(ModelRegistration)
    case validationChanged(String, ValidationResult)
}

/// Observer protocol for model registry changes
public protocol ModelRegistryObserver: AnyObject {
    func modelRegistryDidChange(_ event: ModelRegistryEvent)
}

/// Weak reference wrapper for observers
private struct WeakObserver: Hashable {
    weak var observer: ModelRegistryObserver?
    private let id: ObjectIdentifier
    
    init(_ observer: ModelRegistryObserver) {
        self.observer = observer
        self.id = ObjectIdentifier(observer)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: WeakObserver, rhs: WeakObserver) -> Bool {
        lhs.id == rhs.id
    }
}

/// Validation result for model registration
public struct ValidationResult {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    
    public init(isValid: Bool, errors: [String], warnings: [String]) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

/// Dependency validation result
public struct DependencyValidationResult {
    public let isValid: Bool
    public let missingDependencies: [String: Set<String>]
    public let circularDependencies: [(String, String)]
    
    public init(
        isValid: Bool,
        missingDependencies: [String: Set<String>],
        circularDependencies: [(String, String)]
    ) {
        self.isValid = isValid
        self.missingDependencies = missingDependencies
        self.circularDependencies = circularDependencies
    }
}

/// Model registry errors
public enum ModelRegistryError: Error, LocalizedError {
    case invalidTableName(String)
    case noSyncableProperties(String)
    case registrationFailed(String, Error)
    case discoveryFailed(String, Error)
    case validationFailed(String, String)
    case dependencyNotFound(String, String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidTableName(let name):
            return "Invalid table name: \(name)"
        case .noSyncableProperties(let tableName):
            return "No syncable properties found for \(tableName)"
        case .registrationFailed(let tableName, let error):
            return "Registration failed for \(tableName): \(error.localizedDescription)"
        case .discoveryFailed(let modelName, let error):
            return "Discovery failed for \(modelName): \(error.localizedDescription)"
        case .validationFailed(let tableName, let reason):
            return "Validation failed for \(tableName): \(reason)"
        case .dependencyNotFound(let tableName, let dependency):
            return "Dependency \(dependency) not found for \(tableName)"
        }
    }
}