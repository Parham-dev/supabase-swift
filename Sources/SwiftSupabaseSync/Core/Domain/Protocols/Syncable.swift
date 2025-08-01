//
//  Syncable.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
// import CryptoKit
// import SwiftData

/// Protocol that models must conform to for synchronization
/// Provides the necessary metadata for tracking changes and sync state
/// Note: Temporarily simplified for Linux compatibility
public protocol Syncable {
    
    // MARK: - Required Properties
    
    /// Unique identifier for synchronization across devices
    var syncID: UUID { get set }
    
    /// Timestamp when this record was last modified locally
    var lastModified: Date { get set }
    
    /// Timestamp when this record was last successfully synced
    var lastSynced: Date? { get set }
    
    /// Whether this record has been deleted (soft delete)
    var isDeleted: Bool { get set }
    
    /// Version number for conflict resolution
    var version: Int { get set }
    
    // MARK: - Optional Properties with Default Implementation
    
    /// Hash of the record's content for change detection
    var contentHash: String { get }
    
    /// Whether this record needs to be synced
    var needsSync: Bool { get }
    
    /// The table name for this entity in the remote database
    static var tableName: String { get }
}

// MARK: - Default Implementations

public extension Syncable {
    
    /// Default table name based on type name
    static var tableName: String {
        return String(describing: self).lowercased()
    }
    
    /// Content hash based on syncable properties
    var contentHash: String {
        var components: [String] = []
        components.append("id:\(syncID.uuidString)")
        components.append("v:\(version)")
        components.append("mod:\(lastModified.timeIntervalSince1970)")
        components.append("del:\(isDeleted)")
        components.sort()
        
        let contentString = components.joined(separator:"|")
        return contentString.simpleHash
    }
    
    /// Check if record needs sync
    var needsSync: Bool {
        guard !isDeleted else {
            return lastSynced == nil || lastSynced! < lastModified
        }
        return lastSynced == nil || lastSynced! < lastModified
    }
}

// MARK: - Simple Hash Extension (replaces SHA256 for now)

private extension String {
    var simpleHash: String {
        return String(self.hashValue)
    }
}

// MARK: - Supporting Types

public enum SyncableConflictResolutionResult {
    case localWins
    case remoteWins([String: Any])
    case merged([String: Any])
}

// MARK: - Sync Snapshot (simplified version)

public struct SyncSnapshot: Codable, Equatable {
    public let syncID: UUID
    public let tableName: String
    public let version: Int
    public let lastModified: Date
    public let lastSynced: Date?
    public let isDeleted: Bool
    public let contentHash: String
    
    public init(
        syncID: UUID,
        tableName: String,
        version: Int,
        lastModified: Date,
        lastSynced: Date?,
        isDeleted: Bool,
        contentHash: String
    ) {
        self.syncID = syncID
        self.tableName = tableName
        self.version = version
        self.lastModified = lastModified
        self.lastSynced = lastSynced
        self.isDeleted = isDeleted
        self.contentHash = contentHash
    }
    
    public static func == (lhs: SyncSnapshot, rhs: SyncSnapshot) -> Bool {
        return lhs.syncID == rhs.syncID &&
               lhs.version == rhs.version &&
               lhs.contentHash == rhs.contentHash
    }
}