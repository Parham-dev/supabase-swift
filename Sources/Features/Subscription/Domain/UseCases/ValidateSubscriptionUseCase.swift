//
//  ValidateSubscriptionUseCase.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Use case for validating subscription status and managing feature access
/// Orchestrates subscription validation, caching, and feature gating
public protocol ValidateSubscriptionUseCaseProtocol {
    
    /// Validate user's current subscription status
    /// - Parameter user: User to validate subscription for
    /// - Returns: Comprehensive subscription validation result
    func validateSubscription(for user: User) async throws -> SubscriptionValidationResult
    
    /// Check access to a specific feature
    /// - Parameters:
    ///   - feature: Feature to check access for
    ///   - user: User requesting access
    /// - Returns: Feature access validation result
    func validateFeatureAccess(_ feature: Feature, for user: User) async throws -> FeatureAccessResult
    
    /// Validate access to multiple features at once
    /// - Parameters:
    ///   - features: Set of features to validate
    ///   - user: User to validate features for
    /// - Returns: Dictionary mapping features to access results
    func validateFeatures(_ features: Set<Feature>, for user: User) async throws -> [Feature: FeatureAccessResult]
    
    /// Check subscription limits (quotas, usage, etc.)
    /// - Parameters:
    ///   - limitType: Type of limit to check
    ///   - user: User to check limits for
    /// - Returns: Limit validation result
    func validateLimit(_ limitType: SubscriptionLimit, for user: User) async throws -> LimitValidationResult
    
    /// Refresh subscription status from remote source
    /// - Parameter user: User whose subscription to refresh
    /// - Returns: Updated subscription validation result
    func refreshSubscription(for user: User) async throws -> SubscriptionValidationResult
    
    /// Get subscription recommendations for user
    /// - Parameter user: User to get recommendations for
    /// - Returns: Subscription recommendations
    func getSubscriptionRecommendations(for user: User) async throws -> SubscriptionRecommendations
}

public struct ValidateSubscriptionUseCase: ValidateSubscriptionUseCaseProtocol {
    
    // MARK: - Dependencies
    
    private let subscriptionValidator: SubscriptionValidating
    private let authUseCase: AuthenticateUserUseCaseProtocol
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Configuration
    
    private let cacheExpirationTime: TimeInterval
    private let maxCachedValidations: Int
    
    // MARK: - Cache
    
