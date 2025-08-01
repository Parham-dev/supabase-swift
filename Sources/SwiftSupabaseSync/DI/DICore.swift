//
//  DICore.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Service Lifetime

/// Defines the lifetime management strategy for services in the DI container
public enum ServiceLifetime {
    /// Service is created once and shared across all requests
    case singleton
    
    /// Service is created once per scope/session and shared within that scope
    case scoped
    
    /// Service is created fresh for each request
    case transient
}

// MARK: - Service Registration

/// Protocol for service registration information
public protocol ServiceRegistration {
    /// The service type being registered
    var serviceType: Any.Type { get }
    
    /// The implementation type for the service
    var implementationType: Any.Type { get }
    
    /// The lifetime management strategy
    var lifetime: ServiceLifetime { get }
    
    /// Factory function to create the service instance
    var factory: (DIContainer) throws -> Any { get }
}

/// Concrete implementation of service registration
public struct ServiceRegistrationImpl<ServiceType, ImplementationType>: ServiceRegistration {
    public let serviceType: Any.Type
    public let implementationType: Any.Type
    public let lifetime: ServiceLifetime
    public let factory: (DIContainer) throws -> Any
    
    public init(
        serviceType: ServiceType.Type,
        implementationType: ImplementationType.Type,
        lifetime: ServiceLifetime,
        factory: @escaping (DIContainer) throws -> ImplementationType
    ) {
        self.serviceType = serviceType
        self.implementationType = implementationType
        self.lifetime = lifetime
        self.factory = { container in
            try factory(container)
        }
    }
}

// MARK: - DI Errors

/// Errors that can occur during dependency injection operations
public enum DIError: Error, LocalizedError {
    case serviceNotRegistered(String)
    case circularDependency(String)
    case instantiationFailed(String, Error)
    case invalidServiceType(String)
    case scopeNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .serviceNotRegistered(let service):
            return "Service not registered: \(service)"
        case .circularDependency(let service):
            return "Circular dependency detected for service: \(service)"
        case .instantiationFailed(let service, let error):
            return "Failed to instantiate service \(service): \(error.localizedDescription)"
        case .invalidServiceType(let service):
            return "Invalid service type: \(service)"
        case .scopeNotFound(let scope):
            return "Scope not found: \(scope)"
        }
    }
}

// MARK: - DI Scope

/// Protocol for dependency injection scopes
public protocol DIScope {
    /// Unique identifier for the scope
    var id: String { get }
    
    /// Get service instance from scope
    func getInstance<T>(for type: T.Type) -> T?
    
    /// Store service instance in scope
    func setInstance<T>(_ instance: T, for type: T.Type)
    
    /// Clear all instances in scope
    func clear()
}

/// Implementation of dependency injection scope
public final class DIScopeImpl: DIScope {
    public let id: String
    private var instances: [String: Any] = [:]
    private let lock = NSLock()
    
    public init(id: String = UUID().uuidString) {
        self.id = id
    }
    
    public func getInstance<T>(for type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        return instances[key] as? T
    }
    
    public func setInstance<T>(_ instance: T, for type: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        instances[key] = instance
    }
    
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        instances.removeAll()
    }
}

// Note: SyncLoggerProtocol is defined in Core/Domain/Protocols/AuthRepositoryProtocol.swift

// MARK: - DIContainer

/// Main dependency injection container for managing service registration and resolution
/// Supports singleton, scoped, and transient service lifetimes with thread-safe operations
public final class DIContainer {
    
    // MARK: - Properties
    
    /// Registered services
    private var registrations: [String: ServiceRegistration] = [:]
    
    /// Singleton instances cache
    private var singletonInstances: [String: Any] = [:]
    
    /// Active scopes
    private var scopes: [String: DIScope] = [:]
    
    /// Currently resolving services (for circular dependency detection)
    private var resolutionStack: Set<String> = []
    
    /// Thread safety lock
    private let lock = NSRecursiveLock()
    
    /// Optional logger for debugging
    private var logger: SyncLoggerProtocol?
    
    // MARK: - Initialization
    
    public init(logger: SyncLoggerProtocol? = nil) {
        self.logger = logger
        logger?.debug("DIContainer: Initialized")
    }
    
    // MARK: - Service Registration
    
