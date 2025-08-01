# SwiftSupabaseSync Testing Guide

## Overview

This document provides a comprehensive testing strategy for all SwiftSupabaseSync components using Swift's new Testing framework. Tests are prioritized based on criticality, complexity, and dependency relationships.

## Testing Framework

- **Framework**: Swift Testing (Swift 6.0+)
- **Test Location**: `Tests/SwiftSupabaseSyncTests/`
- **Test Naming**: `[ComponentName]Tests.swift`
- **Test Running**: `swift test`

## Testing Priorities

### Priority 1: Core Foundation (Critical Infrastructure)

These components form the foundation of the system and must be thoroughly tested first:

#### 1.1 Core Entities & Types (Highest Priority)
- `SyncPolicy.swift` - Core synchronization policies and configurations
- `NetworkError.swift` - Network error handling and retry logic
- `SyncStatus.swift` - Synchronization state tracking
- `SharedTypes.swift` - Common type definitions
- `AuthenticationTypes.swift` - Authentication data structures

#### 1.2 Extensions & Utilities
- `ArrayExtensions.swift` - Array utility functions (chunked operations)
- `BatchOperationUtilities.swift` - Batch processing utilities

#### 1.3 Core Services
- `LoggingService.swift` - System logging and debugging
- `SubscriptionValidator.swift` - Subscription validation logic

### Priority 2: Domain Logic (Business Rules)

#### 2.1 Domain Protocols
- `Syncable.swift` - Core synchronization contract
- `ConflictResolvable.swift` - Conflict resolution interface
- `AuthRepositoryProtocol.swift` - Authentication repository contract
- `SyncRepositoryProtocol.swift` - Sync repository contract
- `SubscriptionValidating.swift` - Subscription validation contract

#### 2.2 Domain Services
- `ConflictResolvers.swift` - Conflict resolution algorithms
- `SyncOperationManager.swift` - Synchronization operation management
- `ResolutionHistoryManager.swift` - Conflict resolution history
- `ValidationCacheManager.swift` - Validation result caching

#### 2.3 Use Cases
- `AuthenticateUserUseCase.swift` - User authentication workflow
- `StartSyncUseCase.swift` - Sync initiation workflow
- `ResolveSyncConflictUseCase.swift` - Conflict resolution workflow
- `ValidateSubscriptionUseCase.swift` - Subscription validation workflow

### Priority 3: Data Layer (Persistence & Remote Access)

#### 3.1 Repository Implementations
- `SyncRepository.swift` - Main synchronization repository
- `AuthRepository.swift` - Authentication repository
- `ConflictRepository.swift` - Conflict data repository
- `SyncRepositoryError.swift` - Repository error handling

#### 3.2 Infrastructure Services
- `NetworkConfiguration.swift` - Network setup and configuration
- `RequestBuilder.swift` - HTTP request construction
- `KeychainService.swift` - Secure storage operations
- `LocalDataSource.swift` - Local data persistence (note: requires SwiftData)

#### 3.3 Data Models & Types
- `LocalDataSourceTypes.swift` - Local data type definitions
- `RealtimeProtocolTypes.swift` - Real-time communication types
- `ConflictTypes.swift` - Conflict data structures
- `SyncOperationTypes.swift` - Sync operation definitions
- `SyncRepositoryResultTypes.swift` - Repository result types
- `SyncSchemaTypes.swift` - Schema definition types

### Priority 4: Infrastructure & Integration

#### 4.1 Network Layer
- `Network.swift` - Core networking implementation
- `SupabaseClient.swift` - Supabase API client (note: requires Supabase dependency)
- `NetworkMonitor.swift` - Network connectivity monitoring (note: requires Combine)

#### 4.2 Data Sources
- `SupabaseAuthDataSource.swift` - Remote authentication data source
- `SupabaseDataDataSource.swift` - Remote data synchronization source
- `SupabaseRealtimeDataSource.swift` - Real-time data source (note: requires Combine)

#### 4.3 Advanced Services
- `SyncOperationsManager.swift` - Advanced sync operation management
- `SyncConflictResolutionService.swift` - Conflict resolution service
- `SyncIntegrityValidationService.swift` - Data integrity validation
- `SyncMetadataManager.swift` - Sync metadata management
- `SyncSchemaValidationService.swift` - Schema validation service

