import Foundation

/// Use case for resolving synchronization conflicts
/// Orchestrates conflict detection, resolution, and application
public protocol ResolveSyncConflictUseCaseProtocol {
    
    /// Detect conflicts between local and remote data
    /// - Parameters:
    ///   - entityType: Type of entity to check for conflicts
    ///   - user: User to check conflicts for
    /// - Returns: Array of detected conflicts
    func detectConflicts<T: Syncable>(
        for entityType: T.Type,
        user: User
    ) async throws -> [SyncConflict]
    
    /// Resolve a single conflict using specified strategy
    /// - Parameters:
    ///   - conflict: The conflict to resolve
    ///   - strategy: Resolution strategy to use
    ///   - user: User requesting resolution
    /// - Returns: Conflict resolution result
    func resolveConflict(
        _ conflict: SyncConflict,
        using strategy: ConflictResolutionStrategy,
        for user: User
    ) async throws -> ConflictResolutionResult
    
    /// Resolve multiple conflicts in batch
    /// - Parameters:
    ///   - conflicts: Array of conflicts to resolve
    ///   - strategy: Resolution strategy to use for all conflicts
    ///   - user: User requesting resolution
    /// - Returns: Array of resolution results
    func resolveConflicts(
        _ conflicts: [SyncConflict],
        using strategy: ConflictResolutionStrategy,
        for user: User
    ) async throws -> [ConflictResolutionResult]
    
    /// Auto-resolve conflicts that don't require manual intervention
    /// - Parameters:
    ///   - entityType: Type of entity to auto-resolve conflicts for
    ///   - user: User to resolve conflicts for
    /// - Returns: Auto-resolution result
    func autoResolveConflicts<T: Syncable>(
        for entityType: T.Type,
        user: User
    ) async throws -> AutoResolutionResult
    
    /// Get conflicts requiring manual resolution
    /// - Parameters:
    ///   - entityType: Optional entity type to filter by
    ///   - user: User to get conflicts for
    /// - Returns: Array of conflicts needing manual resolution
    func getManualResolutionConflicts<T: Syncable>(
        for entityType: T.Type?,
        user: User
    ) async throws -> [SyncConflict]
    
    /// Apply custom resolution data to a conflict
    /// - Parameters:
    ///   - conflict: The conflict to resolve
    ///   - resolutionData: Custom resolution data
    ///   - user: User providing resolution
    /// - Returns: Custom resolution result
    func applyCustomResolution(
        to conflict: SyncConflict,
        with resolutionData: [String: Any],
        for user: User
    ) async throws -> ConflictResolutionResult
    
    /// Get conflict resolution history
    /// - Parameters:
    ///   - entityType: Optional entity type to filter by
    ///   - user: User to get history for
    ///   - limit: Maximum number of results
    /// - Returns: Array of historical resolutions
    func getResolutionHistory<T: Syncable>(
        for entityType: T.Type?,
        user: User,
        limit: Int?
    ) async throws -> [ConflictResolutionRecord]
}

public struct ResolveSyncConflictUseCase: ResolveSyncConflictUseCaseProtocol {
    
    // MARK: - Dependencies
    
    private let syncRepository: SyncRepositoryProtocol
    private let conflictResolver: ConflictResolvable
    private let authUseCase: AuthenticateUserUseCaseProtocol
    private let subscriptionUseCase: ValidateSubscriptionUseCaseProtocol
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Configuration
    
    private let maxBatchSize: Int
    private let conflictRetentionDays: Int
    private let autoResolutionEnabled: Bool
    
    // MARK: - State
    
    private let resolutionHistory: ResolutionHistoryManager
    private let historyQueue = DispatchQueue(label: "conflict.history", qos: .utility)
    
    // MARK: - Initialization
    
