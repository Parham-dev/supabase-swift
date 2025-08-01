# Domain Protocols

Defines the core interfaces and contracts that govern how different components interact within the synchronization system. These protocols ensure loose coupling and enable dependency inversion.

## Core Protocols

### Syncable.swift
Protocol that SwiftData models must conform to for synchronization capabilities. Provides sync metadata properties (syncID, lastModified, lastSynced, isDeleted, version), lifecycle hooks for sync events, conflict resolution helpers, and collection extensions for filtering syncable records. Implement this protocol on your SwiftData models to enable automatic synchronization.

### SyncRepositoryProtocol.swift
Protocol defining the data access layer for synchronization. Includes CRUD operations for syncable entities, batch sync operations, conflict management, schema compatibility checking, and transaction support. Implement this protocol to connect the domain layer with your data persistence layer (Core Data, SwiftData, etc.).

## Service Protocols

### AuthRepositoryProtocol.swift
Protocol defining the interface for authentication data operations. Includes sign in/up operations, token refresh, user management, and local storage operations. Also contains SyncLoggerProtocol for logging operations throughout the sync system.

### ConflictResolvable.swift
Protocol for implementing custom conflict resolution strategies. Provides methods for detecting conflicts, resolving with various strategies (auto/manual), validating resolutions, and filtering auto-resolvable conflicts. Use this to customize how data conflicts are handled during sync.

### SubscriptionValidating.swift
Protocol for validating user subscriptions and feature access. Includes methods for checking subscription status, validating feature access with batch support, managing subscription updates, and caching validation results. Implement this to integrate with your subscription backend or App Store subscriptions.