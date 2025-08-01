# Use Cases

Contains the application-specific business logic that orchestrates domain entities and enforces business rules. Each use case represents a single business operation or workflow.

## Files

### AuthenticateUserUseCase.swift
Manages user authentication workflows including sign in, sign up, sign out, and token refresh. Features automatic token refresh before expiration, session validation, secure token storage, and integration with subscription validation. Use this to handle all authentication-related operations in your app.

### StartSyncUseCase.swift
Orchestrates synchronization operations including full sync, incremental sync, and record-specific sync. Features sync eligibility checking (network, battery, subscription), concurrent sync operation management via `SyncOperationManager`, progress tracking, and cancellation support. Use this to initiate and manage sync operations based on user actions or automatic triggers.

### ValidateSubscriptionUseCase.swift
Validates user subscriptions and manages feature access control. Features intelligent result caching via `ValidationCacheManager`, batch feature validation, subscription status refresh, usage limit checking, and subscription recommendations. Use this to gate premium features and enforce subscription limits throughout your app.

### ResolveSyncConflictUseCase.swift
Handles conflict detection and resolution during synchronization. Features automatic conflict resolution for simple cases, manual resolution workflow for complex conflicts, resolution history tracking via `ResolutionHistoryManager`, and batch conflict resolution. Use this to ensure data consistency when the same record is modified on multiple devices.