    /// Register a service with the container
    /// - Parameters:
    ///   - serviceType: Protocol or base type to register
    ///   - implementationType: Concrete implementation type
    ///   - lifetime: Service lifetime management strategy
    ///   - factory: Factory function to create the service
    public func register<ServiceType, ImplementationType>(
        _ serviceType: ServiceType.Type,
        as implementationType: ImplementationType.Type,
        lifetime: ServiceLifetime = .transient,
        factory: @escaping (DIContainer) throws -> ImplementationType
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: serviceType)
        let registration = ServiceRegistrationImpl(
            serviceType: serviceType,
            implementationType: implementationType,
            lifetime: lifetime,
            factory: factory
        )
        
        registrations[key] = registration
        logger?.debug("DIContainer: Registered \(key) with lifetime \(lifetime)")
    }
    
    /// Register a service using the same type for both protocol and implementation
    /// - Parameters:
    ///   - type: Service type
    ///   - lifetime: Service lifetime management strategy
    ///   - factory: Factory function to create the service
    public func register<T>(
        _ type: T.Type,
        lifetime: ServiceLifetime = .transient,
        factory: @escaping (DIContainer) throws -> T
    ) {
        register(type, as: type, lifetime: lifetime, factory: factory)
    }
    
    /// Register a singleton instance directly
    /// - Parameters:
    ///   - serviceType: Service type to register
    ///   - instance: Pre-created instance to register
    public func registerSingleton<T>(_ serviceType: T.Type, instance: T) {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: serviceType)
        singletonInstances[key] = instance
        
        // Also register a factory that returns this instance
        register(serviceType, lifetime: .singleton) { _ in instance }
        
        logger?.debug("DIContainer: Registered singleton instance for \(key)")
    }
    
    // MARK: - Service Resolution
    
    /// Resolve a service from the container
    /// - Parameter type: Service type to resolve
    /// - Returns: Service instance
    /// - Throws: DIError if service cannot be resolved
    public func resolve<T>(_ type: T.Type) throws -> T {
        return try resolve(type, scopeId: nil)
    }
    
    /// Resolve a service with a specific scope
    /// - Parameters:
    ///   - type: Service type to resolve
    ///   - scopeId: Optional scope identifier
    /// - Returns: Service instance
    /// - Throws: DIError if service cannot be resolved
    public func resolve<T>(_ type: T.Type, scopeId: String?) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        
        // Check for circular dependency
        guard !resolutionStack.contains(key) else {
            throw DIError.circularDependency(key)
        }
        
        // Find registration
        guard let registration = registrations[key] else {
            throw DIError.serviceNotRegistered(key)
        }
        
        // Handle different lifetimes
        switch registration.lifetime {
        case .singleton:
            return try resolveSingleton(type, key: key, registration: registration)
            
        case .scoped:
            return try resolveScoped(type, key: key, registration: registration, scopeId: scopeId)
            
        case .transient:
            return try resolveTransient(type, key: key, registration: registration)
        }
    }
    
    /// Resolve an optional service (returns nil if not registered)
    /// - Parameter type: Service type to resolve
    /// - Returns: Service instance or nil
    public func resolveOptional<T>(_ type: T.Type) -> T? {
        return try? resolve(type)
    }
    
    // MARK: - Scope Management
    
    /// Create a new scope
    /// - Parameter id: Optional scope identifier
    /// - Returns: Created scope
    public func createScope(id: String? = nil) -> DIScope {
        lock.lock()
        defer { lock.unlock() }
        
        let scope = DIScopeImpl(id: id ?? UUID().uuidString)
        scopes[scope.id] = scope
        
        logger?.debug("DIContainer: Created scope \(scope.id)")
        return scope
    }
    
    /// Get existing scope by ID
    /// - Parameter id: Scope identifier
    /// - Returns: Scope if exists, nil otherwise
    public func getScope(id: String) -> DIScope? {
        lock.lock()
        defer { lock.unlock() }
        
        return scopes[id]
    }
    
    /// Remove scope and clear its instances
    /// - Parameter id: Scope identifier
    public func removeScope(id: String) {
        lock.lock()
        defer { lock.unlock() }
        
        scopes[id]?.clear()
        scopes.removeValue(forKey: id)
        
        logger?.debug("DIContainer: Removed scope \(id)")
    }
    
    // MARK: - Container Management
    
    /// Check if a service is registered
    /// - Parameter type: Service type to check
    /// - Returns: True if registered, false otherwise
    public func isRegistered<T>(_ type: T.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let key = String(describing: type)
        return registrations[key] != nil
    }
    
    /// Get all registered service types
    /// - Returns: Array of registered service type names
    public func getRegisteredServices() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(registrations.keys)
    }
    
    /// Clear all registrations and instances
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        registrations.removeAll()
        singletonInstances.removeAll()
        
        // Clear all scopes
        for scope in scopes.values {
            scope.clear()
        }
        scopes.removeAll()
        
        logger?.debug("DIContainer: Cleared all registrations and instances")
    }
    
    // MARK: - Private Methods
    
    private func resolveSingleton<T>(_ type: T.Type, key: String, registration: ServiceRegistration) throws -> T {
        // Check if instance already exists
        if let instance = singletonInstances[key] as? T {
            return instance
        }
        
        // Create new instance
        let instance = try createInstance(type, key: key, registration: registration)
        singletonInstances[key] = instance
        
        return instance
    }
    
    private func resolveScoped<T>(_ type: T.Type, key: String, registration: ServiceRegistration, scopeId: String?) throws -> T {
        // Determine scope to use
        let scope: DIScope
        if let scopeId = scopeId, let existingScope = scopes[scopeId] {
            scope = existingScope
        } else {
            // Create default scope if none specified
            scope = createScope()
        }
        
        // Check if instance exists in scope
        if let instance = scope.getInstance(for: type) {
            return instance
        }
        
        // Create new instance and store in scope
        let instance = try createInstance(type, key: key, registration: registration)
        scope.setInstance(instance, for: type)
        
        return instance
    }
    
    private func resolveTransient<T>(_ type: T.Type, key: String, registration: ServiceRegistration) throws -> T {
        return try createInstance(type, key: key, registration: registration)
    }
    
    private func createInstance<T>(_ type: T.Type, key: String, registration: ServiceRegistration) throws -> T {
        // Add to resolution stack
        resolutionStack.insert(key)
        defer { resolutionStack.remove(key) }
        
        do {
            let instance = try registration.factory(self)
            
            guard let typedInstance = instance as? T else {
                throw DIError.invalidServiceType("Factory returned wrong type for \(key)")
            }
            
            logger?.debug("DIContainer: Created instance of \(key)")
            return typedInstance
            
        } catch {
            logger?.error("DIContainer: Failed to create instance of \(key): \(error)")
            throw DIError.instantiationFailed(key, error)
        }
    }
}

