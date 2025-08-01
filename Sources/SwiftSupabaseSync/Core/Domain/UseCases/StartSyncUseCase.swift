//
//  StartSyncUseCase.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Use case for initiating and managing synchronization operations
/// Orchestrates sync workflow, validation, and coordination
public protocol StartSyncUseCaseProtocol {
    
    /// Start full synchronization for all registered entity types
    /// - Parameters:
    ///   - user: User to sync for
    ///   - policy: Sync policy to apply
    /// - Returns: Full sync operation result
    func startFullSync(for user: User, using policy: SyncPolicy) async throws -> SyncOperationResult
    
    /// Start incremental synchronization for specific entity type
    /// - Parameters:
    ///   - entityType: Type of entity to sync
    ///   - user: User to sync for
    ///   - policy: Sync policy to apply
    /// - Returns: Incremental sync operation result
    func startIncrementalSync<T: Syncable>(
        for entityType: T.Type,
        user: User,
        using policy: SyncPolicy
    ) async throws -> SyncOperationResult
    
    /// Start synchronization for specific records
    /// - Parameters:
    ///   - records: Specific records to sync
    ///   - user: User to sync for
    ///   - policy: Sync policy to apply
    /// - Returns: Record sync operation result
    func startRecordSync<T: Syncable>(
        for records: [T],
        user: User,
        using policy: SyncPolicy
    ) async throws -> SyncOperationResult
    
    /// Check if sync can be started given current conditions
    /// - Parameters:
    ///   - user: User requesting sync
    ///   - policy: Sync policy to check against
    /// - Returns: Sync eligibility result
    func checkSyncEligibility(for user: User, using policy: SyncPolicy) async throws -> SyncEligibilityResult
    
    /// Cancel ongoing sync operation
    /// - Parameters:
    ///   - operationID: ID of operation to cancel
    ///   - user: User requesting cancellation
    /// - Returns: Cancellation result
    func cancelSync(operationID: UUID, for user: User) async throws -> SyncCancellationResult
    
    /// Get current sync status
    /// - Parameters:
    ///   - entityType: Optional entity type to get status for
    ///   - user: User to get status for
    /// - Returns: Current sync status
    func getSyncStatus<T: Syncable>(
        for entityType: T.Type?,
        user: User
    ) async throws -> SyncStatus
}

public struct StartSyncUseCase: StartSyncUseCaseProtocol {
    
    // MARK: - Dependencies
    
    private let syncRepository: SyncRepositoryProtocol
    private let subscriptionValidator: SubscriptionValidating
    private let authUseCase: AuthenticateUserUseCaseProtocol
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Configuration
    
    private let maxConcurrentSyncs: Int
    private let syncTimeout: TimeInterval
    
    // MARK: - State
    
