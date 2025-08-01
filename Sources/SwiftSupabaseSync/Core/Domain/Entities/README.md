# Domain Entities

Contains the core business entities that represent the fundamental concepts of the synchronization system. These entities encapsulate business rules and maintain data integrity.

## Files

### User.swift
Represents a user in the system with authentication state, subscription information, and sync preferences. Includes authentication status tracking, token management, subscription tier validation, and feature access control. Use this entity to manage user sessions and check feature permissions.

### SyncStatus.swift
Tracks the current state of synchronization operations including progress, errors, and statistics. Provides real-time sync state (idle, syncing, paused, error, completed), operation counting, and error tracking. Use this to display sync status in UI and monitor sync health.

### SyncPolicy.swift
Defines configuration for how and when synchronization should occur. Includes predefined policies (Conservative, Balanced, Aggressive, Manual, Real-time), network requirements, battery constraints, and conflict resolution strategies. Use this to configure sync behavior based on user preferences or app requirements.

### SharedTypes.swift
Contains shared enumerations and types used across multiple entities. Includes `SyncFrequency` for sync timing configuration and `ConflictResolutionStrategy` for handling data conflicts. Import this when you need these common types without importing specific entities.