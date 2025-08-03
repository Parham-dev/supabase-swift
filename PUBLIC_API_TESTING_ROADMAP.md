# Public API Testing Roadmap

## Overview

This roadmap outlines a comprehensive testing strategy for all public APIs in SwiftSupabaseSync using the new Swift Testing framework. The goal is to create real-world integration tests that simulate actual app usage patterns while ensuring all public APIs work correctly.

## Public APIs Analyzed

### 1. AuthAPI (`Sources/Public/AuthAPI.swift`)
**Primary Functions:**
- `signIn(email:password:)` - Email/password authentication
- `signUp(email:password:displayName:)` - User registration  
- `signOut()` - User logout
- `refreshToken()` - Token refresh
- `validateSession()` - Session validation
- `hasFeatureAccess(_:)` - Feature access checking
- `getSubscriptionInfo()` - Subscription details
- Observer management methods

**Key Properties:**
- `@Published currentUser: UserInfo?`
- `@Published isAuthenticated: Bool`
- `@Published authenticationStatus: PublicAuthenticationStatus`
- Combine publishers for state changes

### 2. SyncAPI (`Sources/Public/SyncAPI.swift`)
**Primary Functions:**
- `startSync()` - Full synchronization
- `startIncrementalSync(for:)` - Model-specific sync
- `stopSync()`, `pauseSync()`, `resumeSync()` - Sync control
- `registerModel(_:)`, `unregisterModel(_:)` - Model management
- Conflict resolution methods
- Policy configuration methods

**Key Properties:**
- `@Published status: PublicSyncStatus`
- `@Published isSyncing: Bool`
- `@Published progress: Double`
- `@Published conflictCount: Int`

### 3. SchemaAPI (`Sources/Public/SchemaAPI.swift`)
**Primary Functions:**
- `registerModel(_:)` - Schema registration
- `validateSchema(for:)` - Schema validation
- `migrateSchema(for:)` - Schema migration
- `generateSchemas()` - Schema generation
- `generateMigrationSQL(for:)` - SQL generation (no auth required)

**Key Properties:**
- `@Published status: PublicSchemaStatus`
- `@Published registeredSchemas: [String: PublicSchemaInfo]`
- `@Published allSchemasValid: Bool`

## Current Test Infrastructure

### Existing Helpers
- ✅ `EnvironmentReader` - Loads test credentials from .env file
- ✅ `TestingDataSourceProvider` - Test data source configuration
- ✅ `MockKeychainService` - Keychain mock for isolated tests
- ✅ `MockSupabaseAuthDataSource` - Auth data source mock

### Existing Test Structure
```
SupabaseSwiftTests/
├── Integration/                     # Real Supabase integration tests
├── PublicAPI/                      # Public API specific tests  
├── Mocks/                          # Mock implementations
└── Helpers/                        # Test utilities
```

## Testing Strategy

### Phase 1: Foundation Setup
**Duration: 1-2 days**

#### 1.1 Enhanced Mock Infrastructure
Create comprehensive mocks that work seamlessly with the new Swift Testing framework:

```swift
// Enhanced mocks needed:
- MockSyncManager
- MockSchemaManager  
- MockNetworkMonitor
- MockSupabaseClient
- MockRealtimeClient
- MockConflictResolver
```

#### 1.2 Test Model Infrastructure
Create standardized test models that cover all Syncable requirements:

```swift
@Model
final class TestUser: Syncable {
    // Complete Syncable implementation
    // Relationships testing
    // Complex data types
}

@Model  
final class TestProject: Syncable {
    // One-to-many relationships
    // Optional fields
    // Date handling
}

@Model
final class TestTask: Syncable {
    // Many-to-many relationships
    // Enums and custom types
    // Validation scenarios
}
```

#### 1.3 Test Data Factory
Build a factory for creating consistent test data:

```swift
struct TestDataFactory {
    static func createTestUser() -> TestUser
    static func createTestProject(for user: TestUser) -> TestProject
    static func createAuthenticatedState() -> AuthState
    static func createSyncScenario() -> SyncTestScenario
}
```

### Phase 2: AuthAPI Integration Tests
**Duration: 2-3 days**

#### 2.1 Authentication Flow Tests
```swift
@Suite("AuthAPI Integration Tests")
struct AuthAPIIntegrationTests {
    
    @Test("Complete sign up and authentication flow")
    func testSignUpAndAuthenticationFlow()
    
    @Test("Sign in with existing user")  
    func testSignInFlow()
    
    @Test("Session management and token refresh")
    func testSessionManagement()
    
    @Test("Sign out and cleanup")
    func testSignOutFlow()
    
    @Test("Feature access validation")
    func testFeatureAccessChecking()
    
    @Test("Subscription tier handling")
    func testSubscriptionTierManagement()
}
```

#### 2.2 AuthAPI Observer Tests
```swift
@Test("Auth state changes trigger observers correctly")
func testAuthStateObservers()

@Test("Combine publishers emit correct values")
func testAuthPublishers() 

@Test("SwiftUI @Published properties update correctly")
func testSwiftUIIntegration()
```