    private let syncManager: SyncOperationManager
    private let syncQueue = DispatchQueue(label: "sync.operations", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init(
        syncRepository: SyncRepositoryProtocol,
        subscriptionValidator: SubscriptionValidating,
        authUseCase: AuthenticateUserUseCaseProtocol,
        logger: SyncLoggerProtocol? = nil,
        maxConcurrentSyncs: Int = 3,
        syncTimeout: TimeInterval = 300 // 5 minutes
    ) {
        self.syncRepository = syncRepository
        self.subscriptionValidator = subscriptionValidator
        self.authUseCase = authUseCase
        self.logger = logger
        self.maxConcurrentSyncs = maxConcurrentSyncs
        self.syncTimeout = syncTimeout
        self.syncManager = SyncOperationManager(maxConcurrentSyncs: maxConcurrentSyncs)
    }
    
    // MARK: - Public Methods
    
    public func startFullSync(for user: User, using policy: SyncPolicy) async throws -> SyncOperationResult {
        logger?.info("Starting full sync for user: \(user.id)")
        
        // Validate preconditions
        let eligibility = try await checkSyncEligibility(for: user, using: policy)
        guard eligibility.isEligible else {
            logger?.warning("Full sync not eligible: \(eligibility.reason?.localizedDescription ?? "Unknown")")
            return SyncOperationResult.failed(
                operation: SyncOperation(type: .fullSync, entityType: "all"),
                error: .subscriptionRequired
            )
        }
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid, let validUser = sessionResult.user else {
            throw SyncError.authenticationFailed
        }
        
        let operationID = UUID()
        let startTime = Date()
        
        do {
            // Create operation context
            let context = SyncOperationContext(
                id: operationID,
                type: .fullSync,
                entityType: "all",
                user: validUser,
                policy: policy,
                startedAt: startTime
            )
            
            // Register operation
            try await syncManager.registerOperation(context)
            
            // Perform full sync
            var totalUploaded = 0
            var totalDownloaded = 0
            var totalConflicts = 0
            var errors: [SyncError] = []
            
            // Get all registered entity types (placeholder - would be implemented)
            let entityTypes = ["User", "SyncStatus"] // In real implementation, this would come from registry
            
            for entityTypeName in entityTypes {
                do {
                    logger?.debug("Syncing entity type: \(entityTypeName)")
                    
                    // Perform sync for entity type (simplified)
                    let result = try await performEntitySync(
                        entityType: entityTypeName,
                        context: context
                    )
                    
                    totalUploaded += result.uploadedCount
                    totalDownloaded += result.downloadedCount
                    totalConflicts += result.conflictCount
                    
                } catch let error as SyncError {
                    errors.append(error)
                    logger?.error("Failed to sync \(entityTypeName): \(error)")
                }
            }
            
            // Unregister operation
            await syncManager.unregisterOperation(operationID)
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Create successful result
            let result = SyncOperationResult(
                operation: SyncOperation(
                    id: operationID,
                    type: .fullSync,
                    entityType: "all",
                    itemCount: totalUploaded + totalDownloaded,
                    startedAt: startTime,
                    completedAt: Date(),
                    status: errors.isEmpty ? .completed : .failed
                ),
                success: errors.isEmpty,
                uploadedCount: totalUploaded,
                downloadedCount: totalDownloaded,
                conflictCount: totalConflicts,
                duration: duration,
                errors: errors
            )
            
            logger?.info("Full sync completed for user: \(user.id), duration: \(duration)s")
            return result
            
        } catch {
            await syncManager.unregisterOperation(operationID)
            logger?.error("Full sync failed for user: \(user.id), error: \(error)")
            throw error
        }
    }
    
    public func startIncrementalSync<T: Syncable>(
        for entityType: T.Type,
        user: User,
        using policy: SyncPolicy
    ) async throws -> SyncOperationResult {
        logger?.info("Starting incremental sync for \(entityType) and user: \(user.id)")
        
        // Validate preconditions
        let eligibility = try await checkSyncEligibility(for: user, using: policy)
        guard eligibility.isEligible else {
            logger?.warning("Incremental sync not eligible: \(eligibility.reason?.localizedDescription ?? "Unknown")")
            return SyncOperationResult.failed(
                operation: SyncOperation(type: .incrementalSync, entityType: String(describing: entityType)),
                error: .subscriptionRequired
            )
        }
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid, let validUser = sessionResult.user else {
            throw SyncError.authenticationFailed
        }
        
        let operationID = UUID()
        let startTime = Date()
        let entityTypeName = String(describing: entityType)
        
        do {
            // Create operation context
            let context = SyncOperationContext(
                id: operationID,
                type: .incrementalSync,
                entityType: entityTypeName,
                user: validUser,
                policy: policy,
                startedAt: startTime
            )
            
            // Register operation
            try await syncManager.registerOperation(context)
            
            // Get last sync timestamp
            let lastSyncTime = try await syncRepository.getLastSyncTimestamp(for: entityType)
            let syncSince = lastSyncTime ?? Date.distantPast
            
            // Perform incremental sync
            let incrementalResult = try await syncRepository.performIncrementalSync(
                ofType: entityType,
                since: syncSince,
                using: policy
            )
            
            // Unregister operation
            await syncManager.unregisterOperation(operationID)
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Create result
            let result = SyncOperationResult(
                operation: SyncOperation(
                    id: operationID,
                    type: .incrementalSync,
                    entityType: entityTypeName,
                    itemCount: incrementalResult.uploadedChanges + incrementalResult.downloadedChanges,
                    startedAt: startTime,
                    completedAt: Date(),
                    status: incrementalResult.success ? .completed : .failed
                ),
                success: incrementalResult.success,
                uploadedCount: incrementalResult.uploadedChanges,
                downloadedCount: incrementalResult.downloadedChanges,
                conflictCount: incrementalResult.conflictCount,
                duration: duration,
                errors: incrementalResult.error != nil ? [incrementalResult.error!] : []
            )
            
            logger?.info("Incremental sync completed for \(entityType), duration: \(duration)s")
            return result
            
        } catch {
            await syncManager.unregisterOperation(operationID)
            logger?.error("Incremental sync failed for \(entityType): \(error)")
            throw error
        }
    }
    
    public func startRecordSync<T: Syncable>(
        for records: [T],
        user: User,
        using policy: SyncPolicy
    ) async throws -> SyncOperationResult {
        logger?.info("Starting record sync for \(records.count) records of type \(T.self)")
        
        // Validate preconditions
        let eligibility = try await checkSyncEligibility(for: user, using: policy)
        guard eligibility.isEligible else {
            return SyncOperationResult.failed(
                operation: SyncOperation(type: .upload, entityType: String(describing: T.self)),
                error: .subscriptionRequired
            )
        }
        
        let operationID = UUID()
        let startTime = Date()
        let entityTypeName = String(describing: T.self)
        
        do {
            // Create snapshots from records
            let snapshots = records.map { $0.createSyncSnapshot() }
            
            // Upload changes
            let uploadResults = try await syncRepository.uploadChanges(snapshots)
            
            let successfulUploads = uploadResults.filter { $0.success }
            let failedUploads = uploadResults.filter { !$0.success }
            
            let duration = Date().timeIntervalSince(startTime)
            
            // Create result
            let result = SyncOperationResult(
                operation: SyncOperation(
                    id: operationID,
                    type: .upload,
                    entityType: entityTypeName,
                    itemCount: records.count,
                    startedAt: startTime,
                    completedAt: Date(),
                    status: failedUploads.isEmpty ? .completed : .failed
                ),
                success: failedUploads.isEmpty,
                uploadedCount: successfulUploads.count,
                downloadedCount: 0,
                conflictCount: 0,
                duration: duration,
                errors: failedUploads.compactMap { $0.error }
            )
            
            logger?.info("Record sync completed: \(successfulUploads.count)/\(records.count) successful")
            return result
            
        } catch {
            logger?.error("Record sync failed: \(error)")
            throw error
        }
    }
    
    public func checkSyncEligibility(for user: User, using policy: SyncPolicy) async throws -> SyncEligibilityResult {
        logger?.debug("Checking sync eligibility for user: \(user.id)")
        
        // Check if policy is enabled
        guard policy.isEnabled else {
            return SyncEligibilityResult(
                isEligible: false,
                reason: .policyDisabled,
                recommendations: ["Enable sync policy in settings"]
            )
        }
        
        // Check user authentication
        guard user.isAuthenticated else {
            return SyncEligibilityResult(
                isEligible: false,
                reason: .notAuthenticated,
                recommendations: ["Sign in to enable sync"]
            )
        }
        
        // Check subscription for sync access
        let syncAccess = try await subscriptionValidator.validateSyncAccess(.fullSync, for: user)
        guard syncAccess.hasAccess else {
            return SyncEligibilityResult(
                isEligible: false,
                reason: .subscriptionRequired,
                recommendations: ["Upgrade to Pro subscription to enable sync"]
            )
        }
        
        // Check network conditions
        let networkConditions = await checkNetworkConditions()
        guard policy.isSyncAllowed(
            isWifi: networkConditions.isWifi,
            batteryLevel: networkConditions.batteryLevel,
            isBackground: networkConditions.isBackground
        ) else {
            return SyncEligibilityResult(
                isEligible: false,
                reason: .conditionsNotMet,
                recommendations: ["Check network connection and battery level"]
            )
        }
        
        // Check concurrent sync limit
        let activeSyncs = await syncManager.getActiveSyncCount()
        guard activeSyncs < maxConcurrentSyncs else {
            return SyncEligibilityResult(
                isEligible: false,
                reason: .tooManyConcurrentSyncs,
                recommendations: ["Wait for current sync operations to complete"]
            )
        }
        
        logger?.debug("Sync eligibility check passed for user: \(user.id)")
        return SyncEligibilityResult(isEligible: true)
    }
    
    public func cancelSync(operationID: UUID, for user: User) async throws -> SyncCancellationResult {
        logger?.info("Cancelling sync operation: \(operationID)")
        
        let result = await syncManager.cancelOperation(operationID)
        if result.success {
            logger?.info("Sync operation cancelled: \(operationID)")
        }
        return result
    }
    
    public func getSyncStatus<T: Syncable>(
        for entityType: T.Type?,
        user: User
    ) async throws -> SyncStatus {
        if let entityType = entityType {
            let entityStatus = try await syncRepository.getSyncStatus(for: entityType)
            
            return SyncStatus(
                state: entityStatus.state,
                totalItems: entityStatus.pendingCount,
                completedItems: 0,
                failedItems: 0,
                isConnected: true, // Would check actual connectivity
                lastError: entityStatus.lastError
            )
        } else {
            // Return overall sync status
            return SyncStatus(
                state: .idle,
                isConnected: true
            )
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func performEntitySync(
        entityType: String,
        context: SyncOperationContext
    ) async throws -> EntitySyncResult {
        // Simplified entity sync - in real implementation would be more complex
        logger?.debug("Performing sync for entity: \(entityType)")
        
        // Simulate sync operation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        return EntitySyncResult(
            entityType: entityType,
            uploadedCount: 5,
            downloadedCount: 3,
            conflictCount: 0
        )
    }
    
    private func checkNetworkConditions() async -> NetworkConditions {
        // In real implementation, would check actual network and system conditions
        return NetworkConditions(
            isWifi: true,
            batteryLevel: 0.8,
            isBackground: false
        )
    }
}

// MARK: - Supporting Types

public struct SyncOperationResult: Codable, Equatable {
    /// The sync operation that was performed
    public let operation: SyncOperation
    
    /// Whether the operation was successful
    public let success: Bool
    
    /// Number of records uploaded
    public let uploadedCount: Int
    
    /// Number of records downloaded
    public let downloadedCount: Int
    
    /// Number of conflicts detected
    public let conflictCount: Int
    
    /// Operation duration in seconds
    public let duration: TimeInterval
    
    /// Errors encountered during sync
    public let errors: [SyncError]
    
    /// Operation completion timestamp
    public let completedAt: Date
    
    public init(
        operation: SyncOperation,
        success: Bool,
        uploadedCount: Int = 0,
        downloadedCount: Int = 0,
        conflictCount: Int = 0,
        duration: TimeInterval = 0,
        errors: [SyncError] = [],
        completedAt: Date = Date()
    ) {
        self.operation = operation
        self.success = success
        self.uploadedCount = uploadedCount
        self.downloadedCount = downloadedCount
        self.conflictCount = conflictCount
        self.duration = duration
        self.errors = errors
        self.completedAt = completedAt
    }
    
    /// Create a failed operation result
    public static func failed(
        operation: SyncOperation,
        error: SyncError
    ) -> SyncOperationResult {
        return SyncOperationResult(
            operation: operation,
            success: false,
            errors: [error]
        )
    }
}

public struct SyncEligibilityResult: Codable, Equatable {
    /// Whether sync is eligible to start
    public let isEligible: Bool
    
    /// Reason for ineligibility (if applicable)
    public let reason: SyncIneligibilityReason?
    
    /// Recommendations to make sync eligible
    public let recommendations: [String]
    
    /// Check timestamp
    public let checkedAt: Date
    
    public init(
        isEligible: Bool,
        reason: SyncIneligibilityReason? = nil,
        recommendations: [String] = [],
        checkedAt: Date = Date()
    ) {
        self.isEligible = isEligible
        self.reason = reason
        self.recommendations = recommendations
        self.checkedAt = checkedAt
    }
}

public struct SyncCancellationResult: Codable, Equatable {
    /// Whether cancellation was successful
    public let success: Bool
    
    /// ID of cancelled operation
    public let operationID: UUID
    
    /// Cancellation timestamp
    public let cancelledAt: Date
    
    /// Error if cancellation failed
    public let error: SyncCancellationError?
    
    public init(
        success: Bool,
        operationID: UUID,
        cancelledAt: Date = Date(),
        error: SyncCancellationError? = nil
    ) {
        self.success = success
        self.operationID = operationID
        self.cancelledAt = cancelledAt
        self.error = error
    }
}

private struct SyncOperationContext {
    let id: UUID
    let type: SyncOperationType
    let entityType: String
    let user: User
    let policy: SyncPolicy
    let startedAt: Date
    var status: SyncOperationStatus
    
    init(
        id: UUID,
        type: SyncOperationType,
        entityType: String,
        user: User,
        policy: SyncPolicy,
        startedAt: Date,
        status: SyncOperationStatus = .running
    ) {
        self.id = id
        self.type = type
        self.entityType = entityType
        self.user = user
        self.policy = policy
        self.startedAt = startedAt
        self.status = status
    }
    
    func withStatus(_ newStatus: SyncOperationStatus) -> SyncOperationContext {
        SyncOperationContext(
            id: id,
            type: type,
            entityType: entityType,
            user: user,
            policy: policy,
            startedAt: startedAt,
            status: newStatus
        )
    }
}

private struct EntitySyncResult {
    let entityType: String
    let uploadedCount: Int
    let downloadedCount: Int
    let conflictCount: Int
}

private struct NetworkConditions {
    let isWifi: Bool
    let batteryLevel: Double
    let isBackground: Bool
}

// MARK: - Enums

public enum SyncIneligibilityReason: String, Codable, CaseIterable {
    case notAuthenticated = "not_authenticated"
    case subscriptionRequired = "subscription_required"
    case policyDisabled = "policy_disabled"
    case conditionsNotMet = "conditions_not_met"
    case tooManyConcurrentSyncs = "too_many_concurrent_syncs"
    case networkUnavailable = "network_unavailable"
    
    public var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .subscriptionRequired:
            return "Pro subscription required"
        case .policyDisabled:
            return "Sync policy is disabled"
        case .conditionsNotMet:
            return "Sync conditions not met"
        case .tooManyConcurrentSyncs:
            return "Too many concurrent sync operations"
        case .networkUnavailable:
            return "Network connection unavailable"
        }
    }
}

