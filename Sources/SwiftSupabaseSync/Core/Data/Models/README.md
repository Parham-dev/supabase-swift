# Data Models

Contains data transfer objects (DTOs), protocol types, and mapping logic for converting between different data representations. This separation ensures clean boundaries between external API formats and internal domain models.

## Files

### LocalDataSourceTypes.swift
Error types and result structures for local data source operations. Contains LocalDataSourceError for various failure scenarios and BatchOperationResult for tracking individual operation outcomes. Use these types when working with local data persistence and batch operations.

### RealtimeProtocolTypes.swift
Internal protocol message types for real-time communication. Contains RealtimeSubscription for subscription management and RealtimeMessage for WebSocket protocol communication. These are internal types used by the real-time data source implementation.

## Subdirectories

### DTOs/
External data formats and transfer objects for API communication.

### Mappers/
Conversion logic for transforming between different data representations.