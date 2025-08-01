# Synchronization Feature

Core synchronization engine that handles bidirectional data sync between local SwiftData models and remote Supabase database. Manages conflict resolution, change tracking, and sync state.

Organized with Domain (sync logic and conflict resolution), Data (sync queue and change history), and Presentation (sync manager for coordinating sync operations).