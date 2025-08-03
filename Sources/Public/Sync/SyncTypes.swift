//
//  SyncTypes.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Foundation
import Combine

// MARK: - Sync Status Types

/// Public sync status enumeration for API consumers
public enum PublicSyncStatus: String, CaseIterable, Sendable {
    case idle = "idle"
    case preparing = "preparing"
    case syncing = "syncing"
    case paused = "paused"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    /// Whether sync is currently active
    public var isActive: Bool {
        switch self {
        case .preparing, .syncing: return true
        case .idle, .paused, .completed, .failed, .cancelled: return false
        }
    }
    
    /// Whether sync can be resumed
    public var canResume: Bool {
        switch self {
        case .paused, .failed: return true
        case .idle, .preparing, .syncing, .completed, .cancelled: return false
        }
    }
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .idle: return "Ready"
        case .preparing: return "Preparing"
        case .syncing: return "Syncing"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}

// MARK: - Sync Result Types

/// Public sync operation result for API consumers
public struct PublicSyncResult: Sendable {
    
    /// Whether the sync operation was successful
    public let success: Bool
    
    /// Number of records uploaded to server
    public let uploadedCount: Int
    
    /// Number of records downloaded from server
    public let downloadedCount: Int
    
    /// Number of conflicts encountered
    public let conflictCount: Int
    
    /// Operation duration in seconds
    public let duration: TimeInterval
    
    /// List of models that were synced
    public let syncedModels: [String]
    
    /// Human-readable summary of the operation
    public let summary: String
    
    /// When the operation completed
    public let completedAt: Date
    
    public init(
        success: Bool,
        uploadedCount: Int = 0,
        downloadedCount: Int = 0,
        conflictCount: Int = 0,
        duration: TimeInterval = 0,
        syncedModels: [String] = [],
        summary: String = "",
        completedAt: Date = Date()
    ) {
        self.success = success
        self.uploadedCount = uploadedCount
        self.downloadedCount = downloadedCount
        self.conflictCount = conflictCount
        self.duration = duration
        self.syncedModels = syncedModels
        self.summary = summary
        self.completedAt = completedAt
    }
}

// MARK: - Sync Observer Protocol

/// Protocol for observing sync state changes
public protocol SyncObserver: AnyObject {
    /// Called when sync status changes
    func syncStatusDidChange(_ status: PublicSyncStatus)
    
    /// Called when sync progress updates
    func syncProgressDidUpdate(_ progress: Double)
    
    /// Called when sync operation completes
    func syncDidComplete(_ result: PublicSyncResult)
    
    /// Called when sync encounters an error
    func syncDidFail(_ error: SwiftSupabaseSyncError)
    
    /// Called when conflicts are detected
    func syncDidDetectConflicts(_ conflicts: [ConflictInfo])
}

// MARK: - Sync Result Extensions

public extension PublicSyncResult {
    
    /// Whether sync was successful
    var wasSuccessful: Bool {
        return success
    }
    
    /// Total number of records processed
    var totalRecordsProcessed: Int {
        return uploadedCount + downloadedCount
    }
    
    /// Whether conflicts were encountered
    var hasConflicts: Bool {
        return conflictCount > 0
    }
    
    /// Performance summary
    var performanceSummary: String {
        let recordsPerSecond = duration > 0 ? Double(totalRecordsProcessed) / duration : 0
        return String(format: "%.1f records/sec", recordsPerSecond)
    }
    
    /// Detailed result summary
    var detailedSummary: String {
        var parts: [String] = []
        
        if uploadedCount > 0 {
            parts.append("\(uploadedCount) uploaded")
        }
        
        if downloadedCount > 0 {
            parts.append("\(downloadedCount) downloaded")
        }
        
        if conflictCount > 0 {
            parts.append("\(conflictCount) conflicts")
        }
        
        let actions = parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
        let timeString = String(format: "%.2fs", duration)
        
        return "\(actions) in \(timeString)"
    }
    
    /// Create a success result
    static func success(
        uploadedCount: Int = 0,
        downloadedCount: Int = 0,
        conflictCount: Int = 0,
        duration: TimeInterval = 0,
        syncedModels: [String] = []
    ) -> PublicSyncResult {
        let total = uploadedCount + downloadedCount
        let summary = total > 0 ? "Successfully synced \(total) items" : "Sync completed with no changes"
        
        return PublicSyncResult(
            success: true,
            uploadedCount: uploadedCount,
            downloadedCount: downloadedCount,
            conflictCount: conflictCount,
            duration: duration,
            syncedModels: syncedModels,
            summary: summary
        )
    }
    
    /// Create a failure result
    static func failure(
        error: String,
        uploadedCount: Int = 0,
        downloadedCount: Int = 0,
        conflictCount: Int = 0,
        duration: TimeInterval = 0,
        syncedModels: [String] = []
    ) -> PublicSyncResult {
        return PublicSyncResult(
            success: false,
            uploadedCount: uploadedCount,
            downloadedCount: downloadedCount,
            conflictCount: conflictCount,
            duration: duration,
            syncedModels: syncedModels,
            summary: "Sync failed: \(error)"
        )
    }
}

// MARK: - Sync Status Extensions

public extension PublicSyncStatus {
    
    /// Whether sync is in an error state
    var isError: Bool {
        return self == .failed
    }
    
    /// Whether sync is in a terminal state (completed/failed/cancelled)
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        case .idle, .preparing, .syncing, .paused: return false
        }
    }
    
    /// Whether sync can be cancelled
    var canCancel: Bool {
        switch self {
        case .preparing, .syncing, .paused: return true
        case .idle, .completed, .failed, .cancelled: return false
        }
    }
    
    /// Status icon for UI display
    var icon: String {
        switch self {
        case .idle: return "⚪"
        case .preparing: return "🟡"
        case .syncing: return "🔄"
        case .paused: return "⏸️"
        case .completed: return "✅"
        case .failed: return "❌"
        case .cancelled: return "⏹️"
        }
    }
}