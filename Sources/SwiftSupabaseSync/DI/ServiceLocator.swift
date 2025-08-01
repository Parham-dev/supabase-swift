//
//  ServiceLocator.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// Note: DICore types are imported implicitly as they're in the same module

/// Global service locator providing centralized access to services
/// Acts as a façade over the DIContainer for simplified service resolution
public final class ServiceLocator {
    
    // MARK: - Singleton
    
    /// Shared instance of the service locator
    public static let shared = ServiceLocator()
    
    // MARK: - Properties
    
    /// Underlying dependency injection container
    private var container: DIContainer?
    
    /// Thread safety lock
    private let lock = NSLock()
    
    /// Default scope for scoped services
    private var defaultScope: DIScope?
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Container Management
    
    /// Configure the service locator with a dependency injection container
    /// - Parameter container: DIContainer to use for service resolution
    public func configure(with container: DIContainer) {
        lock.lock()
        defer { lock.unlock() }
        
        self.container = container
        self.defaultScope = container.createScope(id: "default")
    }
    
    /// Check if the service locator is configured
    /// - Returns: True if configured with a container, false otherwise
    public var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return container != nil
    }
    
    // MARK: - Service Resolution
    
    /// Resolve a service from the container
    /// - Parameter type: Service type to resolve
    /// - Returns: Service instance
    /// - Throws: DIError if service cannot be resolved or container not configured
    public func resolve<T>(_ type: T.Type) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        
        guard let container = container else {
            throw DIError.serviceNotRegistered("ServiceLocator not configured")
        }
        
        return try container.resolve(type)
    }
    
    /// Resolve a service with the default scope
    /// - Parameter type: Service type to resolve
    /// - Returns: Service instance
    /// - Throws: DIError if service cannot be resolved
    public func resolveScoped<T>(_ type: T.Type) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        
        guard let container = container else {
            throw DIError.serviceNotRegistered("ServiceLocator not configured")
        }
        
        return try container.resolve(type, scopeId: defaultScope?.id)
    }
    
    /// Resolve an optional service (returns nil if not registered)
    /// - Parameter type: Service type to resolve
    /// - Returns: Service instance or nil
    public func resolveOptional<T>(_ type: T.Type) -> T? {
        return try? resolve(type)
    }
    
    /// Resolve an optional scoped service
    /// - Parameter type: Service type to resolve
    /// - Returns: Service instance or nil
    public func resolveScopedOptional<T>(_ type: T.Type) -> T? {
        return try? resolveScoped(type)
    }
    
    // MARK: - Convenience Methods
    
    /// Get the underlying container (for advanced operations)
    /// - Returns: DIContainer if configured, nil otherwise
    public func getContainer() -> DIContainer? {
        lock.lock()
        defer { lock.unlock() }
        
        return container
    }
    
    /// Check if a service is registered
    /// - Parameter type: Service type to check
    /// - Returns: True if registered, false otherwise
    public func isRegistered<T>(_ type: T.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        return container?.isRegistered(type) ?? false
    }
    
    /// Create a new scope
    /// - Parameter id: Optional scope identifier
    /// - Returns: Created scope
    /// - Throws: DIError if container not configured
    public func createScope(id: String? = nil) throws -> DIScope {
        lock.lock()
        defer { lock.unlock() }
        
        guard let container = container else {
            throw DIError.serviceNotRegistered("ServiceLocator not configured")
        }
        
        return container.createScope(id: id)
    }
    
    /// Reset the default scope (clears all scoped instances)
    public func resetDefaultScope() {
        lock.lock()
        defer { lock.unlock() }
        
        defaultScope?.clear()
        if let container = container {
            defaultScope = container.createScope(id: "default")
        }
    }
    
    /// Clear the service locator and reset container
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        container?.clear()
        container = nil
        defaultScope = nil
    }
}

// MARK: - Global Convenience Functions

/// Global function to resolve a service
/// - Parameter type: Service type to resolve
/// - Returns: Service instance
/// - Throws: DIError if service cannot be resolved
public func resolve<T>(_ type: T.Type) throws -> T {
    return try ServiceLocator.shared.resolve(type)
}

/// Global function to resolve an optional service
/// - Parameter type: Service type to resolve
/// - Returns: Service instance or nil
public func resolveOptional<T>(_ type: T.Type) -> T? {
    return ServiceLocator.shared.resolveOptional(type)
}

/// Global function to check if a service is registered
/// - Parameter type: Service type to check
/// - Returns: True if registered, false otherwise
public func isRegistered<T>(_ type: T.Type) -> Bool {
    return ServiceLocator.shared.isRegistered(type)
}

// MARK: - Property Wrapper for Dependency Injection

/// Property wrapper for automatic dependency injection
@propertyWrapper
public struct Inject<T> {
    private var service: T?
    
    public var wrappedValue: T {
        mutating get {
            if service == nil {
                service = try? ServiceLocator.shared.resolve(T.self)
            }
            return service!
        }
    }
    
    public init() {}
}

/// Property wrapper for optional dependency injection
@propertyWrapper
public struct InjectOptional<T> {
    private var service: T?
    private var isResolved = false
    
    public var wrappedValue: T? {
        mutating get {
            if !isResolved {
                service = ServiceLocator.shared.resolveOptional(T.self)
                isResolved = true
            }
            return service
        }
    }
    
    public init() {}
}

/// Property wrapper for scoped dependency injection
@propertyWrapper
public struct InjectScoped<T> {
    private var service: T?
    
    public var wrappedValue: T {
        mutating get {
            if service == nil {
                service = try? ServiceLocator.shared.resolveScoped(T.self)
            }
            return service!
        }
    }
    
    public init() {}
}