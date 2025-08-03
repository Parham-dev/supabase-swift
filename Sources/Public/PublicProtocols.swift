//
//  PublicProtocols.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import SwiftData

// MARK: - Core Public Protocols

/// Public interface for models that can be synchronized with Supabase
/// Simplified version of the internal Syncable protocol for public API
public protocol SwiftSupabaseSyncable: PersistentModel {
    
    // MARK: - Required Sync Properties
    
    /// Unique identifier for synchronization across devices
    var syncID: UUID { get set }
    
    /// Timestamp when this record was last modified locally
    var lastModified: Date { get set }
    
    /// Whether this record has been deleted (soft delete)
    var isDeleted: Bool { get set }
    
    // MARK: - Computed Properties
    
    /// Whether this record needs to be synced
    var needsSync: Bool { get }
    
    /// The table name for this entity in the remote database
    static var tableName: String { get }
    
    // MARK: - Lifecycle Hooks (Optional)
    
    /// Called before the record is synced (optional override)
    func willSync()
    
    /// Called after successful sync (optional override)  
    func didSync()
    
    /// Called when sync fails (optional override)
    func syncDidFail(with error: SwiftSupabaseSyncError)
}

/// Public interface for custom conflict resolution strategies
/// Simplified version for external implementations
public protocol ConflictResolver {
    
    /// Resolve a conflict between local and remote versions
    /// - Parameters:
    ///   - local: Local version data
    ///   - remote: Remote version data
    ///   - modelType: Type of model being resolved
    /// - Returns: Resolution indicating which version to keep
    func resolveConflict(
        local: [String: Any],
        remote: [String: Any],
        modelType: String
    ) async -> PublicConflictResolution
    
    /// Check if this resolver can handle the given model type
    /// - Parameter modelType: Model type name
    /// - Returns: True if this resolver can handle the model
    func canResolve(modelType: String) -> Bool
}

/// Public interface for subscription and feature validation
/// Simplified version for external validation services
public protocol SubscriptionProvider {
    
    /// Validate if user has access to a feature
    /// - Parameters:
    ///   - feature: Feature to validate
    ///   - userID: User requesting access
    /// - Returns: Whether access is granted
    func hasAccess(to feature: SyncFeature, for userID: UUID) async -> Bool
    
    /// Get user's current subscription tier
    /// - Parameter userID: User ID
    /// - Returns: Current subscription tier
    func getSubscriptionTier(for userID: UUID) async -> PublicSubscriptionTier
    
    /// Check if user can perform sync operation
    /// - Parameters:
    ///   - operation: Type of sync operation
    ///   - userID: User requesting sync
    /// - Returns: Whether sync is allowed
    func canSync(operation: PublicSyncOperation, for userID: UUID) async -> Bool
}

/// Public interface for sync event monitoring
/// Allows apps to monitor and respond to sync events
public protocol SyncEventObserver: AnyObject {
    
    /// Called when sync starts
    /// - Parameter operation: Details of the sync operation
    func syncDidStart(_ operation: SyncOperationInfo)
    
    /// Called during sync to report progress
    /// - Parameters:
    ///   - operation: Sync operation details
    ///   - progress: Progress percentage (0.0 to 1.0)
    func syncProgressUpdated(_ operation: SyncOperationInfo, progress: Double)
    
    /// Called when sync completes successfully
    /// - Parameter operation: Completed sync operation details
    func syncDidComplete(_ operation: SyncOperationInfo)
    
    /// Called when sync fails
    /// - Parameters:
    ///   - operation: Failed sync operation details
    ///   - error: Error that caused the failure
    func syncDidFail(_ operation: SyncOperationInfo, error: SwiftSupabaseSyncError)
    
    /// Called when conflicts are detected
    /// - Parameters:
    ///   - conflicts: Array of conflicts found
    ///   - operation: Sync operation that detected conflicts
    func conflictsDetected(_ conflicts: [ConflictInfo], in operation: SyncOperationInfo)
}

/// Public interface for authentication state monitoring
/// Allows apps to respond to authentication changes
public protocol AuthenticationObserver: AnyObject {
    
    /// Called when user signs in
    /// - Parameter user: Authenticated user information
    func userDidSignIn(_ user: UserInfo)
    
    /// Called when user signs out
    func userDidSignOut()
    
    /// Called when authentication token is refreshed
    /// - Parameter user: Updated user information
    func authenticationDidRefresh(for user: UserInfo)
    
