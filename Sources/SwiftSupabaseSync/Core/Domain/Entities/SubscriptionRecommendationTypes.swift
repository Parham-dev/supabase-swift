//
//  SubscriptionRecommendationTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Subscription Recommendations

/// Comprehensive subscription recommendations based on usage analysis
public struct SubscriptionRecommendations: Codable, Equatable {
    /// User's current subscription tier
    public let currentTier: SubscriptionTier
    
    /// List of recommendations
    public let suggestions: [SubscriptionSuggestion]
    
    /// Usage analysis that informed recommendations
    public let usage: UsageAnalysis
    
    /// When recommendations were generated
    public let generatedAt: Date
    
    public init(
        currentTier: SubscriptionTier,
        suggestions: [SubscriptionSuggestion],
        usage: UsageAnalysis,
        generatedAt: Date = Date()
    ) {
        self.currentTier = currentTier
        self.suggestions = suggestions
        self.usage = usage
        self.generatedAt = generatedAt
    }
}

/// Individual subscription suggestion for user improvement
public struct SubscriptionSuggestion: Codable, Equatable {
    /// Type of suggestion
    public let type: SuggestionType
    
    /// Target subscription tier
    public let targetTier: SubscriptionTier
    
    /// Reason for the suggestion
    public let reason: String
    
    /// Benefits of following the suggestion
    public let benefits: [String]
    
    /// Priority level
    public let priority: SuggestionPriority
    
    public init(
        type: SuggestionType,
        targetTier: SubscriptionTier,
        reason: String,
        benefits: [String],
        priority: SuggestionPriority = .medium
    ) {
        self.type = type
        self.targetTier = targetTier
        self.reason = reason
        self.benefits = benefits
        self.priority = priority
    }
}

/// Analysis of user's usage patterns
public struct UsageAnalysis: Codable, Equatable {
    /// Primary features used by the user
    public let primaryFeatures: [Feature]
    
    /// Overall usage frequency
    public let usageFrequency: UsageFrequency
    
    /// Storage usage as percentage of quota
    public let storageUsage: Double
    
    /// How often user syncs
    public let syncFrequency: SyncUsageFrequency
    
    public init(
        primaryFeatures: [Feature],
        usageFrequency: UsageFrequency,
        storageUsage: Double,
        syncFrequency: SyncUsageFrequency
    ) {
        self.primaryFeatures = primaryFeatures
        self.usageFrequency = usageFrequency
        self.storageUsage = storageUsage
        self.syncFrequency = syncFrequency
    }
}

// MARK: - Suggestion Enums

/// Types of subscription suggestions
public enum SuggestionType: String, Codable, CaseIterable {
    case upgrade = "upgrade"
    case downgrade = "downgrade"
    case optimize = "optimize"
    case feature = "feature"
}

/// Priority levels for subscription suggestions
public enum SuggestionPriority: String, Codable, CaseIterable, Comparable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public static func < (lhs: SuggestionPriority, rhs: SuggestionPriority) -> Bool {
        let order: [SuggestionPriority] = [.low, .medium, .high, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

// MARK: - Usage Frequency Enums

/// Overall usage frequency categories
public enum UsageFrequency: String, Codable, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case intensive = "intensive"
}

/// Synchronization usage frequency patterns
public enum SyncUsageFrequency: String, Codable, CaseIterable {
    case rarely = "rarely"
    case weekly = "weekly"
    case daily = "daily"
    case hourly = "hourly"
    case realtime = "realtime"
}