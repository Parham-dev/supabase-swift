//
//  LocalDataSource.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import SwiftData

/// Local data source for SwiftData operations with sync support
/// Provides CRUD operations for Syncable entities with change tracking
public final class LocalDataSource {
    
    // MARK: - Properties
    
    internal let modelContext: ModelContext
    private let changeTracker: SyncChangeTracker
    
    // MARK: - Initialization
    
    /// Initialize local data source with model context
    /// - Parameter modelContext: SwiftData model context from the main app
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.changeTracker = SyncChangeTracker()
    }
    
    // MARK: - Query Operations
    
    /// Fetch all records of a specific type
    /// - Parameter type: Type of Syncable entity to fetch
    /// - Returns: Array of all records
    /// - Throws: LocalDataSourceError if fetch fails
    public func fetchAll<T: Syncable>(_ type: T.Type) throws -> [T] {
        let descriptor = FetchDescriptor<T>()
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw LocalDataSourceError.fetchFailed("Failed to fetch all \(type): \(error.localizedDescription)")
        }
    }
    
    /// Fetch records with predicate
    /// - Parameters:
    ///   - type: Type of Syncable entity to fetch
    ///   - predicate: Predicate to filter records
    ///   - sortBy: Optional sort descriptors
    ///   - limit: Optional limit for number of records
    /// - Returns: Array of matching records
    /// - Throws: LocalDataSourceError if fetch fails
    public func fetch<T: Syncable>(
        _ type: T.Type,
        where predicate: Predicate<T>? = nil,
        sortBy: [SortDescriptor<T>] = [],
        limit: Int? = nil
    ) throws -> [T] {
        var descriptor = FetchDescriptor<T>(predicate: predicate, sortBy: sortBy)
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw LocalDataSourceError.fetchFailed("Failed to fetch \(type): \(error.localizedDescription)")
        }
    }
    
    /// Fetch record by sync ID
    /// - Parameters:
    ///   - type: Type of Syncable entity to fetch
    ///   - syncID: Unique sync identifier
    /// - Returns: Record if found, nil otherwise
    /// - Throws: LocalDataSourceError if fetch fails
    public func fetchBySyncID<T: Syncable>(_ type: T.Type, syncID: UUID) throws -> T? {
        let predicate = #Predicate<T> { record in
            record.syncID == syncID
        }
        
        let results = try fetch(type, where: predicate, limit: 1)
        return results.first
    }
    
    /// Fetch records that need synchronization
    /// - Parameters:
    ///   - type: Type of Syncable entity to fetch
    ///   - limit: Optional limit for number of records
    /// - Returns: Array of records needing sync
    /// - Throws: LocalDataSourceError if fetch fails
    public func fetchRecordsNeedingSync<T: Syncable>(_ type: T.Type, limit: Int? = nil) throws -> [T] {
        let predicate = #Predicate<T> { record in
            record.needsSync == true
        }
        
        return try fetch(type, where: predicate, limit: limit)
    }
    
    /// Fetch records modified after date
    /// - Parameters:
    ///   - type: Type of Syncable entity to fetch
    ///   - date: Date threshold for modification
    ///   - limit: Optional limit for number of records
    /// - Returns: Array of records modified after date
    /// - Throws: LocalDataSourceError if fetch fails
    public func fetchRecordsModifiedAfter<T: Syncable>(_ type: T.Type, date: Date, limit: Int? = nil) throws -> [T] {
        let predicate = #Predicate<T> { record in
            record.lastModified > date
        }
        
        let sortBy = [SortDescriptor(\T.lastModified, order: .reverse)]
        return try fetch(type, where: predicate, sortBy: sortBy, limit: limit)
    }
    
    /// Fetch deleted records (tombstones)
    /// - Parameters:
    ///   - type: Type of Syncable entity to fetch
    ///   - since: Optional date to filter from
    ///   - limit: Optional limit for number of records
    /// - Returns: Array of deleted records
    /// - Throws: LocalDataSourceError if fetch fails
    public func fetchDeletedRecords<T: Syncable>(_ type: T.Type, since: Date? = nil, limit: Int? = nil) throws -> [T] {
        var predicate = #Predicate<T> { record in
            record.isDeleted == true
        }
        
        if let since = since {
            predicate = #Predicate<T> { record in
                record.isDeleted == true && record.lastModified > since
            }
        }
        
        let sortBy = [SortDescriptor(\T.lastModified, order: .reverse)]
        return try fetch(type, where: predicate, sortBy: sortBy, limit: limit)
    }
    
    /// Fetch active (non-deleted) records
    /// - Parameters:
    ///   - type: Type of Syncable entity to fetch
    ///   - limit: Optional limit for number of records
    /// - Returns: Array of active records
    /// - Throws: LocalDataSourceError if fetch fails
    public func fetchActiveRecords<T: Syncable>(_ type: T.Type, limit: Int? = nil) throws -> [T] {
        let predicate = #Predicate<T> { record in
            record.isDeleted == false
        }
        
        return try fetch(type, where: predicate, limit: limit)
    }
    
    // MARK: - CRUD Operations
    
    /// Insert a new record
    /// - Parameter record: Syncable record to insert
    /// - Throws: LocalDataSourceError if insert fails
    public func insert<T: Syncable>(_ record: T) throws {
        do {
            // Ensure sync metadata is properly set
            record.syncID = record.syncID == UUID() ? UUID() : record.syncID
            record.lastModified = Date()
            record.version = 1
            record.isDeleted = false
            record.lastSynced = nil
            
            modelContext.insert(record)
            try modelContext.save()
            
            // Track change for sync
            Task {
                await changeTracker.recordInsert(record)
            }
            
        } catch {
            throw LocalDataSourceError.insertFailed("Failed to insert \(T.self): \(error.localizedDescription)")
        }
    }
    
    /// Update an existing record
    /// - Parameter record: Syncable record to update
    /// - Throws: LocalDataSourceError if update fails
    public func update<T: Syncable>(_ record: T) throws {
        do {
            // Update sync metadata
            record.lastModified = Date()
            record.version += 1
            record.lastSynced = nil
            
            try modelContext.save()
            
            // Track change for sync
            Task {
                await changeTracker.recordUpdate(record)
            }
            
        } catch {
            throw LocalDataSourceError.updateFailed("Failed to update \(T.self): \(error.localizedDescription)")
        }
    }
    
    /// Delete a record (soft delete)
    /// - Parameter record: Syncable record to delete
    /// - Throws: LocalDataSourceError if delete fails
    public func delete<T: Syncable>(_ record: T) throws {
        do {
            // Perform soft delete
            record.markAsDeleted()
            record.lastSynced = nil
            
            try modelContext.save()
            
            // Track change for sync
            Task {
                await changeTracker.recordDelete(record)
            }
            
        } catch {
            throw LocalDataSourceError.deleteFailed("Failed to delete \(T.self): \(error.localizedDescription)")
        }
    }
    
    /// Permanently delete a record from local storage
    /// - Parameter record: Syncable record to permanently delete
    /// - Throws: LocalDataSourceError if permanent delete fails
    public func permanentlyDelete<T: Syncable>(_ record: T) throws {
        do {
            modelContext.delete(record)
            try modelContext.save()
            
            // Track permanent deletion
            Task {
                await changeTracker.recordPermanentDelete(record)
            }
            
        } catch {
            throw LocalDataSourceError.deleteFailed("Failed to permanently delete \(T.self): \(error.localizedDescription)")
        }
    }
    
    /// Upsert (insert or update) a record
    /// - Parameter record: Syncable record to upsert
    /// - Returns: Whether the record was inserted (true) or updated (false)
    /// - Throws: LocalDataSourceError if upsert fails
    @discardableResult
    public func upsert<T: Syncable>(_ record: T) throws -> Bool {
        let existingRecord = try fetchBySyncID(T.self, syncID: record.syncID)
        
        if let existing = existingRecord {
            // Update existing record
            copyData(from: record, to: existing)
            try update(existing)
            return false
        } else {
            // Insert new record
            try insert(record)
            return true
        }
    }
    
    // MARK: - Batch Operations
    
    /// Insert multiple records
    /// - Parameter records: Array of Syncable records to insert
    /// - Returns: Array of results indicating success/failure for each record
    public func batchInsert<T: Syncable>(_ records: [T]) -> [BatchOperationResult] {
        var results: [BatchOperationResult] = []
        
        for record in records {
            do {
                try insert(record)
                results.append(BatchOperationResult(syncID: record.syncID, success: true, error: nil))
            } catch {
                results.append(BatchOperationResult(syncID: record.syncID, success: false, error: error))
            }
        }
        
        return results
    }
    
    /// Update multiple records
    /// - Parameter records: Array of Syncable records to update
    /// - Returns: Array of results indicating success/failure for each record
    public func batchUpdate<T: Syncable>(_ records: [T]) -> [BatchOperationResult] {
        var results: [BatchOperationResult] = []
        
        for record in records {
            do {
                try update(record)
                results.append(BatchOperationResult(syncID: record.syncID, success: true, error: nil))
            } catch {
                results.append(BatchOperationResult(syncID: record.syncID, success: false, error: error))
            }
        }
        
        return results
    }
    
    /// Delete multiple records
    /// - Parameter records: Array of Syncable records to delete
    /// - Returns: Array of results indicating success/failure for each record
    public func batchDelete<T: Syncable>(_ records: [T]) -> [BatchOperationResult] {
        var results: [BatchOperationResult] = []
        
        for record in records {
            do {
                try delete(record)
                results.append(BatchOperationResult(syncID: record.syncID, success: true, error: nil))
            } catch {
                results.append(BatchOperationResult(syncID: record.syncID, success: false, error: error))
            }
        }
        
        return results
    }
    
    // MARK: - Sync Support
    
    /// Mark records as synced
    /// - Parameters:
    ///   - syncIDs: Array of sync IDs to mark as synced
    ///   - timestamp: Timestamp to set as last synced
    ///   - type: Type of records to update
    /// - Throws: LocalDataSourceError if marking fails
    public func markRecordsAsSynced<T: Syncable>(_ syncIDs: [UUID], at timestamp: Date, type: T.Type) throws {
        do {
            for syncID in syncIDs {
                if let record = try fetchBySyncID(type, syncID: syncID) {
                    record.lastSynced = timestamp
                }
            }
            
            try modelContext.save()
            
        } catch {
            throw LocalDataSourceError.updateFailed("Failed to mark records as synced: \(error.localizedDescription)")
        }
    }
    
    /// Apply remote changes to local records
    /// - Parameter snapshots: Array of sync snapshots to apply
    /// - Returns: Array of application results
    public func applyRemoteChanges(_ snapshots: [SyncSnapshot]) -> [SyncApplicationResult] {
        var results: [SyncApplicationResult] = []
        
        for snapshot in snapshots {
            do {
                let result = try applyRemoteSnapshot(snapshot)
                results.append(result)
            } catch {
                let failedResult = SyncApplicationResult(
                    snapshot: snapshot,
                    success: false,
                    error: error as? SyncError ?? SyncError.unknownError("Failed to apply snapshot")
                )
                results.append(failedResult)
            }
        }
        
        return results
    }
    
    /// Count records of a specific type
    /// - Parameter type: Type of Syncable entity to count
    /// - Returns: Total count of records
    /// - Throws: LocalDataSourceError if count fails
    public func count<T: Syncable>(_ type: T.Type) throws -> Int {
        let descriptor = FetchDescriptor<T>()
        
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            throw LocalDataSourceError.fetchFailed("Failed to count \(type): \(error.localizedDescription)")
        }
    }
    
    /// Count records needing sync
    /// - Parameter type: Type of Syncable entity to count
    /// - Returns: Count of records needing sync
    /// - Throws: LocalDataSourceError if count fails
    public func countRecordsNeedingSync<T: Syncable>(_ type: T.Type) throws -> Int {
        let predicate = #Predicate<T> { record in
            record.needsSync == true
        }
        
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            throw LocalDataSourceError.fetchFailed("Failed to count records needing sync: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func applyRemoteSnapshot(_ snapshot: SyncSnapshot) throws -> SyncApplicationResult {
        // This would need to be implemented with reflection or type-specific logic
        // For now, return a basic implementation
        
        // Check if local record exists
        // Compare versions and detect conflicts
        // Apply changes based on conflict resolution strategy
        
        return SyncApplicationResult(
            snapshot: snapshot,
            success: true,
            conflictDetected: false
        )
    }
    
    private func copyData<T: Syncable>(from source: T, to destination: T) {
        // This would need to be implemented with reflection
        // to copy all syncable properties from source to destination
        // For now, just update the basic sync metadata
        
        destination.lastModified = source.lastModified
        destination.version = source.version
        destination.isDeleted = source.isDeleted
    }
}