    public init(
        syncRepository: SyncRepositoryProtocol,
        conflictResolver: ConflictResolvable,
        authUseCase: AuthenticateUserUseCaseProtocol,
        subscriptionUseCase: ValidateSubscriptionUseCaseProtocol,
        logger: SyncLoggerProtocol? = nil,
        maxBatchSize: Int = 50,
        conflictRetentionDays: Int = 30,
        autoResolutionEnabled: Bool = true
    ) {
        self.syncRepository = syncRepository
        self.conflictResolver = conflictResolver
        self.authUseCase = authUseCase
        self.subscriptionUseCase = subscriptionUseCase
        self.logger = logger
        self.maxBatchSize = maxBatchSize
        self.conflictRetentionDays = conflictRetentionDays
        self.autoResolutionEnabled = autoResolutionEnabled
        self.resolutionHistory = ResolutionHistoryManager(retentionDays: conflictRetentionDays)
    }
    
    // MARK: - Public Methods
    
    public func detectConflicts<T: Syncable>(
        for entityType: T.Type,
        user: User
    ) async throws -> [SyncConflict] {
        logger?.debug("Detecting conflicts for \(entityType) and user: \(user.id)")
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid, let validUser = sessionResult.user else {
            throw SyncError.authenticationFailed
        }
        
        // Validate feature access
        let featureAccess = try await subscriptionUseCase.validateFeatureAccess(.conflictResolution, for: validUser)
        guard featureAccess.hasAccess else {
            throw SyncError.subscriptionRequired
        }
        
        // Get conflicts from repository
        let conflicts = try await syncRepository.getUnresolvedConflicts(
            ofType: entityType,
            limit: nil
        )
        
        logger?.info("Detected \(conflicts.count) conflicts for \(entityType)")
        return conflicts
    }
    
    public func resolveConflict(
        _ conflict: SyncConflict,
        using strategy: ConflictResolutionStrategy,
        for user: User
    ) async throws -> ConflictResolutionResult {
        logger?.info("Resolving conflict \(conflict.id) using \(strategy)")
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid, let validUser = sessionResult.user else {
            throw SyncError.authenticationFailed
        }
        
        // Validate feature access
        let featureAccess = try await subscriptionUseCase.validateFeatureAccess(.conflictResolution, for: validUser)
        guard featureAccess.hasAccess else {
            throw SyncError.subscriptionRequired
        }
        
        do {
            // Use the injected conflict resolver with strategy
            let strategyResolver = conflictResolver
            
            // Resolve the conflict
            let resolution = try await strategyResolver.resolveConflict(conflict)
            
            // Apply resolution
            let applicationResults = try await syncRepository.applyConflictResolutions([resolution])
            
            guard let applicationResult = applicationResults.first, applicationResult.success else {
                let error = applicationResults.first?.error ?? SyncError.unknownError("Resolution application failed")
                throw error
            }
            
            // Create resolution result
            let result = ConflictResolutionResult(
                conflict: conflict,
                resolution: resolution,
                success: true,
                appliedAt: Date(),
                resolvedBy: validUser.id
            )
            
            // Record in history
            await recordResolution(result)
            
            logger?.info("Conflict \(conflict.id) resolved successfully using \(strategy)")
            return result
            
        } catch {
            logger?.error("Failed to resolve conflict \(conflict.id): \(error)")
            
            let result = ConflictResolutionResult(
                conflict: conflict,
                resolution: nil,
                success: false,
                appliedAt: Date(),
                resolvedBy: validUser.id,
                error: error as? ConflictResolutionError ?? .unknownError(error.localizedDescription)
            )
            
            await recordResolution(result)
            throw error
        }
    }
    
