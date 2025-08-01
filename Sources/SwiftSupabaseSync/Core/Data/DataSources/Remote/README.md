# Remote Data Sources

Implements data access for Supabase services including authentication, database operations, and real-time subscriptions. These data sources handle network communication, error handling, and API response parsing.

## Files

### SupabaseAuthDataSource.swift
Complete authentication service for Supabase Auth integration. Handles user authentication workflows, session management, and secure token storage. Features include:
- Sign in/up with email and password
- OAuth provider authentication (Google, Apple, etc.)
- Session management with automatic token refresh
- Password reset and profile updates
- Secure token storage via KeychainService integration
- Session restoration from stored credentials
- Comprehensive error handling with user-friendly messages
- Mock implementation for testing

Usage:
```swift
let authDataSource = SupabaseAuthDataSource(supabaseClient: client)
let user = try await authDataSource.signIn(email: "user@example.com", password: "password")
let isAuthenticated = await authDataSource.isAuthenticated()
```

### SupabaseDataDataSource.swift
Database operations service for Supabase PostgreSQL integration. Provides CRUD operations, bulk sync capabilities, and conflict detection for Syncable entities. Features include:
- Full CRUD operations (insert, update, delete, fetch)
- Batch operations for performance (batch insert, update, upsert)
- Advanced querying with filters and pagination
- Conflict detection between local and remote records
- Schema introspection and table existence checks
- SyncSnapshot conversion for seamless sync integration
- Comprehensive PostgreSQL error handling
- Support for tombstone records (soft deletes)

Usage:
```swift
let dataSource = SupabaseDataDataSource(supabaseClient: client)
let snapshots = try await dataSource.fetchRecordsModifiedAfter(lastSyncDate, from: "todos")
let results = try await dataSource.batchUpsert(localSnapshots, into: "todos")
```

### SupabaseRealtimeDataSource.swift  
Real-time subscription service for Supabase Realtime integration. Enables live data synchronization and collaborative features with WebSocket-based change notifications. Features include:
- Table-specific change subscriptions (INSERT, UPDATE, DELETE)
- Record-level change monitoring
- Custom channel messaging for app-specific events
- Presence tracking for user status and collaboration
- Connection status monitoring with automatic reconnection
- Reactive programming with Combine publishers
- Comprehensive filtering and event routing
- ObservableObject integration for SwiftUI

Usage:
```swift
let realtimeSource = SupabaseRealtimeDataSource(supabaseClient: client)
try await realtimeSource.connect()

// Subscribe to table changes
let subscriptionId = try await realtimeSource.subscribeToTable("todos") { event in
    handleRealtimeChange(event)
}

// Monitor specific record
try await realtimeSource.subscribeToRecord(syncID: recordId, in: "todos")
```

## Architecture

The remote data sources follow a consistent pattern:
- **Protocol-Based Design**: Clean interfaces with mock implementations for testing
- **Error Handling**: Comprehensive error types with user-friendly messages and recovery suggestions
- **Async/Await**: Modern Swift concurrency for non-blocking operations
- **Reactive Programming**: Combine publishers for real-time updates and state management
- **Security**: Secure credential handling with keychain integration
- **Performance**: Batch operations and efficient querying for large datasets
- **Reliability**: Connection monitoring, retry logic, and graceful error recovery

These data sources provide the remote integration layer for the sync engine, enabling seamless communication with Supabase services while maintaining clean separation from business logic.