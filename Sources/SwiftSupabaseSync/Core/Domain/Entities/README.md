# Domain Entities

Contains the core business entities and supporting types that represent the fundamental concepts of the synchronization system. These entities encapsulate business rules and maintain data integrity.

## Core Entities

### User.swift
Represents a user in the system with authentication state, subscription information, and sync preferences. Includes authentication status tracking, token management, subscription tier validation, and feature access control. Use this entity to manage user sessions and check feature permissions.

### SyncStatus.swift
Tracks the current state of synchronization operations including progress, errors, and statistics. Provides real-time sync state (idle, syncing, paused, error, completed), operation counting, and error tracking. Use this to display sync status in UI and monitor sync health.

### SyncPolicy.swift
Defines configuration for how and when synchronization should occur. Includes predefined policies (Conservative, Balanced, Aggressive, Manual, Real-time), network requirements, battery constraints, and conflict resolution strategies. Use this to configure sync behavior based on user preferences or app requirements.

## Supporting Types

### AuthenticationTypes.swift
Result types and data structures for authentication operations. Contains AuthenticationResult, SignOutResult, SessionValidationResult, and AuthSessionData. Used by authentication use cases and repositories.

### ConflictTypes.swift
Core types for conflict detection and resolution. Contains SyncConflict, ConflictMetadata, and ConflictContext structures. Used throughout the conflict resolution system.

### ConflictResolutionTypes.swift
Types specific to conflict resolution workflows. Contains ConflictResolutionResult, ResolutionStrategy, and ConflictResolutionRecord. Used by conflict resolution use cases.

### RealtimeTypes.swift
Public types for real-time synchronization events. Contains RealtimeChangeEvent, RealtimeConnectionStatus, and event type enumerations. Used by real-time data sources and subscribers.

### SharedTypes.swift
Contains shared enumerations and types used across multiple entities. Includes `SyncFrequency` for sync timing configuration and `ConflictResolutionStrategy` for handling data conflicts. Import this when you need these common types without importing specific entities.

### SubscriptionRecommendationTypes.swift
Types for subscription upgrade recommendations. Contains SubscriptionRecommendation, RecommendationReason, and related enums. Used by subscription validation systems.

### SyncOperationTypes.swift
Result types for sync operations. Contains SyncOperationResult, SyncEligibilityResult, and operation context types. Used by sync use cases and managers.

### SyncRepositoryResultTypes.swift
Result and response types for repository operations. Contains SyncUploadResult, SyncDownloadResult, and SyncApplicationResult. Used by sync repositories and data sources.

### SyncSchemaTypes.swift
Types for schema management and validation. Contains SchemaDefinition, EntitySchema, and validation result types. Used by schema management systems.