#### 2.3 AuthAPI Error Handling
```swift
@Test("Invalid credentials handling")
func testInvalidCredentials()

@Test("Network failure scenarios") 
func testNetworkFailures()

@Test("Session expiration handling")
func testSessionExpiration()
```

### Phase 3: SyncAPI Integration Tests
**Duration: 3-4 days**

#### 3.1 Basic Sync Operations
```swift
@Suite("SyncAPI Basic Operations")
struct SyncAPIBasicTests {
    
    @Test("Register and sync single model")
    func testSingleModelSync()
    
    @Test("Register and sync multiple models")
    func testMultipleModelSync()
    
    @Test("Full sync workflow")
    func testFullSyncWorkflow()
    
    @Test("Incremental sync workflow") 
    func testIncrementalSyncWorkflow()
}
```

#### 3.2 Sync Control and Management
```swift
@Test("Pause and resume sync operations")
func testSyncPauseResume()

@Test("Stop sync operations")
func testSyncStop()

@Test("Sync policy configuration")
func testSyncPolicyConfiguration()

@Test("Concurrent sync handling")
func testConcurrentSyncOperations()
```

#### 3.3 Conflict Resolution
```swift
@Test("Conflict detection and resolution")
func testConflictResolution()

@Test("User-driven conflict resolution")
func testUserDrivenConflictResolution()

@Test("Automatic conflict resolution")
func testAutomaticConflictResolution()
```

#### 3.4 Real-world Sync Scenarios
```swift
@Test("Offline-to-online sync")
func testOfflineToOnlineSync()

@Test("Simultaneous device sync")
func testMultiDeviceSync() 

@Test("Large dataset synchronization")
func testLargeDatasetSync()

@Test("Network interruption handling")
func testNetworkInterruptionHandling()
```

### Phase 4: SchemaAPI Integration Tests  
**Duration: 2-3 days**

#### 4.1 Schema Management
```swift
@Suite("SchemaAPI Integration Tests")
struct SchemaAPIIntegrationTests {
    
    @Test("Register model and validate schema")
    func testSchemaRegistrationAndValidation()
    
    @Test("Schema migration workflow")
    func testSchemaMigrationWorkflow()
    
    @Test("Schema generation for models")
    func testSchemaGeneration()
    
    @Test("SQL migration script generation")
    func testSQLMigrationGeneration()
}
```

#### 4.2 Schema Validation Scenarios
```swift
@Test("Valid schema validation")
func testValidSchemaValidation()

@Test("Invalid schema detection")
func testInvalidSchemaDetection()

@Test("Schema compatibility checking")
func testSchemaCompatibility()

@Test("Auto-validation behavior")
func testAutoValidation()
```

### Phase 5: Cross-API Integration Tests
**Duration: 2-3 days**

#### 5.1 Multi-API Workflows
```swift
@Suite("Cross-API Integration Tests") 
struct CrossAPIIntegrationTests {
    
    @Test("Complete app lifecycle simulation")
    func testCompleteAppLifecycle()
    
    @Test("Auth -> Schema -> Sync workflow")
    func testFullWorkflowIntegration()
    
    @Test("Error propagation across APIs")
    func testErrorPropagationAcrossAPIs()
    
    @Test("State consistency across APIs")
    func testStateConsistencyAcrossAPIs()
}
```

#### 5.2 Real App Simulation
```swift
@Test("Simulate typical todo app usage")
func testTodoAppSimulation()

@Test("Simulate e-commerce app patterns")
func testECommercePatterns()

@Test("Simulate social app scenarios")
func testSocialAppScenarios()
```

### Phase 6: Performance and Edge Case Tests
**Duration: 2-3 days**

#### 6.1 Performance Tests
```swift
@Test("Large dataset performance")
func testLargeDatasetPerformance()

@Test("Concurrent operation performance")
func testConcurrentOperationPerformance()

@Test("Memory usage during sync")
func testMemoryUsage()
```

#### 6.2 Edge Cases
```swift
@Test("Rapid authentication changes")
func testRapidAuthChanges()

@Test("Schema changes during sync")
func testSchemaChangesInProcress()

@Test("Device connectivity changes")
func testConnectivityChanges()
```

## Required Mock Infrastructure

### Critical Mocks to Create

#### 1. MockSyncManager
```swift
final class MockSyncManager: @unchecked Sendable {
    @Published var isSyncing: Bool = false
    @Published var syncProgress: Double = 0.0
    @Published var syncStatus: SyncStatusInfo = .idle
    
    // Configurable behaviors
    var shouldFailSync: Bool = false
    var syncDuration: TimeInterval = 1.0
    var conflictsToReturn: [SyncConflict] = []
    
    func startSync() async throws -> SyncOperationResult
    func registerModel<T: Syncable>(_ type: T.Type)
    // ... other SyncManager methods
}
```

