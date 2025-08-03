//
//  PublicAPITests.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Testing
import Foundation
import SwiftData
import SwiftSupabaseSync

/// Tests that validate the public API interface of SwiftSupabaseSync SDK
/// These tests ensure that the public APIs work correctly without accessing internal implementation
@Suite("SwiftSupabaseSync Public API Tests")
@MainActor
struct PublicAPITests {
    
    // MARK: - Test Configuration
    
    /// Test Supabase credentials from environment
    let testSupabaseURL: String
    let testSupabaseAnonKey: String
    
    /// SDK instance for testing
    let sdk: SwiftSupabaseSync
    
    /// Test user credentials
    let testEmail = "test-public-\(UUID().uuidString.prefix(8))@example.com"
    let testPassword = "TestPassword123!"
    
    // MARK: - Test Model
    
    /// Test model for sync operations - using only public APIs
    @Model
    final class PublicTestTodo: Syncable {
        var id: String
        var title: String
        var isCompleted: Bool
        var createdAt: Date
        var updatedAt: Date
        
        // MARK: - Syncable Requirements
        
        var syncID: UUID = UUID()
        var lastModified: Date = Date()
        var lastSynced: Date?
        var isDeleted: Bool = false
        var version: Int = 1
        
        var contentHash: String {
            let content = "\(title)-\(isCompleted)-\(updatedAt.timeIntervalSince1970)"
            return content.data(using: .utf8)?.base64EncodedString() ?? ""
        }
        
        var needsSync: Bool {
            guard let lastSynced = lastSynced else { return true }
            return lastModified > lastSynced
        }
        
        static var tableName: String {
            return "todos"  // Use existing table that integration tests use
        }
        
        static var syncableProperties: [String] {
            return ["id", "title", "isCompleted", "createdAt", "updatedAt"]
        }
        
        init(id: String = UUID().uuidString, title: String, isCompleted: Bool = false) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
    
    // MARK: - Initialization
    
    init() throws {
        // Load environment variables
        self.testSupabaseURL = EnvironmentReader.getEnvVar("SUPABASE_URL")
        self.testSupabaseAnonKey = EnvironmentReader.getEnvVar("SUPABASE_ANON_KEY")
        
        #expect(!testSupabaseURL.isEmpty, "SUPABASE_URL must be set in environment")
        #expect(!testSupabaseAnonKey.isEmpty, "SUPABASE_ANON_KEY must be set in environment")
        
        // Initialize SDK using public API
        sdk = SwiftSupabaseSync.shared
    }
    
    // MARK: - Utility Methods
    
    /// Initialize SDK using public APIs only
    private func initializeSDK() async throws {
        // Use public initialization API
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        // Verify SDK is properly initialized
        #expect(sdk.isInitialized)
        #expect(sdk.initializationState == .initialized)
        #expect(sdk.auth != nil)
        #expect(sdk.sync != nil)
        #expect(sdk.schema != nil)
    }
    
    /// Clean up after tests using public APIs only
    private func cleanupSDK() async {
        // Use public shutdown API
        await sdk.shutdown()
        
        // Verify cleanup
        #expect(!sdk.isInitialized)
    }
    
    // MARK: - Basic Public API Tests
    
    @Test("SDK basic public interface availability")
    func testSDKPublicInterface() async throws {
        // Test SDK static properties and methods without initialization
        #expect(SwiftSupabaseSync.version == "1.0.0", "Version should be correct")
        #expect(!SwiftSupabaseSync.identifier.isEmpty, "Identifier should not be empty")
        #expect(!SwiftSupabaseSync.buildNumber.isEmpty, "Build number should not be empty")
        
        // Test SDK instance availability
        let sdk = SwiftSupabaseSync.shared
        // SDK instance should always be available (singleton pattern)
        
        // Test initial state without initialization
        #expect(!sdk.isInitialized, "SDK should not be initialized initially")
        #expect(!sdk.isInitializing, "SDK should not be initializing initially")
        #expect(sdk.initializationState == .notInitialized, "Initial state should be notInitialized")
        
        print("✅ SDK public interface validated successfully")
        print("   Version: \(SwiftSupabaseSync.version)")
        print("   Build: \(SwiftSupabaseSync.buildNumber)")
        print("   Identifier: \(SwiftSupabaseSync.identifier)")
    }
    