### Priority 5: Dependency Injection & Configuration

#### 5.1 DI Core
- `DICore.swift` - Dependency injection core implementation
- `ServiceLocator.swift` - Service location and resolution
- `RepositoryFactory.swift` - Repository creation and configuration
- `ConfigurationProvider.swift` - Configuration management
- `DependencyInjectionSetup.swift` - DI system setup

#### 5.2 Additional Services
- `SyncChangeTracker.swift` - Change tracking service

### Priority 6: Supporting Types & Entities

#### 6.1 Additional Domain Entities
- `User.swift` - User entity definition
- `RealtimeTypes.swift` - Real-time operation types
- `ConflictResolutionTypes.swift` - Conflict resolution type definitions
- `SubscriptionRecommendationTypes.swift` - Subscription recommendation types

#### 6.2 Main Entry Point
- `SwiftSupabaseSync.swift` - Main library interface

## Test Implementation Strategy

### Phase 1: Foundation Tests (Week 1)
Start with Priority 1 components:
1. `ArrayExtensionsTests.swift` - Simple utility testing
2. `NetworkErrorTests.swift` - Error handling and retry logic
3. `SyncPolicyTests.swift` - Complex entity with business logic
4. `LoggingServiceTests.swift` - Infrastructure service

### Phase 2: Domain Logic Tests (Week 2)
Focus on Priority 2 components:
1. Protocol conformance tests
2. Use case workflow tests
3. Business logic validation

### Phase 3: Data Layer Tests (Week 3)
Implement Priority 3 components:
1. Repository pattern tests
2. Data transformation tests
3. Error handling tests

### Phase 4: Integration Tests (Week 4)
Cover Priority 4 & 5 components:
1. Network integration tests
2. DI system tests
3. End-to-end workflow tests

## Test Patterns

### 1. Unit Tests
- Test individual functions and methods in isolation
- Use dependency injection for mocking external dependencies
- Focus on edge cases and error conditions

### 2. Integration Tests
- Test component interactions
- Validate data flow between layers
- Test error propagation

### 3. Mock Objects
- Create mock implementations for external dependencies
- Use protocol-based mocking for clean architecture
- Avoid testing external libraries (Supabase, Combine, SwiftData)

## Test Categories by Complexity

### Simple Tests (Good Starting Points)
- `ArrayExtensions.swift` - Pure functions, no dependencies
- `NetworkError.swift` - Enums and error handling
- `SharedTypes.swift` - Type definitions and basic logic

### Medium Complexity Tests
- `SyncPolicy.swift` - Business logic with multiple properties
- `LoggingService.swift` - Service with configuration
- Use case implementations

### Complex Tests (Require Mocks)
- Repository implementations
- Network-dependent services
- Services requiring external frameworks

## Dependencies to Mock

### External Dependencies (Not Available)
- **Supabase**: Mock all Supabase client interactions
- **Combine**: Mock Publisher/Subscriber patterns
- **SwiftData**: Mock data persistence operations

### Internal Dependencies
- Use dependency injection to provide test doubles
- Create protocol-based mocks for clean testing

## Testing Tools and Utilities

### Swift Testing Framework Features
- `@Test` attribute for test methods
- `#expect()` for assertions
- `@Suite` for test organization
- Async/await support for testing asynchronous code

### Custom Test Utilities
- Mock factories for common objects
- Test data builders
- Assertion helpers

## Continuous Integration

### Pre-commit Checks
- All tests must pass
- Code coverage targets
- Linting and formatting

### Test Performance
- Monitor test execution time
- Parallelize independent tests
- Use test tags for selective running

## Notes on Current Implementation

### Identified Issues
1. Missing external dependencies (Supabase, Combine, SwiftData)
2. Some files have compilation errors due to missing imports
3. README files scattered throughout source directories

### Recommended Approach
1. Start with dependency-free components
2. Create comprehensive mocks for external dependencies
3. Focus on business logic and core functionality
4. Add integration tests only after core tests are complete

This testing strategy ensures comprehensive coverage while maintaining focus on the most critical components first.