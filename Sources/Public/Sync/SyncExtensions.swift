//
//  SyncExtensions.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Foundation

// MARK: - Conversion Extensions

extension SyncAPI {
    
    /// Convert internal sync state to public status
    internal func convertToPublicStatus(_ internalStatus: SyncState) -> PublicSyncStatus {
        switch internalStatus {
        case .idle: return .idle
        case .preparing: return .preparing
        case .syncing: return .syncing
        case .paused: return .paused
        case .completed: return .completed
        case .failed: return .failed
        case .cancelled: return .cancelled
        }
    }
    
    /// Convert internal sync result to public result
    internal func convertToPublicResult(_ internalResult: SyncOperationResult) -> PublicSyncResult {
        let models = [internalResult.operation.entityType]
        let summary = internalResult.success 
            ? "Successfully synced \(internalResult.uploadedCount + internalResult.downloadedCount) items"
            : "Sync failed: \(internalResult.errors.first?.localizedDescription ?? "Unknown error")"
        
        return PublicSyncResult(
            success: internalResult.success,
            uploadedCount: internalResult.uploadedCount,
            downloadedCount: internalResult.downloadedCount,
            conflictCount: internalResult.conflictCount,
            duration: internalResult.duration,
            syncedModels: models,
            summary: summary,
            completedAt: internalResult.completedAt
        )
    }
    
    /// Convert generic error to public sync error
    internal func convertToPublicError(_ error: Error) -> SwiftSupabaseSyncError {
        if let syncError = error as? SyncError {
            switch syncError {
            case .networkUnavailable:
                return .networkUnavailable
            case .authenticationFailed:
                return .authenticationFailed(reason: .sessionExpired)
            case .serverError(let code):
                return .serverError(statusCode: code, message: "Server error")
            case .subscriptionRequired:
                return .subscriptionRequired(feature: .basicSync, currentTier: .free)
            case .unknownError(_):
                return .unknown(underlyingError: nil)
            default:
                return .unknown(underlyingError: syncError)
            }
        }
        
        return .unknown(underlyingError: error)
    }
    
    /// Convert internal conflict to public conflict info
    internal func convertToPublicConflict(_ internalConflict: SyncConflict) -> ConflictInfo {
        // This would convert internal SyncConflict to public ConflictInfo
        // The exact implementation depends on the SyncConflict structure
        return ConflictInfo(
            modelType: "unknown", // Would be extracted from conflict
            recordID: "unknown",  // Would be extracted from conflict
            localVersion: "local_data",   // Would be serialized from conflict
            remoteVersion: "remote_data", // Would be serialized from conflict
            resolutionStrategy: .askUser
        )
    }
    
    /// Convert public policy to internal policy
    internal func convertToInternalPolicy(_ publicPolicy: SyncPolicyConfiguration) -> SyncPolicy {
        let settings = publicPolicy.settings
        
        return SyncPolicy(
            name: "Public API Policy",
            frequency: convertToInternalFrequency(settings.syncFrequency),
            wifiOnly: settings.requiresWifi,
            allowBackgroundSync: true, // Default for public API
            enableRealtimeSync: true,  // Default for public API
            maxRetries: settings.retryAttempts,
            batchSize: settings.batchSize
        )
    }
    
    /// Convert public frequency to internal frequency
    internal func convertToInternalFrequency(_ publicFrequency: PublicSyncFrequency) -> SyncFrequency {
        switch publicFrequency {
        case .automatic: return .automatic
        case .manual: return .manual
        case .interval(let seconds): return .interval(seconds)
        }
    }
    
    /// Convert entity status to public operation info
    internal func convertToPublicOperationInfo(_ entityStatus: EntitySyncStatus, modelType: String) -> SyncOperationInfo {
        let type: PublicSyncOperationType = .incrementalSync // Default for entity status
        let status = convertToPublicOperationStatus(entityStatus.state)
        
        return SyncOperationInfo(
            id: UUID(), // Generate new ID since EntitySyncStatus doesn't have one
            type: type,
            models: [modelType],
            startTime: entityStatus.lastSyncAt ?? entityStatus.statusAt,
            status: status
        )
    }
    