#### 2. MockSchemaManager 
```swift
final class MockSchemaManager: @unchecked Sendable {
    @Published var registeredModels: [String: SchemaInfo] = [:]
    @Published var isGeneratingSchema: Bool = false
    
    // Configurable behaviors
    var schemasToValidate: [String: SchemaValidationResult] = [:]
    var shouldFailValidation: Bool = false
    
    func registerModel<T: Syncable>(_ type: T.Type) async throws
    func validateSchema<T: Syncable>(for type: T.Type) async throws -> SchemaValidationResult
    // ... other SchemaManager methods
}
```

#### 3. Enhanced Test Utilities
```swift
struct TestEnvironmentSetup {
    static func createTestContainer() throws -> ModelContainer
    static func createMockServices() -> ServiceContainer
    static func setupTestSupabaseClient() -> MockSupabaseClient
}

final class TestObserver: SyncObserver, AuthenticationObserver, SchemaObserver {
    var receivedEvents: [TestEvent] = []
    // Implementations for all observer protocols
}

enum TestEvent {
    case authStateChanged(PublicAuthenticationStatus)
    case syncStatusChanged(PublicSyncStatus)
    case schemaValidated(PublicSchemaValidation)
    // ... other events
}
```

## Test Configuration and Environment

### Environment Variables Required
```bash
# .env file structure
SUPABASE_URL=your_test_supabase_url
SUPABASE_ANON_KEY=your_test_anon_key
SUPABASE_SERVICE_KEY=your_test_service_key

# Test user credentials
TEST_EMAIL=test@example.com
TEST_PASSWORD=TestPassword123!

# Test database settings
TEST_DB_CLEAN_ON_START=true
TEST_TIMEOUT_SECONDS=30
```

### Test Database Setup
1. **Dedicated Test Database**: Use separate Supabase project for testing
2. **Schema Setup**: Automated table creation/cleanup
3. **Data Isolation**: Each test gets clean database state
4. **Cleanup Strategy**: Automated cleanup after each test

## Success Criteria

### Phase Completion Criteria

#### Phase 1 - Foundation ✅
- [ ] All mock services created and tested
- [ ] Test models with complete Syncable implementation 
- [ ] Test data factory producing consistent data
- [ ] Environment setup automated

#### Phase 2 - AuthAPI ✅
- [ ] All authentication flows tested and passing
- [ ] Observer pattern working correctly
- [ ] Error scenarios handled properly
- [ ] SwiftUI integration verified

#### Phase 3 - SyncAPI ✅  
- [ ] Basic sync operations working
- [ ] Conflict resolution tested
- [ ] Real-world scenarios covered
- [ ] Performance within acceptable limits

#### Phase 4 - SchemaAPI ✅
- [ ] Schema management workflows tested
- [ ] SQL generation working correctly
- [ ] Validation logic verified
- [ ] Migration scenarios covered

#### Phase 5 - Cross-API ✅
- [ ] Full app lifecycle simulation working
- [ ] State consistency across APIs verified
- [ ] Error propagation tested
- [ ] Real app patterns validated

#### Phase 6 - Performance ✅
- [ ] Performance benchmarks established
- [ ] Edge cases handled correctly
- [ ] Memory leaks eliminated
- [ ] Stress testing passed

## Implementation Guidelines

### Swift Testing Best Practices
1. **Use `@Suite` for logical grouping** of related tests
2. **Use `@Test` with descriptive names** that explain the scenario
3. **Use `#expect`** for assertions instead of XCTest assertions
4. **Use `withKnownIssue`** for tracking known issues
5. **Use `Issue.record`** for custom failure messages
6. **Leverage async/await** for all asynchronous operations

### Test Structure Pattern
```swift
@Suite("API Name - Feature Category")
struct APIFeatureTests {
    
    // Test setup
    let mockServices: MockServiceContainer
    let testAPI: APIUnderTest
    
    init() async throws {
        // Setup test environment
    }
    
    @Test("Descriptive test name explaining scenario")
    func testSpecificScenario() async throws {
        // Given - setup test conditions
        // When - perform the action
        // Then - verify results with #expect
    }
    
    deinit {
        // Cleanup if needed
    }
}
```

### Error Testing Pattern
```swift
@Test("API handles network failure gracefully")
func testNetworkFailureHandling() async throws {
    // Given
    mockNetworkService.simulateFailure = true
    
    // When & Then
    await #expect(throws: SwiftSupabaseSyncError.networkUnavailable) {
        try await api.performOperation()
    }
    
    // Verify error state
    #expect(api.lastError != nil)
    #expect(api.status == .error)
}
```

## Timeline Summary

- **Week 1**: Phase 1 (Foundation) + Phase 2 (AuthAPI)
- **Week 2**: Phase 3 (SyncAPI) + Phase 4 (SchemaAPI) 
- **Week 3**: Phase 5 (Cross-API) + Phase 6 (Performance)

**Total Duration: 3 weeks**

This roadmap ensures comprehensive coverage of all public APIs with real-world testing scenarios that simulate actual app usage patterns.