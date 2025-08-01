# SwiftSupabaseSync Testing Guide

This document outlines the comprehensive testing strategy for SwiftSupabaseSync, prioritizing files by importance and impact on the overall system functionality.

## Testing Framework

We use Swift's new **Swift Testing framework** introduced in Swift 6.0+ which provides:
- Modern async/await support
- Better error handling and debugging
- Improved test organization with `@Test` attributes
- Enhanced parameterized testing
- Better integration with Xcode and CI/CD

## Testing Priority Structure

### Tier 1: Critical Core Business Logic (High Priority)
These components contain the essential business logic and should be tested first:

#### 1. Core Domain Entities (Priority: 🔴 Critical)
- **Syncable.swift** - Core synchronization protocol
- **SyncPolicy.swift** - Synchronization policy definitions
- **SyncStatus.swift** - Status tracking for sync operations
- **ConflictResolutionTypes.swift** - Conflict resolution strategies
- **ConflictTypes.swift** - Conflict data structures
- **SyncOperationTypes.swift** - Operation type definitions
- **AuthenticationTypes.swift** - Authentication data structures
- **User.swift** - User entity model

#### 2. Core Domain Protocols (Priority: 🔴 Critical)
- **ConflictResolvable.swift** - Conflict resolution interface
- **SubscriptionValidating.swift** - Subscription validation interface
- **SyncRepositoryProtocol.swift** - Repository abstraction
- **AuthRepositoryProtocol.swift** - Authentication repository interface

#### 3. Core Domain Use Cases (Priority: 🔴 Critical)
- **StartSyncUseCase.swift** - Sync initiation logic
- **ResolveSyncConflictUseCase.swift** - Conflict resolution business logic
- **AuthenticateUserUseCase.swift** - User authentication workflow
- **ValidateSubscriptionUseCase.swift** - Subscription validation logic

#### 4. Core Domain Services (Priority: 🟠 High)
- **ConflictResolvers.swift** - Conflict resolution implementations
- **SyncOperationManager.swift** - Sync operation coordination
- **ResolutionHistoryManager.swift** - History tracking
- **ValidationCacheManager.swift** - Validation caching

### Tier 2: Data Layer and Infrastructure (Medium Priority)
These components handle data access and external integrations:

#### 5. Core Data Repositories (Priority: 🟠 High)
- **SyncRepository.swift** - Main sync data repository
- **AuthRepository.swift** - Authentication data repository
- **ConflictRepository.swift** - Conflict data repository
- **SyncRepositoryError.swift** - Repository error handling

#### 6. Core Data Services (Priority: 🟠 High)
- **SyncChangeTracker.swift** - Change tracking service
- **SyncMetadataManager.swift** - Metadata management
- **SyncIntegrityValidationService.swift** - Data integrity validation
- **SyncConflictResolutionService.swift** - Conflict resolution service

#### 7. Infrastructure Network (Priority: 🟡 Medium)
- **NetworkMonitor.swift** - Network connectivity monitoring
- **SupabaseClient.swift** - Supabase client implementation
- **NetworkConfiguration.swift** - Network configuration
- **Network.swift** - Core networking layer
- **RequestBuilder.swift** - HTTP request builder
- **NetworkError.swift** - Network error handling

#### 8. Infrastructure Storage (Priority: 🟡 Medium)
- **KeychainService.swift** - Secure storage service
- **LocalDataSource.swift** - Local data management

### Tier 3: Supporting Infrastructure (Lower Priority)
These components provide supporting functionality:

#### 9. Dependency Injection (Priority: 🟡 Medium)
- **ServiceLocator.swift** - Service location pattern
- **RepositoryFactory.swift** - Repository factory pattern
- **DependencyInjectionSetup.swift** - DI container setup
- **ConfigurationProvider.swift** - Configuration management
- **DICore.swift** - Core DI functionality

#### 10. Supporting Services (Priority: 🟢 Low)
- **LoggingService.swift** - Application logging
- **SubscriptionValidator.swift** - Subscription validation
- **SyncOperationsManager.swift** - Operations management
- **SyncSchemaValidationService.swift** - Schema validation

## Test Implementation Strategy

