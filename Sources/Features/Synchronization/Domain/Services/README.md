# Domain Services

Contains service layer components that handle complex business logic and coordinate between different domain entities. These services encapsulate operations that don't naturally belong to a single entity.

## Files

### ResolutionHistoryManager.swift
Actor that manages the history and tracking of conflict resolution operations. Provides thread-safe storage for resolution records, history cleanup based on retention policies, analytics and reporting on resolution patterns, and pattern detection for automatic resolution strategies. Use this to track and analyze conflict resolution performance over time.

### SyncOperationManager.swift
Actor that manages concurrent sync operations and coordinates between different sync contexts. Handles operation queuing and prioritization, progress tracking and reporting, resource management and throttling, and concurrent operation coordination. Use this to orchestrate complex sync workflows and ensure optimal resource utilization.

### ValidationCacheManager.swift
Actor that provides caching functionality for subscription validation results. Manages cached validation data with TTL support, cache invalidation strategies, memory pressure handling, and hit rate optimization. Use this to improve performance of subscription validation checks and reduce network overhead.