// MARK: - Convenience Extensions

public extension DIContainer {
    /// Register multiple services using a configuration block
    /// - Parameter configure: Configuration block
    func configure(_ configure: (DIContainer) -> Void) {
        configure(self)
    }
    
    /// Register a service with dependencies resolved automatically
    /// - Parameters:
    ///   - serviceType: Service type to register
    ///   - lifetime: Service lifetime
    ///   - factory: Factory function that receives resolved dependencies
    func registerWithDependencies<T, D1>(
        _ serviceType: T.Type,
        lifetime: ServiceLifetime = .transient,
        factory: @escaping (D1) throws -> T
    ) {
        register(serviceType, lifetime: lifetime) { container in
            let dep1 = try container.resolve(D1.self)
            return try factory(dep1)
        }
    }
    
    /// Register a service with two dependencies
    func registerWithDependencies<T, D1, D2>(
        _ serviceType: T.Type,
        lifetime: ServiceLifetime = .transient,
        factory: @escaping (D1, D2) throws -> T
    ) {
        register(serviceType, lifetime: lifetime) { container in
            let dep1 = try container.resolve(D1.self)
            let dep2 = try container.resolve(D2.self)
            return try factory(dep1, dep2)
        }
    }
    
    /// Register a service with three dependencies
    func registerWithDependencies<T, D1, D2, D3>(
        _ serviceType: T.Type,
        lifetime: ServiceLifetime = .transient,
        factory: @escaping (D1, D2, D3) throws -> T
    ) {
        register(serviceType, lifetime: lifetime) { container in
            let dep1 = try container.resolve(D1.self)
            let dep2 = try container.resolve(D2.self)
            let dep3 = try container.resolve(D3.self)
            return try factory(dep1, dep2, dep3)
        }
    }
}