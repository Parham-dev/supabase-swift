//
//  PublicAPITests_Clean.swift
//  SwiftSupabaseSync
//
//  Created by GitHub Copilot on 03/08/2025.
//

import Foundation
import XCTest
import SwiftData
@testable import SwiftSupabaseSync

// MARK: - Public API Tests (Clean Version)

/// Test model conforming to Syncable for public API testing
@Model
public class PublicTestTodo: Syncable {
    @Attribute(.unique) public var id: UUID
    @Attribute public var title: String
    @Attribute public var isCompleted: Bool
    @Attribute public var createdAt: Date
    @Attribute public var updatedAt: Date?
    @Attribute public var userId: String?
    @Attribute public var remoteID: String?
    @Attribute public var lastSynced: Date?
    @Attribute public var syncStatus: String
    @Attribute public var version: Int
    
    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false, createdAt: Date = Date(), updatedAt: Date? = nil, userId: String? = nil, remoteID: String? = nil, lastSynced: Date? = nil, syncStatus: String = "pending", version: Int = 1) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userId = userId
        self.remoteID = remoteID
        self.lastSynced = lastSynced
        self.syncStatus = syncStatus
        self.version = version
    }
    
    public static var tableName: String { "todos" }
}

@Suite("Schema API Tests")
@MainActor
struct SchemaAPITests {
    
    // MARK: - Test Configuration
    
    let testSupabaseURL = "https://test.supabase.co"
    let testSupabaseAnonKey = "test-anon-key"
    
    var sdk: SwiftSupabaseSync
    
    init() {
        self.sdk = SwiftSupabaseSync()
    }
    
    /// Test that validates SchemaAPI public interface
    @Test("Schema API public interface")
    func testSchemaAPI() async throws {
        Swift.print("🔧 Testing Schema API public interface...")
        
        // Initialize SDK for testing
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        guard let schemaAPI = sdk.schema else {
            throw SwiftSupabaseSyncError.invalidConfiguration(parameter: "schema", reason: "Schema API not available")
        }
        
        // Test initial state
        Swift.print("   📋 Testing initial schema state...")
        #expect(schemaAPI.status == .idle)
        #expect(schemaAPI.autoValidationEnabled == false)
        Swift.print("      ✅ Initial state correct")
        
        // Test schema information methods (no auth required)
        Swift.print("   📦 Testing schema information methods...")
        _ = schemaAPI.getSchemaSummary()
        let isRegistered = schemaAPI.isModelRegistered(PublicTestTodo.self)
        #expect(isRegistered == false) // Should not be registered initially
        
        let schemaInfo = schemaAPI.getSchemaInfo(for: PublicTestTodo.self)
        #expect(schemaInfo == nil) // Should be nil for unregistered model
        
        let validationResult = schemaAPI.getValidationResult(for: PublicTestTodo.self)
        #expect(validationResult == nil) // Should be nil for unvalidated model
        Swift.print("      ✅ Schema information methods work correctly")
        
        // Test error management methods
        Swift.print("   ⚠️ Testing error management...")
        let modelsWithErrors = schemaAPI.getModelsWithErrors()
        #expect(modelsWithErrors.isEmpty) // Should be empty initially
        
        let modelsRequiringMigration = schemaAPI.getModelsRequiringMigration()
        #expect(modelsRequiringMigration.isEmpty) // Should be empty initially
        
        schemaAPI.clearErrors() // Should not crash
        Swift.print("      ✅ Error management methods work correctly")
        
        // Test observer pattern
        Swift.print("   👥 Testing observer pattern...")
        let observer = TestSchemaObserver()
        schemaAPI.addObserver(observer)
        schemaAPI.removeObserver(observer)
        schemaAPI.removeAllObservers()
        Swift.print("      ✅ Observer pattern works correctly")
        
        // Test unregister (should not crash for unregistered model)
        Swift.print("   🗑️ Testing model unregistration...")
        schemaAPI.unregisterModel(PublicTestTodo.self) // Should not crash
        Swift.print("      ✅ Model unregistration handled gracefully")
        
        Swift.print("✅ Schema API public interface validated - All non-auth methods work correctly!")
    }
}

// MARK: - Test Schema Observer

/// Test observer for schema events
class TestSchemaObserver: SchemaObserver {
    func schemaValidationCompleted(for modelName: String, isValid: Bool) {
        // Test observer implementation
    }
    
    func schemaMigrationCompleted(for modelName: String, success: Bool) {
        // Test observer implementation
    }
    
    func schemaStatusChanged(_ status: PublicSchemaStatus, for modelName: String?) {
        // Test observer implementation
    }
    
    func schemaErrorOccurred(_ error: SwiftSupabaseSyncError, for modelName: String) {
        // Test observer implementation
    }
}
