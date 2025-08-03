# Infrastructure

Provides low-level services and utilities that support the application's technical requirements. This layer contains cross-cutting concerns and foundational services used throughout the application.

## Structure

### Network/ (Implemented)
HTTP client and network services for Supabase API communication:
- **NetworkError**: Comprehensive error handling with retry logic
- **RequestBuilder**: Type-safe HTTP request construction
- **SupabaseClient**: Actor-based HTTP client with automatic retry
- **NetworkMonitor**: Real-time connectivity monitoring
- **NetworkConfiguration**: Environment configuration and service coordination

### Storage/ (Pending)
Secure persistence services for local data:
- Keychain integration for secure credential storage
- UserDefaults wrapper for app preferences
- SwiftData local storage management

### Logging/ (Pending)
Diagnostic and monitoring services:
- Structured logging with different levels
- Performance monitoring
- Error tracking and reporting

### Utils/ (Pending)
Common utilities and extensions:
- Date formatting helpers
- Cryptographic utilities
- Collection extensions

## Design Principles

- **Abstraction**: Hide implementation details behind clean interfaces
- **Reusability**: Components can be used across different features
- **Testability**: Easy to mock for unit testing
- **Performance**: Optimized for efficiency and minimal overhead
- **Security**: Secure storage and network communication