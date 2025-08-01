# Data Services

Contains service layer components that handle data-specific operations and provide abstractions for data management tasks. These services bridge the gap between repositories and domain services.

## Files

### SyncChangeTracker.swift
Actor that tracks local changes for sync purposes with thread-safe operations. Manages pending inserts, updates, and deletes, provides change counting and querying capabilities, handles change clearing and cleanup operations, and supports batch change operations. Use this to track what data needs to be synchronized and manage the sync queue efficiently.