### Phase 1: Foundation Testing (Week 1)
1. **Setup Swift Testing Framework** ✅
2. **Test Core Entities** - Start with Syncable protocol and basic entities
3. **Test Core Protocols** - Ensure abstractions work correctly
4. **Basic Integration Tests** - Minimal end-to-end scenarios

### Phase 2: Business Logic Testing (Week 2)
1. **Use Case Testing** - Comprehensive testing of business workflows
2. **Service Testing** - Core services and conflict resolution
3. **Repository Testing** - Data access layer with mocks

### Phase 3: Infrastructure Testing (Week 3)
1. **Network Layer Testing** - API clients and network handling
2. **Storage Testing** - Local data persistence
3. **DI Container Testing** - Dependency injection setup

### Phase 4: Integration & Performance (Week 4)
1. **End-to-End Testing** - Complete workflows
2. **Performance Testing** - Sync performance and memory usage
3. **Error Scenario Testing** - Network failures, conflicts, etc.

## Testing Patterns

### 1. Entity Testing
```swift
@Test("Entity should initialize with correct defaults")
func testEntityDefaults() async throws {
    let entity = MyEntity()
    #expect(entity.isValid)
    #expect(entity.timestamp != nil)
}
```

### 2. Protocol Testing with Mocks
```swift
@Test("Repository should handle sync correctly")
func testRepositorySync() async throws {
    let mockRepo = MockSyncRepository()
    let useCase = SyncUseCase(repository: mockRepo)
    
    let result = try await useCase.startSync()
    #expect(result.isSuccess)
}
```

### 3. Async Operation Testing
```swift
@Test("Sync operation should complete successfully")
func testAsyncSync() async throws {
    let syncManager = SyncManager()
    let expectation = expectation(description: "Sync completion")
    
    try await syncManager.startSync()
    #expect(syncManager.status == .completed)
}
```

### 4. Error Handling Testing
```swift
@Test("Should handle network errors gracefully")
func testNetworkErrorHandling() async throws {
    let client = NetworkClient()
    
    await #expect(throws: NetworkError.connectionFailed) {
        try await client.request(invalidURL)
    }
}
```

## Mock Strategy

### Core Mocks Needed:
1. **MockSupabaseClient** - Network layer mocking
2. **MockKeychainService** - Secure storage mocking
3. **MockNetworkMonitor** - Connectivity state mocking
4. **MockSyncRepository** - Data repository mocking
5. **MockConflictResolver** - Conflict resolution mocking

### Mock Implementation Pattern:
```swift
protocol MockProtocol {
    var callHistory: [String] { get }
    var shouldFail: Bool { get set }
    var mockResponse: Any? { get set }
}
```

## Environment Setup

### macOS Development Environment:
1. **Xcode 15.0+** with Swift 6.0+ support
2. **Swift Package Manager** for dependency management
3. **Swift Testing** framework integration
4. **Continuous Integration** with GitHub Actions

### Linux Testing Environment:
- Some Combine-dependent components may need conditional compilation
- Focus on core business logic that doesn't depend on platform-specific frameworks

## Test Execution

### Local Testing:
```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter SwiftSupabaseSyncTests

# Run with verbose output
swift test --verbose
```

### CI/CD Integration:
- Automated testing on PR creation
- Performance regression testing
- Code coverage reporting
- Cross-platform testing (macOS, iOS, Linux where applicable)

## Success Metrics

### Coverage Targets:
- **Tier 1 (Critical)**: 95%+ code coverage
- **Tier 2 (Important)**: 85%+ code coverage  
- **Tier 3 (Supporting)**: 70%+ code coverage

### Quality Gates:
- All tests must pass before merge
- No critical business logic without tests
- Performance tests must not regress
- Memory leaks must be addressed

## Next Steps

1. **Immediate**: Set up basic Swift Testing framework ✅
2. **Next**: Implement Tier 1 entity and protocol tests
3. **Then**: Add comprehensive use case testing
4. **Finally**: Complete infrastructure and integration tests

This systematic approach ensures that the most critical components are thoroughly tested first, providing a solid foundation for the entire SwiftSupabaseSync library.