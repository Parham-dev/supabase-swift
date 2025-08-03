//
//  StartSyncUseCaseCore.swift
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
            
            // Get all registered entity types from the model registry
            let modelRegistry = await ModelRegistryService.shared
            let registeredModels = await modelRegistry.getAllRegistrations()
            let entityTypes = registeredModels.map { $0.tableName }
            
            logger?.info("Found \(entityTypes.count) registered entity types: \(entityTypes)")
            print("🔍 [StartSyncUseCase] Found \(entityTypes.count) registered entity types: \(entityTypes)")
            
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
        
        // Implementation would be similar to incremental sync but for specific records
        // This is a simplified placeholder
        return SyncOperationResult(
            operation: SyncOperation(type: .upload, entityType: String(describing: T.self)),
            success: true
        )
    }
    
    public func checkSyncEligibility(for user: User, using policy: SyncPolicy) async throws -> SyncEligibilityResult {
        // Check authentication
        guard user.isAuthenticated else {
            return .ineligible(reason: .notAuthenticated, recommendations: ["Please sign in to continue"])
        }
        
        // Check subscription
        let validation = try await subscriptionValidator.validateSubscription(for: user)
        guard validation.isValid else {
            return .ineligible(reason: .subscriptionRequired, recommendations: ["Upgrade to Pro subscription"])
        }
        
        // Check policy
        guard policy.isEnabled else {
            return .ineligible(reason: .policyDisabled, recommendations: ["Enable sync in policy settings"])
        }
        
        // Check concurrent operations
        let activeCount = await syncManager.getActiveSyncCount()
        guard activeCount < maxConcurrentSyncs else {
            return .ineligible(reason: .tooManyConcurrentSyncs, recommendations: ["Wait for current sync to complete"])
        }
        
        return .eligible
    }
    
    public func cancelSync(operationID: UUID, for user: User) async throws -> SyncCancellationResult {
        logger?.info("Cancelling sync operation: \(operationID) for user: \(user.id)")
        return await syncManager.cancelOperation(operationID)
    }
    
    public func getSyncStatus<T: Syncable>(
        for entityType: T.Type?,
        user: User
    ) async throws -> SyncStatus {
        // Implementation would get current sync status from repository
        // This is a simplified placeholder
        return SyncStatus(
            state: .idle,
            progress: 0.0
        )
    }
    
    // MARK: - Private Methods
    
    private func performEntitySync(
        entityType: String,
        context: SyncOperationContext
    ) async throws -> (uploadedCount: Int, downloadedCount: Int, conflictCount: Int) {
        // Simplified implementation - in reality this would delegate to the sync repository
        // and handle the specific entity type sync logic
        return (uploadedCount: 0, downloadedCount: 0, conflictCount: 0)
    }
}