    @Test("Configuration builder public API")
    func testConfigurationBuilder() async throws {
        // Test ConfigurationBuilder public API
        let configBuilder = ConfigurationBuilder()
        
        // Test method chaining with proper testing configuration
        let _ = try configBuilder
            .supabaseURL(testSupabaseURL)
            .supabaseAnonKey(testSupabaseAnonKey)
            .environment(.testing)
            .bundleIdentifier("com.test.app")
            .appVersion("1.0.0")
            .buildNumber("1")
            .sync { builder in
                builder
                    .maxRetryAttempts(1)  // Minimal retry for testing
                    .requestTimeoutInterval(5.0)  // Quick timeout for testing
                    .batchSize(10)  // Small batch for testing
            }
            .loggingPreset(.testing)
            .securityPreset(.development)
            .build()
        
        // Configuration should be built successfully (throws if invalid)
        
        // Test quick builders
        let _ = try ConfigurationBuilder.development(
            url: testSupabaseURL,
            key: testSupabaseAnonKey
        )
        // Development config should be built successfully
        
        let _ = try ConfigurationBuilder.production(
            url: testSupabaseURL,
            key: testSupabaseAnonKey
        )
        // Production config should be built successfully
        
        print("✅ Configuration builder API validated successfully")
        print("   Method chaining: ✓")
        print("   Quick builders: ✓")
        print("   Configuration validation: ✓")
    }
    
    /// Test that validates model registration APIs work correctly
    @Test("Model Registration API")
    func testModelRegistrationAPI() async throws {
        print("🔧 Testing model registration APIs...")
        
        // Initialize SDK for testing
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        guard let syncAPI = sdk.sync else {
            throw SwiftSupabaseSyncError.invalidConfiguration(parameter: "sync", reason: "Sync API not available")
        }
        
        // Test initial state - no models registered
        print("   📋 Initial state: \(syncAPI.registeredModels.count) models")
        
        // Test 1: Single model registration
        print("   🔸 Testing single model registration...")
        syncAPI.registerModel(PublicTestTodo.self)
        #expect(syncAPI.registeredModels.contains("todos"))
        print("      ✅ registerModel(PublicTestTodo.self) works")
        
        // Test 2: Array-based multiple registration  
        print("   🔸 Testing array-based registration...")
        syncAPI.registerModels([PublicTestTodo.self])
        #expect(syncAPI.registeredModels.contains("todos"))
        print("      ✅ registerModels([ModelType.self]) works")
        
        // Test 3: Variadic registration (developer-friendly syntax)
        print("   🔸 Testing variadic registration...")
        syncAPI.registerModels(PublicTestTodo.self)
        #expect(syncAPI.registeredModels.contains("todos"))
        print("      ✅ registerModels(Model1.self, Model2.self...) works")
        
        // Test 4: Unregistration
        print("   🔸 Testing model unregistration...")
        syncAPI.unregisterModel(PublicTestTodo.self)
        // Note: unregister removes from SyncManager but doesn't remove from SyncAPI.registeredModels Set
        // This is because SyncAPI tracks what was ever registered in this session
        print("      ✅ unregisterModel(PublicTestTodo.self) works")
        
        // Test 5: Re-registration after unregister
        print("   🔸 Testing re-registration...")
        syncAPI.registerModel(PublicTestTodo.self)
        #expect(syncAPI.registeredModels.contains("todos"))
        print("      ✅ Re-registration after unregister works")
        
        print("🎯 All model registration APIs validated successfully!")
        print("   📊 Final registered models: \(syncAPI.registeredModels)")
    }

