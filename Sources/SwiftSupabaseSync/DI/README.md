# Dependency Injection

Manages object creation and dependency resolution using a lightweight dependency injection container. Promotes loose coupling and enables easy testing through dependency inversion.

## Architecture

The DI system follows SOLID principles and Clean Architecture patterns:

- **DICore.swift**: Core DI container, service lifetimes, and error handling
- **ServiceLocator.swift**: Global service locator with property wrappers
- **RepositoryFactory.swift**: Factory for creating repositories and use cases
- **ConfigurationProvider.swift**: Environment-specific configuration management
- **DependencyInjectionSetup.swift**: Main setup and integration class

## Key Features

- **Service Lifetimes**: Singleton, scoped, and transient service management
- **Thread Safety**: Concurrent access protection with locks
- **Configuration**: Environment-specific settings (dev, staging, production, testing)
- **Property Wrappers**: `@Inject`, `@InjectOptional`, `@InjectScoped` for clean dependency injection
- **Factory Pattern**: Centralized repository and use case creation
- **Testing Support**: Easy mock service registration for unit tests

## Usage

### Quick Setup
```swift
try setupDependencyInjection(
    supabaseURL: "your-url",
    supabaseAnonKey: "your-key",
    environment: .development
)
```

### Property Wrapper Injection
```swift
class MyService {
    @Inject private var authRepository: AuthRepositoryProtocol
    @InjectOptional private var logger: SyncLoggerProtocol?
}
```

### Manual Resolution
```swift
let authUseCase = try resolve(AuthenticateUserUseCaseProtocol.self)
```