    /// Convert sync operation to public operation info
    internal func convertToPublicOperationInfo(_ operation: SyncOperation) -> SyncOperationInfo {
        let type = convertToPublicOperationType(operation.type)
        let status = convertToPublicOperationStatus(operation.status)
        
        return SyncOperationInfo(
            id: operation.id,
            type: type,
            models: [operation.entityType],
            startTime: operation.startedAt ?? operation.createdAt,
            status: status
        )
    }
    
    /// Convert internal operation type to public type
    internal func convertToPublicOperationType(_ internalType: SyncOperationType) -> PublicSyncOperationType {
        switch internalType {
        case .fullSync: return .fullSync
        case .incrementalSync: return .incrementalSync
        case .upload: return .upload
        case .download: return .download
        }
    }
    
    /// Convert sync state to public operation status
    internal func convertToPublicOperationStatus(_ internalStatus: SyncState) -> PublicSyncOperationStatus {
        switch internalStatus {
        case .idle: return .pending
        case .preparing: return .pending
        case .syncing: return .running
        case .paused: return .paused
        case .completed: return .completed
        case .failed: return .failed
        case .cancelled: return .cancelled
        }
    }
    
    /// Convert operation status to public operation status
    internal func convertToPublicOperationStatus(_ internalStatus: SyncOperationStatus) -> PublicSyncOperationStatus {
        switch internalStatus {
        case .pending: return .pending
        case .running: return .running
        case .completed: return .completed
        case .failed: return .failed
        case .cancelled: return .cancelled
        }
    }
}

// MARK: - Utility Extensions

public extension SyncAPI {
    
    /// Check if sync can be started given current conditions
    /// - Returns: Whether sync is eligible to start
    func canStartSync() async -> Bool {
        guard authAPI.isAuthenticated else { return false }
        guard isSyncEnabled else { return false }
        guard !isSyncing else { return false }
        
        return true
    }
    
    /// Get a summary of current sync state
    /// - Returns: Human-readable sync summary
    func getSyncSummary() -> String {
        let statusText = status.rawValue.capitalized
        let modelsText = "\(registeredModels.count) models"
        let conflictsText = conflictCount > 0 ? ", \(conflictCount) conflicts" : ""
        let timeText = lastSyncTime.map { "Last sync: \(formatRelativeTime($0))" } ?? "Never synced"
        
        return "\(statusText) • \(modelsText)\(conflictsText) • \(timeText)"
    }
    
    /// Convenience method to start sync and wait for completion
    /// - Returns: Whether sync completed successfully
    @discardableResult
    func syncAndWait() async throws -> Bool {
        let result = try await startSync()
        return result.success
    }
    
    /// Convenience method to register multiple models by type
    /// - Parameter types: Variadic list of Syncable types to register
    func registerModels<T: Syncable>(_ types: T.Type...) {
        for type in types {
            registerModel(type)
        }
    }
    
    // Note: clearErrors() method moved to main SyncAPI.swift file to access private properties
    
    /// Get sync health status
    var syncHealthStatus: String {
        if !isSyncEnabled {
            return "🔴 Disabled"
        } else if status == .failed {
            return "🔴 Failed"
        } else if conflictCount > 0 {
            return "🟡 \(conflictCount) conflicts"
        } else if isSyncing {
            return "🟢 Syncing"
        } else if lastSyncTime != nil {
            return "🟢 Ready"
        } else {
            return "🟡 Not synced"
        }
    }
    
    /// Get last sync time formatted for display
    var lastSyncTimeFormatted: String? {
        guard let lastSyncTime = lastSyncTime else { return nil }
        return formatRelativeTime(lastSyncTime)
    }
}

// MARK: - Private Utility Methods

extension SyncAPI {
    
    /// Format relative time for display
    internal func formatRelativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}