//
//  Syncable.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import SwiftData

/// Protocol that SwiftData models must conform to for synchronization
/// Provides the necessary metadata for tracking changes and sync state
public protocol Syncable: PersistentModel {
    
    // MARK: - Required Properties
    
    /// Unique identifier for synchronization across devices
    /// This should be consistent across all instances of the same record
    var syncID: UUID { get set }
    
    /// Timestamp when this record was last modified locally
    /// Updated automatically when the record changes
    var lastModified: Date { get set }
    
    /// Timestamp when this record was last successfully synced
    /// Updated by the sync engine after successful sync
    var lastSynced: Date? { get set }
    
    /// Whether this record has been deleted (soft delete)
    /// Used for tombstone records to sync deletions
    var isDeleted: Bool { get set }
    
    /// Version number for conflict resolution
    /// Incremented on each modification
    var version: Int { get set }
    
    // MARK: - Optional Properties with Default Implementation
    
    /// Hash of the record's content for change detection
    /// Automatically calculated from syncable properties
    var contentHash: String { get }
    
    /// Whether this record needs to be synced
    /// True when local changes haven't been synced yet
    var needsSync: Bool { get }
    
    /// The table name for this entity in the remote database
    /// Defaults to the type name
    static var tableName: String { get }
    
    /// Properties that should be included in sync operations
    /// Defaults to all stored properties except internal sync metadata
    static var syncableProperties: [String] { get }
    
    // MARK: - Sync Lifecycle Methods
    
    /// Called before the record is synced to the server
    /// Override to perform pre-sync validation or transformations
    func willSync()
    
    /// Called after the record is successfully synced
    /// Override to perform post-sync cleanup or notifications
    func didSync()
    
    /// Called when sync fails for this record
    /// Override to handle sync failures or implement retry logic
    func syncDidFail(error: SyncError)
    
    /// Called to prepare the record for conflict resolution
    /// Override to customize how conflicts are detected and resolved
    func prepareForConflictResolution() -> [String: Any]
    
    /// Called after conflict resolution is applied
    /// Override to perform cleanup after conflict resolution
    func didResolveConflict(resolution: SyncableConflictResolutionResult)
}

// MARK: - Default Implementations

public extension Syncable {
    
    /// Default table name based on type name
    static var tableName: String {
        return String(describing: self).lowercased()
    }
    
    /// Default syncable properties (excludes sync metadata)
    static var syncableProperties: [String] {
        // This would be implemented using reflection in a real implementation
        // For now, return empty array - concrete types should override
        return []
    }
    
    /// Content hash based on syncable properties
    var contentHash: String {
        // In a real implementation, this would use reflection
        // to get actual property values and create a hash
        // For now, use basic implementation
        let contentString = "\(syncID)-\(version)-\(lastModified.timeIntervalSince1970)"
        
        return contentString.sha256
    }
    
    /// Check if record needs sync
    var needsSync: Bool {
        guard !isDeleted else {
            // Deleted records need sync if they haven't been synced since deletion
            return lastSynced == nil || lastSynced! < lastModified
        }
        
        // Regular records need sync if never synced or modified since last sync
        return lastSynced == nil || lastSynced! < lastModified
    }
    
    /// Default implementation - override in concrete types if needed
    func willSync() {
        // Update modification timestamp
        lastModified = Date()
        version += 1
    }
    
    /// Default implementation - override in concrete types if needed
    func didSync() {
        // Update sync timestamp
        lastSynced = Date()
    }
    
    /// Default implementation - override in concrete types if needed
    func syncDidFail(error: SyncError) {
        // Log error or implement default retry logic
        print("Sync failed for \(Self.tableName) \(syncID): \(error.localizedDescription)")
    }
    
    /// Default conflict resolution data
    func prepareForConflictResolution() -> [String: Any] {
        return [
            "syncID": syncID.uuidString,
            "version": version,
            "lastModified": lastModified.timeIntervalSince1970,
            "contentHash": contentHash,
            "isDeleted": isDeleted
        ]
    }
    
    /// Default post-conflict resolution cleanup
    func didResolveConflict(resolution: SyncableConflictResolutionResult) {
        switch resolution {
        case .localWins:
            // Local version kept, update sync timestamp
            lastSynced = Date()
        case .remoteWins(let remoteData):
            // Remote version applied, update from remote data
            updateFromRemoteData(remoteData)
        case .merged(let mergedData):
            // Merged version applied
            updateFromRemoteData(mergedData)
        }
    }
    
    /// Helper method to update from remote data
    private func updateFromRemoteData(_ data: [String: Any]) {
        // This would be implemented using reflection in a real implementation
        // Concrete types should override if they need custom update logic
        if let timestamp = data["lastModified"] as? TimeInterval {
            lastModified = Date(timeIntervalSince1970: timestamp)
        }
        if let versionNum = data["version"] as? Int {
            version = versionNum
        }
        lastSynced = Date()
    }
}

// MARK: - Supporting Types

public enum SyncableConflictResolutionResult {
    case localWins
    case remoteWins([String: Any])
    case merged([String: Any])
}

// MARK: - Syncable Extensions for Common Operations

public extension Syncable {
    
    /// Mark record as deleted (soft delete)
    func markAsDeleted() {
        isDeleted = true
        lastModified = Date()
        version += 1
    }
    
