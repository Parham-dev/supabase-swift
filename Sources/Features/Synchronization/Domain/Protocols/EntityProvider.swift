//
//  EntityProvider.swift
//  SupabaseSwift
//
//  Created by Parham on 03/08/2025.
//

import Foundation
import SwiftData

/// Protocol for providing entities of any registered type for sync operations
/// This enables dynamic entity fetching without hardcoded type dependencies
public protocol EntityProvider {
    /// Get all entities of the registered type that need syncing
    /// - Returns: Array of entities that implement Syncable protocol
    func getEntitiesNeedingSync() async throws -> [any Syncable]
    
    /// Get entities by their sync IDs
    /// - Parameter syncIDs: Array of sync IDs to fetch
    /// - Returns: Array of entities matching the provided IDs
    func getEntitiesBySyncIDs(_ syncIDs: [String]) async throws -> [any Syncable]
    
    /// Get the table name this provider handles
    var tableName: String { get }
    
    /// Get the Swift type name this provider handles
    var entityTypeName: String { get }
}

/// Generic entity provider that can work with any Syncable type
/// This uses Swift's type system to provide compile-time safety while maintaining runtime flexibility
public class GenericEntityProvider<T: Syncable>: EntityProvider {
    
    private let entityFetcher: () async throws -> [T]
    private let entityByIDFetcher: ([String]) async throws -> [T]
    
    public let tableName: String
    public let entityTypeName: String
    
    /// Initialize with custom fetch closures
    /// - Parameters:
    ///   - tableName: The database table name
    ///   - entityTypeName: The Swift type name
    ///   - entityFetcher: Closure to fetch all entities needing sync
    ///   - entityByIDFetcher: Closure to fetch entities by sync IDs
    public init(
        tableName: String,
        entityTypeName: String,
        entityFetcher: @escaping () async throws -> [T],
        entityByIDFetcher: @escaping ([String]) async throws -> [T]
    ) {
        self.tableName = tableName
        self.entityTypeName = entityTypeName
        self.entityFetcher = entityFetcher
        self.entityByIDFetcher = entityByIDFetcher
    }
    
    public func getEntitiesNeedingSync() async throws -> [any Syncable] {
        let entities = try await entityFetcher()
        return entities.map { $0 as any Syncable }
    }
    
    public func getEntitiesBySyncIDs(_ syncIDs: [String]) async throws -> [any Syncable] {
        let entities = try await entityByIDFetcher(syncIDs)
        return entities.map { $0 as any Syncable }
    }
}

/// Entity provider registry for managing providers for different entity types
/// This allows dynamic registration and lookup of providers at runtime
public class EntityProviderRegistry {
    
    /// Shared instance
    public static let shared = EntityProviderRegistry()
    
    private var providers: [String: EntityProvider] = [:]
    private let lock = NSRecursiveLock()
    
    private init() {}
    
    /// Register an entity provider for a specific table
    /// - Parameters:
    ///   - provider: The entity provider implementation
    ///   - tableName: The table name to register for
    public func registerProvider(_ provider: EntityProvider, forTable tableName: String) {
        lock.lock()
        defer { lock.unlock() }
        
        providers[tableName] = provider
        print("📦 [EntityProviderRegistry] Registered provider for table '\(tableName)' (type: \(provider.entityTypeName))")
    }
    
    /// Get entity provider for a table
    /// - Parameter tableName: The table name to get provider for
    /// - Returns: Entity provider if registered, nil otherwise
    public func getProvider(forTable tableName: String) -> EntityProvider? {
        lock.lock()
        defer { lock.unlock() }
        
        return providers[tableName]
    }
    
    /// Unregister provider for a table
    /// - Parameter tableName: The table name to unregister
    public func unregisterProvider(forTable tableName: String) {
        lock.lock()
        defer { lock.unlock() }
        
        providers.removeValue(forKey: tableName)
        print("📦 [EntityProviderRegistry] Unregistered provider for table '\(tableName)'")
    }
    
    /// Get all registered table names
    public var registeredTables: [String] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(providers.keys)
    }
}