    public func resolveConflicts(
        _ conflicts: [SyncConflict],
        using strategy: ConflictResolutionStrategy,
        for user: User
    ) async throws -> [ConflictResolutionResult] {
        logger?.info("Resolving \(conflicts.count) conflicts in batch using \(strategy)")
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid, let validUser = sessionResult.user else {
            throw SyncError.authenticationFailed
        }
        
        // Validate feature access
        let featureAccess = try await subscriptionUseCase.validateFeatureAccess(.conflictResolution, for: validUser)
        guard featureAccess.hasAccess else {
            throw SyncError.subscriptionRequired
        }
        
        // Process in batches to avoid overwhelming the system
        var allResults: [ConflictResolutionResult] = []
        let batches = conflicts.chunked(into: maxBatchSize)
        
        for batch in batches {
            logger?.debug("Processing batch of \(batch.count) conflicts")
            
            var batchResults: [ConflictResolutionResult] = []
            
            for conflict in batch {
                do {
                    let result = try await resolveConflict(conflict, using: strategy, for: validUser)
                    batchResults.append(result)
                } catch {
                    let failedResult = ConflictResolutionResult(
                        conflict: conflict,
                        resolution: nil,
                        success: false,
                        appliedAt: Date(),
                        resolvedBy: validUser.id,
                        error: error as? ConflictResolutionError ?? .unknownError(error.localizedDescription)
                    )
                    batchResults.append(failedResult)
                }
            }
            
            allResults.append(contentsOf: batchResults)
        }
        
        let successCount = allResults.filter { $0.success }.count
        logger?.info("Batch conflict resolution completed: \(successCount)/\(conflicts.count) successful")
        
        return allResults
    }
    
    public func autoResolveConflicts<T: Syncable>(
        for entityType: T.Type,
        user: User
    ) async throws -> AutoResolutionResult {
        logger?.info("Auto-resolving conflicts for \(entityType) and user: \(user.id)")
        
        guard autoResolutionEnabled else {
            return AutoResolutionResult(
                entityType: String(describing: entityType),
                totalConflicts: 0,
                autoResolvedCount: 0,
                manualRequiredCount: 0,
                success: false,
                error: .autoResolutionDisabled
            )
        }
        
        // Detect all conflicts
        let allConflicts = try await detectConflicts(for: entityType, user: user)
        
        guard !allConflicts.isEmpty else {
            return AutoResolutionResult(
                entityType: String(describing: entityType),
                totalConflicts: 0,
                autoResolvedCount: 0,
                manualRequiredCount: 0,
                success: true
            )
        }
        
        // Filter conflicts for auto-resolution
        let (autoResolvable, manualRequired) = conflictResolver.filterAutoResolvableConflicts(allConflicts)
        
        logger?.debug("Found \(autoResolvable.count) auto-resolvable and \(manualRequired.count) manual conflicts")
        
        var resolvedCount = 0
        var errors: [ConflictResolutionError] = []
        
        // Auto-resolve using last-write-wins strategy
        for conflict in autoResolvable {
            do {
                _ = try await resolveConflict(conflict, using: .lastWriteWins, for: user)
                resolvedCount += 1
            } catch let error as ConflictResolutionError {
                errors.append(error)
                logger?.warning("Failed to auto-resolve conflict \(conflict.id): \(error)")
            } catch {
                errors.append(.unknownError(error.localizedDescription))
            }
        }
        
        let result = AutoResolutionResult(
            entityType: String(describing: entityType),
            totalConflicts: allConflicts.count,
            autoResolvedCount: resolvedCount,
            manualRequiredCount: manualRequired.count,
            success: errors.isEmpty,
            errors: errors
        )
        
        logger?.info("Auto-resolution completed: \(resolvedCount)/\(autoResolvable.count) resolved")
        return result
    }
    
    public func getManualResolutionConflicts<T: Syncable>(
        for entityType: T.Type?,
        user: User
    ) async throws -> [SyncConflict] {
        logger?.debug("Getting manual resolution conflicts for user: \(user.id)")
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid else {
            throw SyncError.authenticationFailed
        }
        
        // Get all conflicts
        let allConflicts: [SyncConflict]
        if let entityType = entityType {
            allConflicts = try await syncRepository.getUnresolvedConflicts(
                ofType: entityType,
                limit: nil
            )
        } else {
            // In real implementation, would get conflicts for all entity types
            allConflicts = []
        }
        
        // Filter for manual resolution only
        let (_, manualRequired) = conflictResolver.filterAutoResolvableConflicts(allConflicts)
        
        logger?.debug("Found \(manualRequired.count) conflicts requiring manual resolution")
        return manualRequired
    }
    
