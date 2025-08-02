//
//  SubscriptionManager.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Combine

/// Manages subscription validation, feature gating, and pro feature access
/// Provides reactive updates for subscription status and feature availability
@MainActor
public final class SubscriptionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current subscription validation result
    @Published public private(set) var subscriptionStatus: SubscriptionValidationResult?
    
    /// Whether subscription is currently being validated
    @Published public private(set) var isValidating: Bool = false
    
    /// Available features for current subscription
    @Published public private(set) var availableFeatures: Set<Feature> = []
    
    /// Current subscription tier
    @Published public private(set) var currentTier: SubscriptionTier = .free
    
    /// Whether user has an active subscription
    @Published public private(set) var hasActiveSubscription: Bool = false
    
    /// Last validation error
    @Published public private(set) var lastValidationError: SubscriptionValidationError?
    
    /// Feature access results cache
    @Published public private(set) var featureAccessCache: [Feature: FeatureAccessResult] = [:]
    
    /// Usage limits status
    @Published public private(set) var usageLimits: [SubscriptionLimit: LimitValidationResult] = [:]
    
    // MARK: - Dependencies
    
    private let subscriptionValidator: SubscriptionValidating
    private let validateSubscriptionUseCase: ValidateSubscriptionUseCaseProtocol
    private let authManager: AuthManager
    private let coordinationHub: CoordinationHub
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Configuration
    
    private let enableCaching: Bool
    private let cacheExpirationInterval: TimeInterval
    private let autoRefreshInterval: TimeInterval
    
    // MARK: - State Management
    
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var featureValidationTasks: [Feature: Task<FeatureAccessResult, Never>] = [:]
    
    // MARK: - Initialization
    
    public init(
        subscriptionValidator: SubscriptionValidating,
        validateSubscriptionUseCase: ValidateSubscriptionUseCaseProtocol,
        authManager: AuthManager,
        logger: SyncLoggerProtocol? = nil,
        enableCaching: Bool = true,
        cacheExpirationInterval: TimeInterval = 300, // 5 minutes
        autoRefreshInterval: TimeInterval = 900 // 15 minutes
    ) {
        self.subscriptionValidator = subscriptionValidator
        self.validateSubscriptionUseCase = validateSubscriptionUseCase
        self.authManager = authManager
        self.coordinationHub = CoordinationHub.shared
        self.logger = logger
        self.enableCaching = enableCaching
        self.cacheExpirationInterval = cacheExpirationInterval
        self.autoRefreshInterval = autoRefreshInterval
        
        Task {
            await initialize()
        }
    }
    
    // MARK: - Initialization
    
    private func initialize() async {
        logger?.debug("SubscriptionManager: Initializing")
        
        // Observe authentication state changes
        observeAuthenticationState()
        
        // Initial validation if user is authenticated
        if authManager.isAuthenticated {
            await validateSubscription()
        }
        
        // Setup auto refresh
        setupAutoRefresh()
    }
    
    // MARK: - Subscription Validation
    
    /// Validate current user's subscription
    /// - Parameter forceRefresh: Whether to bypass cache and force fresh validation
    /// - Returns: Subscription validation result
    @discardableResult
    public func validateSubscription(forceRefresh: Bool = false) async -> SubscriptionValidationResult {
        guard let user = authManager.currentUser else {
            let result = SubscriptionValidationResult.freeTier()
            await updateSubscriptionStatus(result)
            return result
        }
        
        logger?.info("SubscriptionManager: Validating subscription for user: \(user.id)")
        
        await setValidating(true)
        defer { Task { await setValidating(false) } }
        
        do {
            let result: SubscriptionValidationResult
            
            if !forceRefresh, enableCaching, let cached = subscriptionValidator.getCachedValidation(for: user) {
                logger?.debug("SubscriptionManager: Using cached validation result")
                result = cached
            } else {
                result = try await subscriptionValidator.validateSubscription(for: user)
                logger?.debug("SubscriptionManager: Fresh validation completed")
            }
            
            await updateSubscriptionStatus(result)
            await clearValidationError()
            
            return result
            
        } catch let error as SubscriptionValidationError {
            logger?.error("SubscriptionManager: Subscription validation failed: \(error)")
            await setValidationError(error)
            
            let failedResult = SubscriptionValidationResult.failed(error: error)
            await updateSubscriptionStatus(failedResult)
            
            return failedResult
        } catch {
            let validationError = SubscriptionValidationError.unknownError(error.localizedDescription)
            logger?.error("SubscriptionManager: Subscription validation failed with unknown error: \(error)")
            await setValidationError(validationError)
            
            let failedResult = SubscriptionValidationResult.failed(error: validationError)
            await updateSubscriptionStatus(failedResult)
            
            return failedResult
        }
    }
    
    /// Refresh subscription status from remote source
    /// - Returns: Updated subscription validation result
    @discardableResult
    public func refreshSubscriptionStatus() async -> SubscriptionValidationResult {
        guard let user = authManager.currentUser else {
            let result = SubscriptionValidationResult.freeTier()
            await updateSubscriptionStatus(result)
            return result
        }
        
        logger?.info("SubscriptionManager: Refreshing subscription status")
        
        do {
            let result = try await subscriptionValidator.refreshSubscriptionStatus(for: user)
            await updateSubscriptionStatus(result)
            await clearValidationError()
            return result
        } catch let error as SubscriptionValidationError {
            await setValidationError(error)
            return SubscriptionValidationResult.failed(error: error)
        } catch {
            let validationError = SubscriptionValidationError.unknownError(error.localizedDescription)
            await setValidationError(validationError)
            return SubscriptionValidationResult.failed(error: validationError)
        }
    }
    
    // MARK: - Feature Access Validation
    
    /// Check if user has access to a specific feature
    /// - Parameter feature: Feature to check access for
    /// - Returns: Feature access result
    public func validateFeatureAccess(_ feature: Feature) async -> FeatureAccessResult {
        guard let user = authManager.currentUser else {
            return FeatureAccessResult.denied(
                for: feature,
                reason: .subscriptionRequired,
                requiredTier: .pro
            )
        }
        
        // Check cache first
        if enableCaching, let cached = featureAccessCache[feature] {
            let cacheAge = Date().timeIntervalSince(cached.validatedAt)
            if cacheAge < cacheExpirationInterval {
                logger?.debug("SubscriptionManager: Using cached feature access result for \(feature)")
                return cached
            }
        }
        
        // Cancel any existing validation task for this feature
        featureValidationTasks[feature]?.cancel()
        
        // Create new validation task
        let task = Task {
            do {
                let result = try await subscriptionValidator.validateFeatureAccess(feature, for: user)
                await MainActor.run {
                    self.featureAccessCache[feature] = result
                }
                return result
            } catch {
                return FeatureAccessResult.denied(
                    for: feature,
                    reason: .validationFailed,
                    requiredTier: .pro
                )
            }
        }
        
        featureValidationTasks[feature] = task
        let result = await task.value
        featureValidationTasks.removeValue(forKey: feature)
        
        return result
    }
    
    /// Validate access to multiple features at once
    /// - Parameter features: Set of features to validate
    /// - Returns: Dictionary mapping features to their access results
    public func validateFeatures(_ features: Set<Feature>) async -> [Feature: FeatureAccessResult] {
        guard authManager.currentUser != nil else {
            return features.reduce(into: [:]) { result, feature in
                result[feature] = FeatureAccessResult.denied(
                    for: feature,
                    reason: .subscriptionRequired,
                    requiredTier: .pro
                )
            }
        }
        
        logger?.debug("SubscriptionManager: Validating access to \(features.count) features")
        
        return await withTaskGroup(of: (Feature, FeatureAccessResult).self) { group in
            for feature in features {
                group.addTask {
                    let result = await self.validateFeatureAccess(feature)
                    return (feature, result)
                }
            }
            
            var results: [Feature: FeatureAccessResult] = [:]
            for await (feature, result) in group {
                results[feature] = result
            }
            return results
        }
    }
    
    /// Check if user has access to a feature (simple boolean check)
    /// - Parameter feature: Feature to check
    /// - Returns: True if user has access, false otherwise
    public func hasFeatureAccess(_ feature: Feature) async -> Bool {
        let result = await validateFeatureAccess(feature)
        return result.hasAccess
    }
    
    // MARK: - Sync Access Validation
    
    /// Validate sync access for specific operation type
    /// - Parameter syncType: Type of sync operation
    /// - Returns: Sync access result
    public func validateSyncAccess(_ syncType: SyncOperationType) async -> SyncAccessResult {
        guard let user = authManager.currentUser else {
            return SyncAccessResult.denied(
                for: syncType,
                reason: .subscriptionRequired
            )
        }
        
        do {
            return try await subscriptionValidator.validateSyncAccess(syncType, for: user)
        } catch {
            return SyncAccessResult.denied(
                for: syncType,
                reason: .validationFailed
            )
        }
    }
    
    // MARK: - Usage Limits
    
    /// Check usage limit for specific limit type
    /// - Parameter limitType: Type of limit to check
    /// - Returns: Limit validation result
    public func validateLimit(_ limitType: SubscriptionLimit) async -> LimitValidationResult {
        guard let user = authManager.currentUser else {
            return LimitValidationResult(
                withinLimit: false,
                limitType: limitType,
                currentUsage: 0,
                maximumAllowed: 0
            )
        }
        
        do {
            let result = try await subscriptionValidator.validateLimit(limitType, for: user)
            
            await MainActor.run {
                self.usageLimits[limitType] = result
            }
            
            return result
        } catch {
            return LimitValidationResult(
                withinLimit: false,
                limitType: limitType,
                currentUsage: 0,
                maximumAllowed: 0
            )
        }
    }
    
    /// Get all usage limits for current user
    /// - Returns: Dictionary of all usage limits
    public func getAllUsageLimits() async -> [SubscriptionLimit: LimitValidationResult] {
        let allLimits = SubscriptionLimit.allCases
        
        return await withTaskGroup(of: (SubscriptionLimit, LimitValidationResult).self) { group in
            for limit in allLimits {
                group.addTask {
                    let result = await self.validateLimit(limit)
                    return (limit, result)
                }
            }
            
            var results: [SubscriptionLimit: LimitValidationResult] = [:]
            for await (limit, result) in group {
                results[limit] = result
            }
            return results
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached validation results
    public func clearCache() {
        Task {
            await MainActor.run {
                self.featureAccessCache.removeAll()
                self.usageLimits.removeAll()
            }
            
            // Clear validator cache if supported
            if let user = authManager.currentUser {
                subscriptionValidator.invalidateCache(for: user)
            }
            
            logger?.debug("SubscriptionManager: Cache cleared")
        }
    }
    
    /// Clear cache for specific feature
    /// - Parameter feature: Feature to clear cache for
    public func clearCache(for feature: Feature) {
        Task {
            await MainActor.run {
                self.featureAccessCache.removeValue(forKey: feature)
            }
        }
    }
    
    // MARK: - Private State Management
    
    private func updateSubscriptionStatus(_ result: SubscriptionValidationResult) async {
        await MainActor.run {
            self.subscriptionStatus = result
            self.availableFeatures = result.availableFeatures
            self.currentTier = result.tier
            self.hasActiveSubscription = result.isValid && !result.isExpired
        }
        
        // Publish subscription change through coordination hub
        coordinationHub.publishSubscriptionChanged(
            tier: result.tier,
            isValid: result.isValid && !result.isExpired,
            features: result.availableFeatures
        )
        
        logger?.debug("SubscriptionManager: Updated subscription status - tier: \(result.tier), valid: \(result.isValid)")
    }
    
    private func setValidating(_ validating: Bool) async {
        await MainActor.run {
            self.isValidating = validating
        }
    }
    
    private func setValidationError(_ error: SubscriptionValidationError) async {
        await MainActor.run {
            self.lastValidationError = error
        }
    }
    
    private func clearValidationError() async {
        await MainActor.run {
            self.lastValidationError = nil
        }
    }
    
    // MARK: - Auto Refresh
    
    private func setupAutoRefresh() {
        refreshTimer?.invalidate()
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performAutoRefresh()
            }
        }
    }
    
    private func performAutoRefresh() async {
        guard authManager.isAuthenticated else { return }
        
        logger?.debug("SubscriptionManager: Performing auto refresh")
        
        await validateSubscription()
    }
    
    // MARK: - State Observation
    
    private func observeAuthenticationState() {
        authManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                Task { [weak self] in
                    if isAuthenticated {
                        await self?.validateSubscription()
                    } else {
                        await self?.handleSignOut()
                    }
                }
            }
            .store(in: &cancellables)
        
        authManager.$currentUser
            .compactMap { $0 }
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.validateSubscription()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleSignOut() async {
        await MainActor.run {
            self.subscriptionStatus = nil
            self.availableFeatures = []
            self.currentTier = .free
            self.hasActiveSubscription = false
            self.featureAccessCache.removeAll()
            self.usageLimits.removeAll()
            self.lastValidationError = nil
        }
        
        logger?.debug("SubscriptionManager: Cleared state after sign out")
    }
    
    // MARK: - Cleanup
    
    deinit {
        refreshTimer?.invalidate()
        cancellables.removeAll()
        
        // Cancel any active feature validation tasks
        for (_, task) in featureValidationTasks {
            task.cancel()
        }
    }
}

