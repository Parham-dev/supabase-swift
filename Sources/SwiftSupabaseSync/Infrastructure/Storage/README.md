# Storage Infrastructure

Provides secure and efficient local storage services for sensitive data and application preferences. Abstracts platform-specific storage mechanisms with consistent interfaces.

## Files

### KeychainService.swift
Secure storage service for sensitive data using iOS Keychain. Provides encrypted storage for authentication tokens, API keys, encryption keys, and other sensitive information. Features include:
- Encrypted storage with device-only access
- Convenient methods for common auth tokens (access_token, refresh_token, user_session)
- Supabase configuration storage (URL, API key)
- Async/await support for non-blocking operations
- Mock implementation for testing
- Comprehensive error handling with recovery suggestions

Usage:
```swift
let keychain = KeychainService.shared
try await keychain.storeAccessToken("your_token_here")
let token = try await keychain.retrieveAccessToken()
```

### LocalDataSource.swift
Local data source for SwiftData operations with sync support. Provides CRUD operations for Syncable entities with automatic change tracking for synchronization. Features include:
- Full CRUD operations with sync metadata management
- Query operations with predicates and sorting
- Batch operations for performance
- Change tracking for sync purposes
- Soft delete support for tombstone records
- Sync status management (markAsSynced, needsSync queries)
- Integration with SwiftData ModelContext from main app

Usage:
```swift
let dataSource = LocalDataSource(modelContext: yourModelContext)
let records = try dataSource.fetchRecordsNeedingSync(MyModel.self)
try dataSource.insert(newRecord)
try dataSource.markRecordsAsSynced(syncedIDs, at: Date())
```

## Architecture

The storage layer follows the Repository pattern and provides:
- **Security**: Keychain integration for sensitive data with proper access controls
- **Performance**: Efficient SwiftData operations with batching support
- **Sync Support**: Built-in change tracking and sync metadata management
- **Testability**: Protocol-based design with mock implementations
- **Error Handling**: Comprehensive error types with descriptive messages

This module integrates with the main application's SwiftData schema and provides the local storage foundation for the sync engine.