    private let cacheManager: ValidationCacheManager
    private let cacheQueue = DispatchQueue(label: "subscription.cache", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init(
        subscriptionValidator: SubscriptionValidating,
        authUseCase: AuthenticateUserUseCaseProtocol,
        logger: SyncLoggerProtocol? = nil,
        cacheExpirationTime: TimeInterval = 300, // 5 minutes
        maxCachedValidations: Int = 100
    ) {
        self.subscriptionValidator = subscriptionValidator
        self.authUseCase = authUseCase
        self.logger = logger
        self.cacheExpirationTime = cacheExpirationTime
        self.maxCachedValidations = maxCachedValidations
        self.cacheManager = ValidationCacheManager(
            expirationTime: cacheExpirationTime,
            maxCachedValidations: maxCachedValidations
        )
    }
    
    // MARK: - Public Methods
    
    public func validateSubscription(for user: User) async throws -> SubscriptionValidationResult {
        logger?.debug("Validating subscription for user: \(user.id)")
        
        // Check cache first
        if let cachedResult = await cacheManager.getCachedValidation(for: user) {
            logger?.debug("Using cached subscription validation for user: \(user.id)")
            return cachedResult
        }
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid, let validUser = sessionResult.user else {
            throw SubscriptionValidationError.invalidCredentials
        }
        
        do {
            // Perform fresh validation
            let result = try await subscriptionValidator.validateSubscription(for: validUser)
            
            // Cache the result
            await cacheManager.cacheValidationResult(result, for: validUser)
            
            logger?.info("Subscription validation completed for user: \(user.id), tier: \(result.tier)")
            return result
            
        } catch {
            logger?.error("Subscription validation failed for user: \(user.id), error: \(error)")
            
            // Return cached result if available, even if expired
            if let expiredCached = await cacheManager.getExpiredCachedValidation(for: user) {
                logger?.warning("Using expired cached validation due to validation failure")
                return expiredCached
            }
            
            throw error
        }
    }
    
    public func validateFeatureAccess(_ feature: Feature, for user: User) async throws -> FeatureAccessResult {
        logger?.debug("Validating feature access for \(feature) and user: \(user.id)")
        
        // First validate subscription
        let subscriptionResult = try await validateSubscription(for: user)
        
        // Check if feature is included in subscription
        if subscriptionResult.availableFeatures.contains(feature) {
            logger?.debug("Feature \(feature) granted for user: \(user.id)")
            return FeatureAccessResult.granted(
                for: feature,
                requiredTier: subscriptionResult.tier
            )
        }
        
        // Determine required tier for feature
        let requiredTier = getRequiredTierForFeature(feature)
        
        // Determine denial reason
        let denialReason = getDenialReason(
            currentTier: subscriptionResult.tier,
            requiredTier: requiredTier,
            subscriptionStatus: subscriptionResult.status,
            isExpired: subscriptionResult.isExpired
        )
        
        logger?.debug("Feature \(feature) denied for user: \(user.id), reason: \(denialReason)")
        return FeatureAccessResult.denied(
            for: feature,
            reason: denialReason,
            requiredTier: requiredTier
        )
    }
    
    public func validateFeatures(_ features: Set<Feature>, for user: User) async throws -> [Feature: FeatureAccessResult] {
        logger?.debug("Validating \(features.count) features for user: \(user.id)")
        
        var results: [Feature: FeatureAccessResult] = [:]
        
        // Validate subscription once
        let subscriptionResult = try await validateSubscription(for: user)
        
        // Check each feature
        for feature in features {
            if subscriptionResult.availableFeatures.contains(feature) {
                results[feature] = FeatureAccessResult.granted(
                    for: feature,
                    requiredTier: subscriptionResult.tier
                )
            } else {
                let requiredTier = getRequiredTierForFeature(feature)
                let denialReason = getDenialReason(
                    currentTier: subscriptionResult.tier,
                    requiredTier: requiredTier,
                    subscriptionStatus: subscriptionResult.status,
                    isExpired: subscriptionResult.isExpired
                )
                
                results[feature] = FeatureAccessResult.denied(
                    for: feature,
                    reason: denialReason,
                    requiredTier: requiredTier
                )
            }
        }
        
        logger?.debug("Feature validation completed: \(results.values.filter { $0.hasAccess }.count)/\(features.count) granted")
        return results
    }
    
    public func validateLimit(_ limitType: SubscriptionLimit, for user: User) async throws -> LimitValidationResult {
        logger?.debug("Validating limit \(limitType) for user: \(user.id)")
        
        // Validate subscription first
        let subscriptionResult = try await validateSubscription(for: user)
        
        // Get limit for user's tier
        let maxAllowed = getMaxAllowedForLimit(limitType, tier: subscriptionResult.tier)
        
        // Get current usage (would be implemented based on actual usage tracking)
        let currentUsage = try await getCurrentUsage(limitType: limitType, for: user)
        
        let withinLimit = currentUsage <= maxAllowed
        let resetDate = getResetDateForLimit(limitType)
        
        let result = LimitValidationResult(
            withinLimit: withinLimit,
            limitType: limitType,
            currentUsage: currentUsage,
            maximumAllowed: maxAllowed,
            resetsAt: resetDate
        )
        
        logger?.debug("Limit validation for \(limitType): \(currentUsage)/\(maxAllowed) (\(withinLimit ? "within" : "exceeded"))")
        return result
    }
    
    public func refreshSubscription(for user: User) async throws -> SubscriptionValidationResult {
        logger?.info("Refreshing subscription for user: \(user.id)")
        
        // Clear cache for this user
        await cacheManager.invalidateCache(for: user)
        
        // Validate session
        let sessionResult = try await authUseCase.validateSession()
        guard sessionResult.isValid, let validUser = sessionResult.user else {
            throw SubscriptionValidationError.invalidCredentials
        }
        
        do {
            // Force fresh validation
            let result = try await subscriptionValidator.refreshSubscriptionStatus(for: validUser)
            
            // Cache the refreshed result
            await cacheManager.cacheValidationResult(result, for: validUser)
            
            logger?.info("Subscription refreshed for user: \(user.id), tier: \(result.tier)")
            return result
            
        } catch {
            logger?.error("Subscription refresh failed for user: \(user.id), error: \(error)")
            throw error
        }
    }
    
    public func getSubscriptionRecommendations(for user: User) async throws -> SubscriptionRecommendations {
        logger?.debug("Getting subscription recommendations for user: \(user.id)")
        
        // Validate current subscription
        let subscriptionResult = try await validateSubscription(for: user)
        
        // Analyze usage patterns (simplified)
        let usageAnalysis = try await analyzeUsagePatterns(for: user)
        
        // Generate recommendations
        let recommendations = generateRecommendations(
            currentTier: subscriptionResult.tier,
            usage: usageAnalysis,
            availableFeatures: subscriptionResult.availableFeatures
        )
        
        logger?.debug("Generated \(recommendations.suggestions.count) recommendations for user: \(user.id)")
        return recommendations
    }
    
    // MARK: - Private Helper Methods
    
    private func getRequiredTierForFeature(_ feature: Feature) -> SubscriptionTier {
        switch feature {
        case .basicSync:
            return .free
        case .realtimeSync, .conflictResolution, .multiDevice:
            return .pro
        case .customSchemas, .advancedLogging, .prioritySupport, .customBackup:
            return .enterprise
        }
    }
    
    private func getDenialReason(
        currentTier: SubscriptionTier,
        requiredTier: SubscriptionTier,
        subscriptionStatus: UserSubscriptionStatus,
        isExpired: Bool
    ) -> FeatureDenialReason {
        if isExpired {
            return .subscriptionExpired
        }
        
        if subscriptionStatus != .active {
            return .subscriptionRequired
        }
        
        // Check tier hierarchy
        let tierOrder: [SubscriptionTier] = [.free, .pro, .enterprise]
        
        guard let currentIndex = tierOrder.firstIndex(of: currentTier),
              let requiredIndex = tierOrder.firstIndex(of: requiredTier) else {
            return .subscriptionRequired
        }
        
        if currentIndex < requiredIndex {
            return .insufficientTier
        }
        
        return .subscriptionRequired
    }
    
    private func getMaxAllowedForLimit(_ limitType: SubscriptionLimit, tier: SubscriptionTier) -> Double {
        switch (limitType, tier) {
        case (.storageQuota, .free):
            return 100_000_000 // 100MB
        case (.storageQuota, .pro):
            return 1_000_000_000 // 1GB
        case (.storageQuota, .enterprise):
            return 10_000_000_000 // 10GB
            
        case (.syncOperations, .free):
            return 100
        case (.syncOperations, .pro):
            return 1000
        case (.syncOperations, .enterprise):
            return 10000
            
        case (.apiCalls, .free):
            return 1000
        case (.apiCalls, .pro):
            return 10000
        case (.apiCalls, .enterprise):
            return 100000
            
        case (.realtimeConnections, .free):
            return 1
        case (.realtimeConnections, .pro):
            return 10
        case (.realtimeConnections, .enterprise):
            return 100
            
        case (.modelCount, .free):
            return 3
        case (.modelCount, .pro):
            return 20
        case (.modelCount, .enterprise):
            return 100
            
        case (.recordCount, .free):
            return 1000
        case (.recordCount, .pro):
            return 100000
        case (.recordCount, .enterprise):
            return 1000000
            
        default:
            return 0
        }
    }
    
    private func getCurrentUsage(limitType: SubscriptionLimit, for user: User) async throws -> Double {
        // In real implementation, this would query actual usage from repositories
        // For now, return simulated usage
        switch limitType {
        case .storageQuota:
            return 50_000_000 // 50MB
        case .syncOperations:
            return 45
        case .apiCalls:
            return 234
        case .realtimeConnections:
            return 1
        case .modelCount:
            return 2
        case .recordCount:
            return 567
        }
    }
    
    private func getResetDateForLimit(_ limitType: SubscriptionLimit) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch limitType {
        case .syncOperations, .apiCalls:
            // Monthly limits
            return calendar.dateInterval(of: .month, for: now)?.end
        case .realtimeConnections:
            // No reset (concurrent limit)
            return nil
        case .storageQuota, .modelCount, .recordCount:
            // Account limits (no reset)
            return nil
        }
    }
    