// MARK: - Public Convenience Methods

public extension SubscriptionManager {
    
    /// Whether current subscription allows realtime sync
    var allowsRealtimeSync: Bool {
        availableFeatures.contains(.realtimeSync)
    }
    
    /// Whether current subscription allows conflict resolution
    var allowsConflictResolution: Bool {
        availableFeatures.contains(.conflictResolution)
    }
    
    /// Whether current subscription allows multi-device sync
    var allowsMultiDevice: Bool {
        availableFeatures.contains(.multiDevice)
    }
    
    /// Whether current subscription allows custom schemas
    var allowsCustomSchemas: Bool {
        availableFeatures.contains(.customSchemas)
    }
    
    /// Time until subscription expires (if applicable)
    var timeUntilExpiration: TimeInterval? {
        subscriptionStatus?.timeUntilExpiration
    }
    
    /// Whether subscription is expired
    var isExpired: Bool {
        subscriptionStatus?.isExpired ?? false
    }
    
    /// Clear validation errors
    func clearErrors() {
        Task {
            await clearValidationError()
        }
    }
    
    /// Force validation refresh
    func forceRefresh() async {
        await validateSubscription(forceRefresh: true)
    }
    
    /// Get cached access result for feature
    func getCachedAccess(for feature: Feature) -> FeatureAccessResult? {
        featureAccessCache[feature]
    }
    
    /// Get usage percentage for limit
    func getUsagePercentage(for limit: SubscriptionLimit) -> Double? {
        usageLimits[limit]?.usagePercentage
    }
}