//
//  SubscriptionValidating.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Protocol for validating subscription status and feature access
/// Enables pro feature gating and subscription-based functionality
public protocol SubscriptionValidating {
    
    // MARK: - Core Validation Methods
    
    /// Validate if user has an active subscription
    /// - Parameter user: The user to validate
    /// - Returns: Validation result with subscription status
    func validateSubscription(for user: User) async throws -> SubscriptionValidationResult
    
    /// Check if a specific feature is available to the user
    /// - Parameters:
    ///   - feature: The feature to check access for
    ///   - user: The user requesting access
    /// - Returns: Feature access result
    func validateFeatureAccess(_ feature: Feature, for user: User) async throws -> FeatureAccessResult
    
    /// Validate subscription for sync operations
    /// - Parameters:
    ///   - syncType: Type of sync operation being requested
    ///   - user: The user requesting sync
    /// - Returns: Sync permission result
    func validateSyncAccess(_ syncType: SyncOperationType, for user: User) async throws -> SyncAccessResult
    
    /// Refresh subscription status from remote source
    /// - Parameter user: The user whose subscription to refresh
    /// - Returns: Updated subscription validation result
    func refreshSubscriptionStatus(for user: User) async throws -> SubscriptionValidationResult
    
    // MARK: - Batch Validation
    
    /// Validate multiple features at once
    /// - Parameters:
    ///   - features: Set of features to validate
    ///   - user: The user to validate against
    /// - Returns: Dictionary mapping features to their access results
    func validateFeatures(_ features: Set<Feature>, for user: User) async throws -> [Feature: FeatureAccessResult]
    
    /// Check subscription limits (e.g., storage, API calls)
    /// - Parameters:
    ///   - limitType: Type of limit to check
    ///   - user: The user to check limits for
    /// - Returns: Limit validation result
    func validateLimit(_ limitType: SubscriptionLimit, for user: User) async throws -> LimitValidationResult
    
    // MARK: - Caching & Performance
    
    /// Get cached subscription status if available
    /// - Parameter user: The user to get cached status for
    /// - Returns: Cached validation result or nil if not cached/expired
    func getCachedValidation(for user: User) -> SubscriptionValidationResult?
    
    /// Invalidate cached subscription data
    /// - Parameter user: The user whose cache to invalidate
    func invalidateCache(for user: User)
}

// MARK: - Supporting Types

public struct SubscriptionValidationResult: Codable, Equatable {
    /// Whether the subscription is valid and active
    public let isValid: Bool
    
    /// Current subscription tier
    public let tier: SubscriptionTier
    
    /// Subscription status details
    public let status: UserSubscriptionStatus
    
    /// When the subscription expires (nil for lifetime/enterprise)
    public let expiresAt: Date?
    
    /// Features available with current subscription
    public let availableFeatures: Set<Feature>
    
    /// Validation timestamp
    public let validatedAt: Date
    
    /// Error if validation failed
    public let error: SubscriptionValidationError?
    
    /// Whether this result came from cache
    public let fromCache: Bool
    
    public init(
        isValid: Bool,
        tier: SubscriptionTier,
        status: UserSubscriptionStatus,
        expiresAt: Date? = nil,
        availableFeatures: Set<Feature> = [],
        validatedAt: Date = Date(),
        error: SubscriptionValidationError? = nil,
        fromCache: Bool = false
    ) {
        self.isValid = isValid
        self.tier = tier
        self.status = status
        self.expiresAt = expiresAt
        self.availableFeatures = availableFeatures
        self.validatedAt = validatedAt
        self.error = error
        self.fromCache = fromCache
    }
}

public struct FeatureAccessResult: Codable, Equatable {
    /// Whether access to the feature is granted
    public let hasAccess: Bool
    
    /// The feature being checked
    public let feature: Feature
    
    /// Reason for access denial (if applicable)
    public let denialReason: FeatureDenialReason?
    
    /// Required subscription tier for this feature
    public let requiredTier: SubscriptionTier
    
    /// Validation timestamp
    public let validatedAt: Date
    
    public init(
        hasAccess: Bool,
        feature: Feature,
        denialReason: FeatureDenialReason? = nil,
        requiredTier: SubscriptionTier,
        validatedAt: Date = Date()
    ) {
        self.hasAccess = hasAccess
        self.feature = feature
        self.denialReason = denialReason
        self.requiredTier = requiredTier
        self.validatedAt = validatedAt
    }
}

