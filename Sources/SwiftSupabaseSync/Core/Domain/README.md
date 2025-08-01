# Domain Layer

This layer contains the core business logic and entities of the SwiftSupabaseSync package. It defines the fundamental concepts and rules that govern synchronization between local SwiftData models and remote Supabase data.

The Domain layer is completely independent of external frameworks and implementation details, ensuring that business logic remains pure and testable. It serves as the foundation upon which all other layers build.

## Structure

### Entities/
Core business objects that encapsulate data and business rules:
- **User**: Authentication state and subscription management
- **SyncStatus**: Real-time synchronization state tracking
- **SyncPolicy**: Configuration for sync behavior and constraints
- **SharedTypes**: Common enumerations used across entities

### Protocols/
Interfaces that define contracts for system components:
- **Syncable**: Protocol for SwiftData models to enable synchronization
- **SubscriptionValidating**: Interface for subscription and feature validation
- **ConflictResolvable**: Contract for implementing conflict resolution strategies
- **SyncRepositoryProtocol**: Data access layer abstraction

### UseCases/
Application-specific business logic orchestration:
- **AuthenticateUserUseCase**: User authentication workflows
- **StartSyncUseCase**: Synchronization operation management
- **ValidateSubscriptionUseCase**: Feature access control and validation
- **ResolveSyncConflictUseCase**: Conflict detection and resolution

## Key Design Principles

- **Independence**: No dependencies on external frameworks or UI concerns
- **Testability**: All components are easily unit testable with clear interfaces
- **Thread Safety**: Actor-based state management for concurrent operations
- **Error Handling**: Comprehensive error types with recovery strategies
- **Clean Architecture**: Strict separation of concerns and dependency inversion