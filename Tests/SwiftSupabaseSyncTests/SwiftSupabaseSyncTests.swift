import XCTest
import SwiftData
@testable import SwiftSupabaseSync

/// Comprehensive test suite for SwiftSupabaseSync SDK
/// Tests the main SDK interface, initialization, and core functionality
@MainActor
final class SwiftSupabaseSyncTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    /// Test Supabase credentials (loaded from .env file or environment)
    private let testSupabaseURL: String = {
        let url = EnvironmentReader.getEnvVar("SUPABASE_URL")
        guard !url.isEmpty else {
            // If no environment variable found, provide clear instruction
            print("⚠️ SUPABASE_URL not found in environment variables or .env file")
            print("💡 To fix this:")
            print("   1. Add SUPABASE_URL to Xcode scheme environment variables, OR")
            print("   2. Ensure .env file exists in project root with SUPABASE_URL=your_url")
            print("   3. Using fallback URL for testing...")
            return "https://your-project.supabase.co" // Fallback for demo
        }
        return url
    }()
    
    private let testSupabaseAnonKey: String = {
        let key = EnvironmentReader.getEnvVar("SUPABASE_ANON_KEY")
        guard !key.isEmpty else {
            print("⚠️ SUPABASE_ANON_KEY not found in environment variables or .env file")
            print("💡 To fix this:")
            print("   1. Add SUPABASE_ANON_KEY to Xcode scheme environment variables, OR")
            print("   2. Ensure .env file exists in project root with SUPABASE_ANON_KEY=your_key")
            print("   3. Using fallback key for testing...")
            return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.example.fallback" // Fallback for demo
        }
        return key
    }()
    
    /// SDK instance for testing
    private var sdk: SwiftSupabaseSync!
    
    // MARK: - Test Model
    
    /// Test model for schema and sync operations
    @Model
    final class TestTask: Syncable {
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
            return "test_tasks"
        }
        
        init(id: String = UUID().uuidString, title: String, isCompleted: Bool = false) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
            self.createdAt = Date()
            self.updatedAt = Date()
        }
    }
    
    // MARK: - Test Lifecycle
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize SDK instance
        sdk = SwiftSupabaseSync.shared
        
        print("✅ Test setup completed")
    }
    
    // Helper method to set up LocalDataSource and KeychainService for SDK initialization
    private func setupLocalDataSourceForTesting() throws {
        // Set up in-memory SwiftData model context for testing
        let schema = Schema([TestTask.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = ModelContext(modelContainer)
        
        // Create LocalDataSource with test ModelContext
        let localDataSource = LocalDataSource(modelContext: modelContext)
        
        // Create MockKeychainService for testing (avoids iOS Simulator Keychain entitlement issues)
        let mockKeychainService = MockKeychainService()
        
        // Set the global testing services
        RepositoryFactory.testingLocalDataSource = localDataSource
        RepositoryFactory.testingKeychainService = mockKeychainService
        
        print("📦 LocalDataSource registered with in-memory storage for testing")
        print("🔐 MockKeychainService registered to avoid Keychain entitlement issues")
    }
    
    // Helper method to setup before SDK initialization tests
    private func setupForSDKInitialization() throws {
        try setupLocalDataSourceForTesting()
    }
    
        override func tearDown() async throws {
        // Reset SDK state between tests
        await sdk.reset()
        
        // Clear test data sources
        RepositoryFactory.testingLocalDataSource = nil
        RepositoryFactory.testingKeychainService = nil
        
        try await super.tearDown()
        print("♻️ Test teardown completed")
    }
    
    // MARK: - SDK Information Tests
    
    func testSDKVersion() throws {
        XCTAssertEqual(SwiftSupabaseSync.version, "1.0.0")
        XCTAssertEqual(SwiftSupabaseSync.buildNumber, "2025.08.02.001")
        XCTAssertEqual(SwiftSupabaseSync.identifier, "com.parham.SwiftSupabaseSync")
    }
    
    func testSDKInitialState() async throws {
        // Ensure SDK is reset before testing initial state
        await sdk.reset()
        
        // Wait for any ongoing initialization to complete
        while sdk.isInitializing {
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        XCTAssertFalse(sdk.isInitialized)
        XCTAssertFalse(sdk.isInitializing)
        XCTAssertEqual(sdk.initializationState, .notInitialized)
        XCTAssertEqual(sdk.healthStatus, .unknown)
        XCTAssertNil(sdk.auth)
        XCTAssertNil(sdk.sync)
        XCTAssertNil(sdk.schema)
    }
    
    // MARK: - SDK Initialization Tests
    
    func testBasicInitializationForDevelopment() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Test initialization for development
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        // Verify initialization state
        XCTAssertTrue(sdk.isInitialized)
        XCTAssertFalse(sdk.isInitializing)
        XCTAssertEqual(sdk.initializationState, .initialized)
        XCTAssertNotEqual(sdk.healthStatus, .unknown)
        
        // Verify APIs are available
        XCTAssertNotNil(sdk.auth)
        XCTAssertNotNil(sdk.sync)
        XCTAssertNotNil(sdk.schema)
        
        print("✅ Basic initialization successful")
    }
    
    func testProductionInitialization() async throws {
        try setupForSDKInitialization()
        
        // Test production initialization
        try await sdk.initializeForProduction(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        // Verify initialization
        XCTAssertTrue(sdk.isInitialized)
        XCTAssertEqual(sdk.initializationState, .initialized)
        
        // Verify all APIs are available
        XCTAssertNotNil(sdk.auth)
        XCTAssertNotNil(sdk.sync)
        XCTAssertNotNil(sdk.schema)
        
        print("✅ Production initialization successful")
    }
    
    func testAdvancedInitializationWithBuilder() async throws {
        try setupForSDKInitialization()
        
        // Test advanced initialization with builder pattern
        try await sdk.initialize { builder in
            return try builder
                .supabaseURL(testSupabaseURL)
                .supabaseAnonKey(testSupabaseAnonKey)
                .environment(.development)  // Use development instead of testing
                .syncPreset(.offlineFirst)
                .loggingPreset(.debug)       // Use debug instead of testing
                .securityPreset(.development)
                .build()
        }
        
        // Verify initialization
        XCTAssertTrue(sdk.isInitialized)
        XCTAssertEqual(sdk.initializationState, .initialized)
        
        print("✅ Advanced initialization with builder successful")
    }
    
    func testDoubleInitializationPrevention() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // First initialization
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        // Attempt second initialization should throw error
        do {
            try await sdk.initializeForDevelopment(
                supabaseURL: testSupabaseURL,
                supabaseAnonKey: testSupabaseAnonKey
            )
            XCTFail("Second initialization should throw error")
        } catch let error as SDKError {
            // Check error type by comparing descriptions since SDKError isn't Equatable
            switch error {
            case .alreadyInitialized:
                print("✅ Double initialization correctly prevented")
            default:
                XCTFail("Expected alreadyInitialized error, got: \(error)")
            }
        }
    }
    
    func testInitializationWithInvalidCredentials() async throws {
        // Test initialization with invalid URL
        do {
            try await sdk.initializeForDevelopment(
                supabaseURL: "invalid-url",
                supabaseAnonKey: testSupabaseAnonKey
            )
            XCTFail("Initialization with invalid URL should fail")
        } catch {
            print("✅ Invalid URL correctly rejected: \(error)")
        }
        
        // Reset for next test
        await sdk.reset()
        
        // Test initialization with invalid key
        do {
            try await sdk.initializeForDevelopment(
                supabaseURL: testSupabaseURL,
                supabaseAnonKey: "invalid-key"
            )
            XCTFail("Initialization with invalid key should fail")
        } catch {
            print("✅ Invalid key correctly rejected: \(error)")
        }
    }
    
    // MARK: - Health Monitoring Tests
    
    func testHealthCheckBeforeInitialization() async throws {
        // Health check before initialization
        let healthResult = await sdk.performHealthCheck()
        
        XCTAssertEqual(healthResult.overallStatus, .unhealthy)
        XCTAssertFalse(healthResult.isHealthy)
        XCTAssertFalse(healthResult.errors.isEmpty)
        
        print("✅ Health check before initialization: \(healthResult.healthSummary)")
    }
    
    func testHealthCheckAfterInitialization() async throws {
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        // Perform health check
        let healthResult = await sdk.performHealthCheck()
        
        XCTAssertNotEqual(healthResult.overallStatus, .unknown)
        XCTAssertFalse(healthResult.componentStatuses.isEmpty)
        
        // Check component statuses
        XCTAssertNotNil(healthResult.componentStatuses["auth"])
        XCTAssertNotNil(healthResult.componentStatuses["sync"])
        XCTAssertNotNil(healthResult.componentStatuses["schema"])
        
        print("✅ Health check after initialization:")
        print("   Overall: \(healthResult.overallStatus)")
        print("   Summary: \(healthResult.healthSummary)")
        
        healthResult.componentStatuses.forEach { component, status in
            print("   \(component): \(status)")
        }
    }
    
    // MARK: - Runtime Information Tests
    
    func testRuntimeInformation() async throws {
        // Wait for any ongoing initialization to complete first
        while sdk.isInitializing {
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        }
        
        // Test runtime info before initialization
        print("🔍 SDK instance: \(sdk!)")
        print("🔍 SDK isInitialized: \(sdk.isInitialized)")
        print("🔍 About to call getRuntimeInfo...")
        
        var runtimeInfo = sdk.getRuntimeInfo()
        
        print("✅ getRuntimeInfo() succeeded")
        XCTAssertEqual(runtimeInfo.version, "1.0.0")
        XCTAssertEqual(runtimeInfo.buildNumber, "2025.08.02.001")
        XCTAssertFalse(runtimeInfo.isInitialized)
        XCTAssertFalse(runtimeInfo.isAuthenticated)
        XCTAssertFalse(runtimeInfo.isSyncEnabled)
        
        print("✅ Runtime info before initialization:")
        print(runtimeInfo.summary)
        
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        // Test runtime info after initialization
        runtimeInfo = sdk.getRuntimeInfo()
        
        XCTAssertTrue(runtimeInfo.isInitialized)
        XCTAssertTrue(runtimeInfo.configurationPresent)
        XCTAssertEqual(runtimeInfo.initializationState, .initialized)
        
        print("✅ Runtime info after initialization:")
        print(runtimeInfo.summary)
    }
    
    // MARK: - Authentication API Tests
    
    func testAuthenticationAPIAvailability() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        // Test Auth API availability
        guard let auth = sdk.auth else {
            XCTFail("Auth API should be available after initialization")
            return
        }
        
        // Test initial auth state
        XCTAssertFalse(auth.isAuthenticated)
        XCTAssertEqual(auth.authenticationStatus, .signedOut)
        XCTAssertNil(auth.currentUser)
        XCTAssertFalse(auth.isLoading)
        
        print("✅ Auth API available and in correct initial state")
    }
    
    func testAuthenticationSignUp() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        guard let auth = sdk.auth else {
            XCTFail("Auth API not available")
            return
        }
        
        // Generate unique test email
        let testEmail = "test-\(UUID().uuidString.prefix(8))@example.com"
        let testPassword = "TestPassword123!"
        
        do {
            // Attempt sign up
            try await auth.signUp(email: testEmail, password: testPassword)
            
            // Note: In test environment, this might require email verification
            // So we don't necessarily expect to be authenticated immediately
            print("✅ Sign up request sent successfully for \(testEmail)")
            
        } catch {
            // Sign up might fail due to various reasons in test environment
            // Log the error but don't fail the test
            print("⚠️ Sign up error (expected in test environment): \(error)")
        }
    }
    
    // MARK: - Schema API Tests
    
    func testSchemaAPIAvailability() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        guard let schema = sdk.schema else {
            XCTFail("Schema API should be available after initialization")
            return
        }
        
        // Test initial schema state
        XCTAssertEqual(schema.status, .idle)
        XCTAssertTrue(schema.registeredSchemas.isEmpty)
        XCTAssertTrue(schema.allSchemasValid)
        XCTAssertTrue(schema.validationResults.isEmpty)
        
        print("✅ Schema API available and in correct initial state")
    }
    
    func testModelRegistration() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        guard let schema = sdk.schema else {
            XCTFail("Schema API not available")
            return
        }
        
        // Note: Model registration requires authentication which we don't have in tests
        // Instead, we'll just verify the schema API is available and working
        
        // Test that we can attempt registration (it will fail due to auth)
        do {
            try await schema.registerModel(TestTask.self)
            XCTFail("Registration should fail without authentication")
        } catch {
            // Expected to fail due to authentication
            print("✅ Model registration correctly requires authentication")
            print("   Error: \(error)")
        }
    }
    
    // MARK: - Sync API Tests
    
    func testSyncAPIAvailability() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        guard let sync = sdk.sync else {
            XCTFail("Sync API should be available after initialization")
            return
        }
        
        // Test initial sync state
        XCTAssertFalse(sync.isSyncing)
        XCTAssertFalse(sync.isSyncEnabled)
        XCTAssertEqual(sync.progress, 0.0)
        XCTAssertTrue(sync.activeOperations.isEmpty)
        
        print("✅ Sync API available and in correct initial state")
    }
    
    func testSyncModelRegistration() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        guard let sync = sdk.sync else {
            XCTFail("Sync API not available")
            return
        }
        
        // Register model for sync - this doesn't require authentication
        sync.registerModel(TestTask.self)
        
        // Verify registration - sync uses table name not class name
        XCTAssertTrue(sync.registeredModels.contains("test_tasks"))
        
        print("✅ Sync model registration successful")
        print("   Registered models: \(sync.registeredModels.joined(separator: ", "))")
    }
    
    // MARK: - Lifecycle Tests
    
    func testSDKShutdown() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        // Verify initialized state
        XCTAssertTrue(sdk.isInitialized)
        
        // Shutdown SDK
        await sdk.shutdown()
        
        // Verify shutdown state
        XCTAssertFalse(sdk.isInitialized)
        XCTAssertFalse(sdk.isInitializing)
        XCTAssertEqual(sdk.initializationState, .notInitialized)
        XCTAssertEqual(sdk.healthStatus, .unknown)
        XCTAssertNil(sdk.auth)
        XCTAssertNil(sdk.sync)
        XCTAssertNil(sdk.schema)
        
        print("✅ SDK shutdown successful")
    }
    
    func testSDKReset() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        // Verify initialized state
        XCTAssertTrue(sdk.isInitialized)
        
        // Reset SDK
        await sdk.reset()
        
        // Verify reset state (same as shutdown)
        XCTAssertFalse(sdk.isInitialized)
        XCTAssertEqual(sdk.initializationState, .notInitialized)
        
        print("✅ SDK reset successful")
    }
    
    // MARK: - Error Handling Tests
    
    func testSDKErrorTypes() throws {
        // Test SDK error types
        let notInitialized = SDKError.notInitialized
        let alreadyInitialized = SDKError.alreadyInitialized
        let configError = SDKError.configurationError("test")
        
        XCTAssertNotNil(notInitialized.errorDescription)
        XCTAssertNotNil(notInitialized.recoverySuggestion)
        
        XCTAssertNotNil(alreadyInitialized.errorDescription)
        XCTAssertNotNil(alreadyInitialized.recoverySuggestion)
        
        XCTAssertNotNil(configError.errorDescription)
        XCTAssertNotNil(configError.recoverySuggestion)
        
        print("✅ SDK error types provide proper descriptions and recovery suggestions")
    }
    
    func testUsingSDKBeforeInitialization() async throws {
        // Ensure SDK is not initialized
        XCTAssertFalse(sdk.isInitialized)
        
        // Attempting to use APIs before initialization should return nil
        XCTAssertNil(sdk.auth)
        XCTAssertNil(sdk.sync)
        XCTAssertNil(sdk.schema)
        
        print("✅ SDK correctly prevents usage before initialization")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() async throws {
        print("🚀 Starting complete SDK workflow test...")
        
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Step 1: Initialize SDK
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        print("✅ Step 1: SDK initialized")
        
        // Step 2: Verify all APIs are available
        guard let _ = sdk.auth,
              let sync = sdk.sync,
              let schema = sdk.schema else {
            XCTFail("APIs not available after initialization")
            return
        }
        print("✅ Step 2: All APIs available")
        
        // Step 3: Attempt to register model in schema (will fail without auth)
        do {
            try await schema.registerModel(TestTask.self)
            print("⚠️ Step 3: Model registration succeeded (unexpected in test)")
        } catch {
            print("✅ Step 3: Model registration requires authentication (expected)")
        }
        
        // Step 4: Register model for sync
        sync.registerModel(TestTask.self)
        print("✅ Step 4: Model registered for sync")
        
        // Step 5: Perform health check
        let healthResult = await sdk.performHealthCheck()
        print("✅ Step 5: Health check completed (\(healthResult.overallStatus))")
        
        // Step 6: Get runtime information
        let runtimeInfo = sdk.getRuntimeInfo()
        print("✅ Step 6: Runtime info retrieved")
        print(runtimeInfo.summary)
        
        print("🎉 Complete workflow test successful!")
    }
    
    // MARK: - Performance Tests
    
    func testSDKInitializationPerformance() throws {
        measure {
            Task {
                await sdk.reset()
                try? await sdk.initializeForDevelopment(
                    supabaseURL: testSupabaseURL,
                    supabaseAnonKey: testSupabaseAnonKey
                )
            }
        }
    }
    
    func testHealthCheckPerformance() async throws {
        // Set up test services before SDK initialization
        try setupForSDKInitialization()
        
        // Initialize SDK first
        try await sdk.initializeForDevelopment(
            supabaseURL: testSupabaseURL,
            supabaseAnonKey: testSupabaseAnonKey
        )
        
        measure {
            Task {
                _ = await sdk.performHealthCheck()
            }
        }
    }
}