public struct SyncAccessResult: Codable, Equatable {
    /// Whether sync access is granted
    public let hasAccess: Bool
    
    /// The sync operation type being checked
    public let syncType: SyncOperationType
    
    /// Reason for access denial (if applicable)
    public let denialReason: SyncDenialReason?
    
    /// Maximum allowed sync frequency for user's tier
    public let allowedFrequency: SyncFrequency?
    
    /// Validation timestamp
    public let validatedAt: Date
    
    public init(
        hasAccess: Bool,
        syncType: SyncOperationType,
        denialReason: SyncDenialReason? = nil,
        allowedFrequency: SyncFrequency? = nil,
        validatedAt: Date = Date()
    ) {
        self.hasAccess = hasAccess
        self.syncType = syncType
        self.denialReason = denialReason
        self.allowedFrequency = allowedFrequency
        self.validatedAt = validatedAt
    }
}

public struct LimitValidationResult: Codable, Equatable {
    /// Whether the limit allows the operation
    public let withinLimit: Bool
    
    /// Type of limit being checked
    public let limitType: SubscriptionLimit
    
    /// Current usage amount
    public let currentUsage: Double
    
    /// Maximum allowed for user's subscription
    public let maximumAllowed: Double
    
    /// Usage percentage (0.0 to 1.0)
    public let usagePercentage: Double
    
    /// When the limit resets (e.g., monthly limits)
    public let resetsAt: Date?
    
    /// Validation timestamp
    public let validatedAt: Date
    
    public init(
        withinLimit: Bool,
        limitType: SubscriptionLimit,
        currentUsage: Double,
        maximumAllowed: Double,
        resetsAt: Date? = nil,
        validatedAt: Date = Date()
    ) {
        self.withinLimit = withinLimit
        self.limitType = limitType
        self.currentUsage = currentUsage
        self.maximumAllowed = maximumAllowed
        self.usagePercentage = maximumAllowed > 0 ? min(currentUsage / maximumAllowed, 1.0) : 0.0
        self.resetsAt = resetsAt
        self.validatedAt = validatedAt
    }
}

// MARK: - Enums

public enum FeatureDenialReason: String, Codable, CaseIterable {
    case subscriptionRequired = "subscription_required"
    case subscriptionExpired = "subscription_expired"
    case insufficientTier = "insufficient_tier"
    case trialExpired = "trial_expired"
    case accountSuspended = "account_suspended"
    case featureDisabled = "feature_disabled"
    case networkError = "network_error"
    case validationFailed = "validation_failed"
    
    public var localizedDescription: String {
        switch self {
        case .subscriptionRequired:
            return "Pro subscription required"
        case .subscriptionExpired:
            return "Subscription has expired"
        case .insufficientTier:
            return "Higher subscription tier required"
        case .trialExpired:
            return "Trial period has expired"
        case .accountSuspended:
            return "Account has been suspended"
        case .featureDisabled:
            return "Feature is currently disabled"
        case .networkError:
            return "Unable to verify subscription"
        case .validationFailed:
            return "Subscription validation failed"
        }
    }
}

public enum SyncDenialReason: String, Codable, CaseIterable {
    case subscriptionRequired = "subscription_required"
    case quotaExceeded = "quota_exceeded"
    case rateLimitExceeded = "rate_limit_exceeded"
    case featureNotAvailable = "feature_not_available"
    case networkError = "network_error"
    case validationFailed = "validation_failed"
    
    public var localizedDescription: String {
        switch self {
        case .subscriptionRequired:
            return "Pro subscription required for sync"
        case .quotaExceeded:
            return "Sync quota exceeded"
        case .rateLimitExceeded:
            return "Sync rate limit exceeded"
        case .featureNotAvailable:
            return "Sync feature not available"
        case .networkError:
            return "Unable to verify sync permissions"
        case .validationFailed:
            return "Sync validation failed"
        }
    }
}

public enum SubscriptionLimit: String, Codable, CaseIterable {
    case storageQuota = "storage_quota"
    case syncOperations = "sync_operations"
    case apiCalls = "api_calls"
    case realtimeConnections = "realtime_connections"
    case modelCount = "model_count"
    case recordCount = "record_count"
    