public enum SyncCancellationError: String, Codable, CaseIterable {
    case operationNotFound = "operation_not_found"
    case operationAlreadyCompleted = "operation_already_completed"
    case cancellationNotAllowed = "cancellation_not_allowed"
    
    public var localizedDescription: String {
        switch self {
        case .operationNotFound:
            return "Sync operation not found"
        case .operationAlreadyCompleted:
            return "Operation already completed"
        case .cancellationNotAllowed:
            return "Cancellation not allowed for this operation"
        }
    }
}

// MARK: - Sync Operation Manager

private actor SyncOperationManager {
    private var activeSyncOperations: [UUID: SyncOperationContext] = [:]
    private let maxConcurrentSyncs: Int
    
    init(maxConcurrentSyncs: Int) {
        self.maxConcurrentSyncs = maxConcurrentSyncs
    }
    
    func registerOperation(_ context: SyncOperationContext) throws {
        guard activeSyncOperations.count < maxConcurrentSyncs else {
            throw SyncError.rateLimitExceeded
        }
        activeSyncOperations[context.id] = context
    }
    
    func unregisterOperation(_ operationID: UUID) {
        activeSyncOperations.removeValue(forKey: operationID)
    }
    
    func getActiveSyncCount() -> Int {
        return activeSyncOperations.count
    }
    
    func cancelOperation(_ operationID: UUID) -> SyncCancellationResult {
        guard let context = activeSyncOperations[operationID] else {
            return SyncCancellationResult(
                success: false,
                operationID: operationID,
                error: .operationNotFound
            )
        }
        
        // Mark as cancelled
        activeSyncOperations[operationID] = context.withStatus(.cancelled)
        
        return SyncCancellationResult(
            success: true,
            operationID: operationID
        )
    }
}