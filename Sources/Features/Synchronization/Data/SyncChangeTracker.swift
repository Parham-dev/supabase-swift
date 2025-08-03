//
//  SyncChangeTracker.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Sync Change Tracker

/// Actor that tracks local changes for sync purposes
/// Thread-safe tracking of pending inserts, updates, and deletes
internal actor SyncChangeTracker {
    
    // MARK: - Properties
    
    private var pendingInserts: Set<UUID> = []
    private var pendingUpdates: Set<UUID> = []
    private var pendingDeletes: Set<UUID> = []
    
    // MARK: - Change Recording
    
    /// Record a pending insert operation
    /// - Parameter record: Record that was inserted
    func recordInsert<T: Syncable>(_ record: T) {
        pendingInserts.insert(record.syncID)
    }
    
    /// Record a pending update operation
    /// - Parameter record: Record that was updated
    func recordUpdate<T: Syncable>(_ record: T) {
        pendingUpdates.insert(record.syncID)
    }
    
    /// Record a pending delete operation
    /// - Parameter record: Record that was deleted
    func recordDelete<T: Syncable>(_ record: T) {
        pendingDeletes.insert(record.syncID)
    }
    
    /// Record a permanent delete operation
    /// - Parameter record: Record that was permanently deleted
    /// - Note: Removes from all pending changes since record is gone
    func recordPermanentDelete<T: Syncable>(_ record: T) {
        pendingInserts.remove(record.syncID)
        pendingUpdates.remove(record.syncID)
        pendingDeletes.remove(record.syncID)
    }
    
    // MARK: - Change Retrieval
    
    /// Get all pending changes
    /// - Returns: Tuple of pending inserts, updates, and deletes
    func getPendingChanges() -> (inserts: Set<UUID>, updates: Set<UUID>, deletes: Set<UUID>) {
        return (pendingInserts, pendingUpdates, pendingDeletes)
    }
    
    /// Get count of all pending changes
    /// - Returns: Total number of pending changes
    func getPendingChangeCount() -> Int {
        return pendingInserts.count + pendingUpdates.count + pendingDeletes.count
    }
    
    /// Check if there are any pending changes
    /// - Returns: Whether there are pending changes
    func hasPendingChanges() -> Bool {
        return !pendingInserts.isEmpty || !pendingUpdates.isEmpty || !pendingDeletes.isEmpty
    }
    
    /// Check if a specific record has pending changes
    /// - Parameter syncID: Sync ID to check
    /// - Returns: Whether the record has pending changes
    func hasPendingChanges(for syncID: UUID) -> Bool {
        return pendingInserts.contains(syncID) || 
               pendingUpdates.contains(syncID) || 
               pendingDeletes.contains(syncID)
    }
    
    // MARK: - Change Clearing
    
    /// Clear pending changes for specific sync IDs
    /// - Parameter syncIDs: Array of sync IDs to clear
    func clearPendingChanges(syncIDs: [UUID]) {
        for syncID in syncIDs {
            pendingInserts.remove(syncID)
            pendingUpdates.remove(syncID)
            pendingDeletes.remove(syncID)
        }
    }
    
    /// Clear all pending changes
    func clearAllPendingChanges() {
        pendingInserts.removeAll()
        pendingUpdates.removeAll()
        pendingDeletes.removeAll()
    }
    
    /// Clear only pending inserts
    func clearPendingInserts() {
        pendingInserts.removeAll()
    }
    
    /// Clear only pending updates
    func clearPendingUpdates() {
        pendingUpdates.removeAll()
    }
    
    /// Clear only pending deletes
    func clearPendingDeletes() {
        pendingDeletes.removeAll()
    }
}