    public func applyCustomResolution(
        to conflict: SyncConflict,
        with resolutionData: [String: Any],
        for user: User
    ) async throws -> ConflictResolutionResult {
        logger?.info("Applying custom resolution to conflict \(conflict.id)")
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid, let validUser = sessionResult.user else {
            throw SyncError.authenticationFailed
        }
        
        // Validate feature access
        let featureAccess = try await subscriptionUseCase.validateFeatureAccess(.conflictResolution, for: validUser)
        guard featureAccess.hasAccess else {
            throw SyncError.subscriptionRequired
        }
        
        do {
            // Create custom resolution
            let resolution = ConflictResolution(
                strategy: .manual,
                resolvedData: resolutionData,
                explanation: "Custom resolution applied by user",
                wasAutomatic: false,
                confidence: 1.0
            )
            
            // Validate the resolution
            guard conflictResolver.validateResolution(resolution, for: conflict) else {
                throw ConflictResolutionError.resolutionValidationFailed
            }
            
            // Apply resolution
            let applicationResults = try await syncRepository.applyConflictResolutions([resolution])
            
            guard let applicationResult = applicationResults.first, applicationResult.success else {
                let error = applicationResults.first?.error ?? SyncError.unknownError("Custom resolution application failed")
                throw error
            }
            
            // Create resolution result
            let result = ConflictResolutionResult(
                conflict: conflict,
                resolution: resolution,
                success: true,
                appliedAt: Date(),
                resolvedBy: validUser.id
            )
            
            // Record in history
            await recordResolution(result)
            
            logger?.info("Custom resolution applied successfully to conflict \(conflict.id)")
            return result
            
        } catch {
            logger?.error("Failed to apply custom resolution to conflict \(conflict.id): \(error)")
            
            let result = ConflictResolutionResult(
                conflict: conflict,
                resolution: nil,
                success: false,
                appliedAt: Date(),
                resolvedBy: validUser.id,
                error: error as? ConflictResolutionError ?? .unknownError(error.localizedDescription)
            )
            
            await recordResolution(result)
            throw error
        }
    }
    
    public func getResolutionHistory<T: Syncable>(
        for entityType: T.Type?,
        user: User,
        limit: Int?
    ) async throws -> [ConflictResolutionRecord] {
        logger?.debug("Getting resolution history for user: \(user.id)")
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid else {
            throw SyncError.authenticationFailed
        }
        
        let entityTypeName = entityType != nil ? String(describing: entityType!) : nil
        return await resolutionHistory.getHistory(
            entityType: entityTypeName,
            limit: limit
        )
    }
    
    // MARK: - Private Helper Methods
    
    private func recordResolution(_ result: ConflictResolutionResult) async {
        let record = ConflictResolutionRecord(
            id: UUID(),
            conflictId: result.conflict.id,
            entityType: result.conflict.entityType,
            strategy: result.resolution?.strategy ?? .manual,
            success: result.success,
            resolvedAt: result.appliedAt,
            resolvedBy: result.resolvedBy,
            error: result.error
        )
        
        await resolutionHistory.addRecord(record)
        logger?.debug("Recorded resolution for conflict \(result.conflict.id)")
    }
}

// MARK: - Supporting Types

public struct ConflictResolutionResult {
    /// The original conflict
    public let conflict: SyncConflict
    
    /// The resolution that was applied (if successful)
    public let resolution: ConflictResolution?
    
    /// Whether resolution was successful
    public let success: Bool
    
    /// When resolution was applied
    public let appliedAt: Date
    
    /// ID of user who resolved the conflict
    public let resolvedBy: UUID
    
    /// Error if resolution failed
    public let error: ConflictResolutionError?
    
    public init(
        conflict: SyncConflict,
        resolution: ConflictResolution?,
        success: Bool,
        appliedAt: Date = Date(),
        resolvedBy: UUID,
        error: ConflictResolutionError? = nil
    ) {
        self.conflict = conflict
        self.resolution = resolution
        self.success = success
        self.appliedAt = appliedAt
        self.resolvedBy = resolvedBy
        self.error = error
    }
}