    /// Called when authentication fails
    /// - Parameter error: Authentication error
    func authenticationDidFail(with error: PublicAuthenticationError)
}

/// Public interface for network state monitoring
/// Allows apps to respond to connectivity changes
public protocol NetworkObserver: AnyObject {
    
    /// Called when network connectivity changes
    /// - Parameter isConnected: Whether device is connected to network
    func networkConnectivityChanged(isConnected: Bool)
    
    /// Called when network quality changes
    /// - Parameter quality: Current network quality assessment
    func networkQualityChanged(_ quality: PublicNetworkQuality)
    
    /// Called when sync suitability changes based on network conditions
    /// - Parameter suitable: Whether current network is suitable for sync
    func syncSuitabilityChanged(isSuitable: Bool)
}

// MARK: - Configuration Protocols

/// Protocol for providing custom sync policies
public protocol SyncPolicyProvider {
    
    /// Get sync policy for a specific model type
    /// - Parameter modelType: Model type name
    /// - Returns: Sync policy to use for this model
    func syncPolicy(for modelType: String) -> SyncPolicyConfiguration
    
    /// Get sync frequency based on current conditions
    /// - Parameters:
    ///   - networkQuality: Current network quality
    ///   - batteryLevel: Current battery level (0.0 to 1.0)
    ///   - userActive: Whether user is actively using the app
    /// - Returns: Recommended sync frequency
    func syncFrequency(
        networkQuality: PublicNetworkQuality,
        batteryLevel: Double,
        userActive: Bool
    ) -> PublicSyncFrequency
}

/// Protocol for custom logging implementations
public protocol LoggingProvider {
    
    /// Log a message at the specified level
    /// - Parameters:
    ///   - level: Log level
    ///   - message: Message to log
    ///   - category: Log category/component
    func log(level: PublicLogLevel, message: String, category: String)
    
    /// Log an error with context
    /// - Parameters:
    ///   - error: Error to log
    ///   - context: Additional context information
    ///   - category: Log category/component
    func logError(_ error: Error, context: [String: Any]?, category: String)
}

// MARK: - Default Implementations

public extension SwiftSupabaseSyncable {
    
    /// Default table name based on type name
    static var tableName: String {
        return String(describing: self).lowercased()
    }
    
    /// Default needs sync check
    var needsSync: Bool {
        // Simple implementation - override for custom logic
        return true
    }
    
    /// Default pre-sync preparation
    func willSync() {
        lastModified = Date()
    }
    
    /// Default post-sync cleanup
    func didSync() {
        // Override in concrete types if needed
    }
    
    /// Default sync failure handling
    func syncDidFail(with error: SwiftSupabaseSyncError) {
        // Override in concrete types for custom error handling
        print("Sync failed for \(Self.tableName): \(error.localizedDescription)")
    }
}

public extension ConflictResolver {
    
    /// Default implementation can resolve any model type
    func canResolve(modelType: String) -> Bool {
        return true
    }
}

public extension SyncPolicyProvider {
    
    /// Default sync policy for all models
    func syncPolicy(for modelType: String) -> SyncPolicyConfiguration {
        return .balanced
    }
    
    /// Default sync frequency based on conditions
    func syncFrequency(
        networkQuality: PublicNetworkQuality,
        batteryLevel: Double,
        userActive: Bool
    ) -> PublicSyncFrequency {
        // Conservative approach by default
        switch networkQuality {
        case .excellent, .good:
            return userActive ? .automatic : .interval(300)
        case .poor:
            return .interval(900)
        case .offline:
            return .manual
        }
    }
}

// MARK: - Observer Registration

/// Protocol for managing observer registrations
public protocol ObserverManager {
    
    /// Add a sync event observer
    /// - Parameter observer: Observer to add
    func addSyncObserver(_ observer: SyncEventObserver)
    
    /// Remove a sync event observer
    /// - Parameter observer: Observer to remove
    func removeSyncObserver(_ observer: SyncEventObserver)
    
    /// Add an authentication observer
    /// - Parameter observer: Observer to add
    func addAuthObserver(_ observer: AuthenticationObserver)
    
    /// Remove an authentication observer
    /// - Parameter observer: Observer to remove
    func removeAuthObserver(_ observer: AuthenticationObserver)
    
    /// Add a network observer
    /// - Parameter observer: Observer to add
    func addNetworkObserver(_ observer: NetworkObserver)
    
    /// Remove a network observer
    /// - Parameter observer: Observer to remove
    func removeNetworkObserver(_ observer: NetworkObserver)
}