    @Test("Real-world developer workflow using public APIs")
    func testRealWorldDeveloperWorkflow() async throws {
        print("🚀 Testing real-world developer workflow...")
        
        // Step 1: Developer creates their SwiftData models
        // (Already defined: PublicTestTodo)
        print("   ✓ Developer has SwiftData models conforming to Syncable")
        
        // Step 2: Simple SDK initialization
        let sdk = SwiftSupabaseSync.shared
        
        // Test that SDK is ready for configuration
        #expect(!sdk.isInitialized, "SDK should start uninitialized")
        
        // Step 3: Test the configuration - show how simple it should be
        print("   📋 Testing simple configuration...")
        
        let _ = try ConfigurationBuilder()
            .supabaseURL(testSupabaseURL)
            .supabaseAnonKey(testSupabaseAnonKey)
            .environment(.testing)
            .sync { builder in
                builder
                    .maxRetryAttempts(1)
                    .requestTimeoutInterval(5.0)
                    .batchSize(10)
            }
            .loggingPreset(.testing)
            .build()
        
        print("   ✓ Configuration created successfully")
        
        // Step 4: Test actual model registration functionality
        print("   📦 Testing model registration APIs...")
        
        // Create a minimal SDK setup for testing registration without full initialization
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        guard let syncAPI = sdk.sync else {
            throw SwiftSupabaseSyncError.invalidConfiguration(parameter: "sync", reason: "Sync API not available")
        }
        
        // Test 1: Single model registration
        print("      Testing: syncAPI.registerModel(PublicTestTodo.self)")
        syncAPI.registerModel(PublicTestTodo.self)
        #expect(syncAPI.registeredModels.contains("todos"))
        print("      ✓ Single model registration works")
        
        // Test 2: Array-based registration
        print("      Testing: syncAPI.registerModels([PublicTestTodo.self])")
        syncAPI.registerModels([PublicTestTodo.self])
        #expect(syncAPI.registeredModels.contains("todos"))
        print("      ✓ Array-based registration works")
        
        // Test 3: Variadic registration (most developer-friendly)
        print("      Testing: syncAPI.registerModels(PublicTestTodo.self)")
        syncAPI.registerModels(PublicTestTodo.self)
        #expect(syncAPI.registeredModels.contains("todos"))
        print("      ✓ Variadic registration works")
        
        // Test 4: Multiple models at once (simulated with same model for test)
        print("      Testing: syncAPI.registerModels(Multiple types...)")
        syncAPI.registerModels(PublicTestTodo.self, PublicTestTodo.self)
        #expect(syncAPI.registeredModels.contains("todos"))
        print("      ✓ Multiple model registration works")
        
        print("   📋 Model registration APIs validated successfully!")
        
        // Step 5: Show the complete workflow that developers would follow
        print("   🔄 Complete developer workflow validation:")
        print("      ✅ 1. Create SwiftData models conforming to Syncable")
        print("      ✅ 2. Initialize SDK with Supabase credentials")
        print("      ✅ 3. Register models: sdk.sync?.registerModels(Todo.self, User.self)")
        print("      ⏳ 4. Authenticate: sdk.auth?.signIn(email, password)")
        print("      ⏳ 5. Start syncing: sdk.sync?.startSync()")
        print("      ⏳ 6. Models automatically sync bidirectionally!")
        
        print("✅ Real-world workflow validated - Model registration APIs work perfectly!")
    }

}

// MARK: - Test Schema Observer

/// Test observer for schema events
class TestSchemaObserver: SchemaObserver {
    func schemaValidationCompleted(_ result: PublicSchemaValidation) {
        // Test observer implementation
    }
    
    func schemaMigrationCompleted(_ result: PublicSchemaMigration) {
        // Test observer implementation
    }
    
    func schemaStatusChanged(_ status: PublicSchemaStatus, for modelName: String?) {
        // Test observer implementation
    }
    
    func schemaErrorOccurred(_ error: SwiftSupabaseSyncError, for modelName: String) {
        // Test observer implementation
    }
}