public struct AutoResolutionResult {
    /// Entity type that was processed
    public let entityType: String
    
    /// Total number of conflicts found
    public let totalConflicts: Int
    
    /// Number of conflicts auto-resolved
    public let autoResolvedCount: Int
    
    /// Number of conflicts requiring manual resolution
    public let manualRequiredCount: Int
    
    /// Whether auto-resolution was successful
    public let success: Bool
    
    /// Processing timestamp
    public let processedAt: Date
    
    /// Errors encountered during auto-resolution
    public let errors: [ConflictResolutionError]
    
    public init(
        entityType: String,
        totalConflicts: Int,
        autoResolvedCount: Int,
        manualRequiredCount: Int,
        success: Bool,
        processedAt: Date = Date(),
        errors: [ConflictResolutionError] = [],
        error: ConflictResolutionError? = nil
    ) {
        self.entityType = entityType
        self.totalConflicts = totalConflicts
        self.autoResolvedCount = autoResolvedCount
        self.manualRequiredCount = manualRequiredCount
        self.success = success
        self.processedAt = processedAt
        
        if let error = error {
            self.errors = [error]
        } else {
            self.errors = errors
        }
    }
}

public struct ConflictResolutionRecord: Identifiable {
    /// Unique record ID
    public let id: UUID
    
    /// ID of the conflict that was resolved
    public let conflictId: UUID
    
    /// Entity type that had the conflict
    public let entityType: String
    
    /// Strategy used for resolution
    public let strategy: ConflictResolutionStrategy
    
    /// Whether resolution was successful
    public let success: Bool
    
    /// When conflict was resolved
    public let resolvedAt: Date
    
    /// ID of user who resolved the conflict
    public let resolvedBy: UUID
    
    /// Error if resolution failed
    public let error: ConflictResolutionError?
    
    public init(
        id: UUID = UUID(),
        conflictId: UUID,
        entityType: String,
        strategy: ConflictResolutionStrategy,
        success: Bool,
        resolvedAt: Date = Date(),
        resolvedBy: UUID,
        error: ConflictResolutionError? = nil
    ) {
        self.id = id
        self.conflictId = conflictId
        self.entityType = entityType
        self.strategy = strategy
        self.success = success
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.error = error
    }
}

// MARK: - Error Extensions

extension ConflictResolutionError {
    static let autoResolutionDisabled = ConflictResolutionError.unknownError("Auto-resolution is disabled")
}

// MARK: - Array Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// Note: DispatchQueue.sync extension removed to avoid conflicts

// MARK: - Resolution History Manager

private actor ResolutionHistoryManager {
    private var history: [ConflictResolutionRecord] = []
    private let retentionDays: Int
    
    init(retentionDays: Int) {
        self.retentionDays = retentionDays
    }
    
    func addRecord(_ record: ConflictResolutionRecord) {
        history.append(record)
        cleanupOldEntries()
    }
    
    func getHistory(entityType: String?, limit: Int?) -> [ConflictResolutionRecord] {
        var filteredHistory = history
        
        // Filter by entity type if specified
        if let entityType = entityType {
            filteredHistory = filteredHistory.filter { $0.entityType == entityType }
        }
        
        // Filter by date (only recent entries)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        filteredHistory = filteredHistory.filter { $0.resolvedAt >= cutoffDate }
        
        // Sort by resolution date (newest first)
        filteredHistory.sort { $0.resolvedAt > $1.resolvedAt }
        
        // Apply limit if specified
        if let limit = limit {
            filteredHistory = Array(filteredHistory.prefix(limit))
        }
        
        return filteredHistory
    }
    
    private func cleanupOldEntries() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        history.removeAll { $0.resolvedAt < cutoffDate }
    }
}

// Note: StrategyBasedConflictResolver implementation removed to avoid conflicts
// It's already implemented in ConflictResolvable.swift