    public var displayName: String {
        switch self {
        case .storageQuota:
            return "Storage Quota"
        case .syncOperations:
            return "Sync Operations"
        case .apiCalls:
            return "API Calls"
        case .realtimeConnections:
            return "Real-time Connections"
        case .modelCount:
            return "Model Count"
        case .recordCount:
            return "Record Count"
        }
    }
}

public enum SubscriptionValidationError: Error, LocalizedError, Codable, Equatable {
    case networkUnavailable
    case invalidCredentials
    case serverError(Int)
    case subscriptionServiceUnavailable
    case invalidSubscriptionData
    case rateLimitExceeded
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .invalidCredentials:
            return "Invalid subscription credentials"
        case .serverError(let code):
            return "Server error occurred (code: \(code))"
        case .subscriptionServiceUnavailable:
            return "Subscription service temporarily unavailable"
        case .invalidSubscriptionData:
            return "Invalid subscription data received"
        case .rateLimitExceeded:
            return "Subscription validation rate limit exceeded"
        case .unknownError(let message):
            return "Subscription validation error: \(message)"
        }
    }
}

// MARK: - Default Implementation

public extension SubscriptionValidating {
    
    /// Default batch feature validation
    func validateFeatures(_ features: Set<Feature>, for user: User) async throws -> [Feature: FeatureAccessResult] {
        var results: [Feature: FeatureAccessResult] = [:]
        
        for feature in features {
            results[feature] = try await validateFeatureAccess(feature, for: user)
        }
        
        return results
    }
    
    /// Default cache implementation (no caching)
    func getCachedValidation(for user: User) -> SubscriptionValidationResult? {
        return nil
    }
    
    /// Default cache invalidation (no-op)
    func invalidateCache(for user: User) {
        // Override in implementations that support caching
    }
}

// MARK: - Convenience Extensions

public extension SubscriptionValidationResult {
    
    /// Check if subscription allows a specific feature
    func allowsFeature(_ feature: Feature) -> Bool {
        return isValid && availableFeatures.contains(feature)
    }
    
    /// Check if subscription is expired
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() >= expiresAt
    }
    
    /// Time until expiration
    var timeUntilExpiration: TimeInterval? {
        guard let expiresAt = expiresAt else { return nil }
        return expiresAt.timeIntervalSinceNow
    }
    
    /// Create a failed validation result
    static func failed(error: SubscriptionValidationError) -> SubscriptionValidationResult {
        return SubscriptionValidationResult(
            isValid: false,
            tier: .free,
            status: .inactive,
            error: error
        )
    }
    
    /// Create a free tier result
    static func freeTier() -> SubscriptionValidationResult {
        return SubscriptionValidationResult(
            isValid: true,
            tier: .free,
            status: .active,
            availableFeatures: User.featuresForTier(.free)
        )
    }
}

public extension FeatureAccessResult {
    
    /// Create a granted access result
    static func granted(for feature: Feature, requiredTier: SubscriptionTier = .free) -> FeatureAccessResult {
        return FeatureAccessResult(
            hasAccess: true,
            feature: feature,
            requiredTier: requiredTier
        )
    }
    
    /// Create a denied access result
    static func denied(
        for feature: Feature,
        reason: FeatureDenialReason,
        requiredTier: SubscriptionTier = .pro
    ) -> FeatureAccessResult {
        return FeatureAccessResult(
            hasAccess: false,
            feature: feature,
            denialReason: reason,
            requiredTier: requiredTier
        )
    }
}

public extension SyncAccessResult {
    
    /// Create a granted sync access result
    static func granted(
        for syncType: SyncOperationType,
        allowedFrequency: SyncFrequency? = nil
    ) -> SyncAccessResult {
        return SyncAccessResult(
            hasAccess: true,
            syncType: syncType,
            allowedFrequency: allowedFrequency
        )
    }
    
    /// Create a denied sync access result
    static func denied(
        for syncType: SyncOperationType,
        reason: SyncDenialReason
    ) -> SyncAccessResult {
        return SyncAccessResult(
            hasAccess: false,
            syncType: syncType,
            denialReason: reason
        )
    }
}