    private func analyzeUsagePatterns(for user: User) async throws -> UsageAnalysis {
        // In real implementation, would analyze actual usage data
        return UsageAnalysis(
            primaryFeatures: [.basicSync, .realtimeSync],
            usageFrequency: .moderate,
            storageUsage: 0.5, // 50% of quota
            syncFrequency: .daily
        )
    }
    
    private func generateRecommendations(
        currentTier: SubscriptionTier,
        usage: UsageAnalysis,
        availableFeatures: Set<Feature>
    ) -> SubscriptionRecommendations {
        var suggestions: [SubscriptionSuggestion] = []
        
        // Analyze if user needs upgrade
        if currentTier == .free && usage.usageFrequency == .high {
            suggestions.append(SubscriptionSuggestion(
                type: .upgrade,
                targetTier: .pro,
                reason: "High usage detected - Pro plan recommended",
                benefits: ["Increased sync operations", "Real-time sync", "Multi-device support"],
                priority: .high
            ))
        }
        
        // Check for unused features
        if currentTier == .pro && usage.primaryFeatures.count <= 2 {
            suggestions.append(SubscriptionSuggestion(
                type: .optimize,
                targetTier: currentTier,
                reason: "You're only using basic features",
                benefits: ["Consider Free plan to save costs"],
                priority: .low
            ))
        }
        
        return SubscriptionRecommendations(
            currentTier: currentTier,
            suggestions: suggestions,
            usage: usage,
            generatedAt: Date()
        )
    }
}

// MARK: - Extensions

extension SubscriptionValidationResult {
    func withCacheFlag(_ fromCache: Bool) -> SubscriptionValidationResult {
        return SubscriptionValidationResult(
            isValid: isValid,
            tier: tier,
            status: status,
            expiresAt: expiresAt,
            availableFeatures: availableFeatures,
            validatedAt: validatedAt,
            error: error,
            fromCache: fromCache
        )
    }
}