    /// Check if record was modified after given date
    func wasModifiedAfter(_ date: Date) -> Bool {
        return lastModified > date
    }
    
    /// Check if record was synced after given date
    func wasSyncedAfter(_ date: Date) -> Bool {
        guard let syncDate = lastSynced else { return false }
        return syncDate > date
    }
    
    /// Get time since last sync
    var timeSinceLastSync: TimeInterval? {
        guard let syncDate = lastSynced else { return nil }
        return Date().timeIntervalSince(syncDate)
    }
    
    /// Get time since last modification
    var timeSinceLastModification: TimeInterval {
        return Date().timeIntervalSince(lastModified)
    }
    
    /// Check if record is newer than another record
    func isNewerThan(_ other: any Syncable) -> Bool {
        return lastModified > other.lastModified
    }
    
    /// Check if record has higher version than another record
    func hasHigherVersionThan(_ other: any Syncable) -> Bool {
        return version > other.version
    }
    
    /// Create a sync snapshot for conflict resolution
    func createSyncSnapshot() -> SyncSnapshot {
        return SyncSnapshot(
            syncID: syncID,
            tableName: Self.tableName,
            version: version,
            lastModified: lastModified,
            lastSynced: lastSynced,
            isDeleted: isDeleted,
            contentHash: contentHash,
            conflictData: prepareForConflictResolution()
        )
    }
}

// MARK: - Sync Snapshot

public struct SyncSnapshot: Codable, Equatable {
    public let syncID: UUID
    public let tableName: String
    public let version: Int
    public let lastModified: Date
    public let lastSynced: Date?
    public let isDeleted: Bool
    public let contentHash: String
    public let conflictData: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case syncID = "sync_id"
        case tableName = "table_name"
        case version
        case lastModified = "last_modified"
        case lastSynced = "last_synced"
        case isDeleted = "is_deleted"
        case contentHash = "content_hash"
        case conflictData = "conflict_data"
    }
    
    public init(
        syncID: UUID,
        tableName: String,
        version: Int,
        lastModified: Date,
        lastSynced: Date?,
        isDeleted: Bool,
        contentHash: String,
        conflictData: [String: Any]
    ) {
        self.syncID = syncID
        self.tableName = tableName
        self.version = version
        self.lastModified = lastModified
        self.lastSynced = lastSynced
        self.isDeleted = isDeleted
        self.contentHash = contentHash
        self.conflictData = conflictData
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        syncID = try container.decode(UUID.self, forKey: .syncID)
        tableName = try container.decode(String.self, forKey: .tableName)
        version = try container.decode(Int.self, forKey: .version)
        lastModified = try container.decode(Date.self, forKey: .lastModified)
        lastSynced = try container.decodeIfPresent(Date.self, forKey: .lastSynced)
        isDeleted = try container.decode(Bool.self, forKey: .isDeleted)
        contentHash = try container.decode(String.self, forKey: .contentHash)
        
        // Decode conflict data as JSON
        if let jsonData = try container.decodeIfPresent(Data.self, forKey: .conflictData) {
            conflictData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] ?? [:]
        } else {
            conflictData = [:]
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(syncID, forKey: .syncID)
        try container.encode(tableName, forKey: .tableName)
        try container.encode(version, forKey: .version)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encodeIfPresent(lastSynced, forKey: .lastSynced)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(contentHash, forKey: .contentHash)
        
        // Encode conflict data as JSON
        let jsonData = try JSONSerialization.data(withJSONObject: conflictData)
        try container.encode(jsonData, forKey: .conflictData)
    }
    
    public static func == (lhs: SyncSnapshot, rhs: SyncSnapshot) -> Bool {
        return lhs.syncID == rhs.syncID &&
               lhs.version == rhs.version &&
               lhs.contentHash == rhs.contentHash
    }
}

// MARK: - String SHA256 Extension

private extension String {
    var sha256: String {
        // Simple hash implementation - in production would use CryptoKit
        return String(self.hash)
    }
}

// MARK: - Collection Extensions for Syncable

public extension Collection where Element: Syncable {
    
    /// Filter records that need synchronization
    func needingSync() -> [Element] {
        return self.filter { $0.needsSync }
    }
    
    /// Filter deleted records
    func deleted() -> [Element] {
        return self.filter { $0.isDeleted }
    }
    
    /// Filter active (non-deleted) records
    func active() -> [Element] {
        return self.filter { !$0.isDeleted }
    }
    
    /// Filter records modified after date
    func modifiedAfter(_ date: Date) -> [Element] {
        return self.filter { $0.wasModifiedAfter(date) }
    }
    
    /// Filter records synced after date
    func syncedAfter(_ date: Date) -> [Element] {
        return self.filter { $0.wasSyncedAfter(date) }
    }
    
    /// Get records that have never been synced
    func neverSynced() -> [Element] {
        return self.filter { $0.lastSynced == nil }
    }
    
    /// Sort by last modified date (newest first)
    func sortedByLastModified() -> [Element] {
        return self.sorted { $0.lastModified > $1.lastModified }
    }
    
    /// Sort by sync ID for consistent ordering
    func sortedBySyncID() -> [Element] {
        return self.sorted { $0.syncID.uuidString < $1.syncID.uuidString }
    }
    
    /// Create sync snapshots for all records
    func createSyncSnapshots() -> [SyncSnapshot] {
        return self.map { $0.createSyncSnapshot() }
    }
}