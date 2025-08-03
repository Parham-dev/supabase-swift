//
//  SubscriptionViewModel.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for managing subscription status, feature access, and upgrade flows
/// Provides comprehensive subscription management for SwiftUI views with real-time validation
@MainActor
public final class SubscriptionViewModel: ObservableObject {
    
    // MARK: - Subscription Status Properties
    
    /// Current subscription validation result
    @Published public private(set) var subscriptionStatus: SubscriptionValidationResult?
    
    /// Whether subscription is currently being validated
    @Published public private(set) var isValidating: Bool = false
    
    /// Current subscription tier
    @Published public private(set) var currentTier: SubscriptionTier = .free
    
    /// Whether user has an active subscription
    @Published public private(set) var hasActiveSubscription: Bool = false
    
    /// Available features for current subscription
    @Published public private(set) var availableFeatures: Set<Feature> = []
    
    /// Last subscription validation error
    @Published public private(set) var lastValidationError: SubscriptionValidationError?
    
    // MARK: - Feature Access Management
    
    /// Feature access results cache
    @Published public private(set) var featureAccessCache: [Feature: FeatureAccessResult] = [:]
    
    /// Features currently being validated
    @Published public private(set) var featuresBeingValidated: Set<Feature> = []
    
    /// Quick access flags for common features
    @Published public private(set) var hasRealtimeSync: Bool = false
    @Published public private(set) var hasConflictResolution: Bool = false
    @Published public private(set) var hasMultiDevice: Bool = false
    @Published public private(set) var hasCustomSchemas: Bool = false
    @Published public private(set) var hasAdvancedLogging: Bool = false
    @Published public private(set) var hasPrioritySupport: Bool = false
    
    // MARK: - Usage Limits and Quotas
    
    /// Current usage limits status
    @Published public private(set) var usageLimits: [SubscriptionLimit: LimitValidationResult] = [:]
    
    /// Whether any usage limits are approaching (>80%)
    @Published public private(set) var hasUsageWarnings: Bool = false
    
    /// Whether any usage limits are exceeded
    @Published public private(set) var hasUsageLimitExceeded: Bool = false
    
    /// Storage quota information
    @Published public private(set) var storageQuota: LimitValidationResult?
    
    /// API calls quota information
    @Published public private(set) var apiCallsQuota: LimitValidationResult?
    
    // MARK: - Subscription Insights
    
    /// Time until subscription expires
    @Published public private(set) var timeUntilExpiration: TimeInterval?
    
    /// Whether subscription is expiring soon (within 7 days)
    @Published public private(set) var isExpiringSoon: Bool = false
    
    /// Recommended subscription tier based on usage
    @Published public private(set) var recommendedTier: SubscriptionTier?
    
    /// Benefits of upgrading to higher tier
    @Published public private(set) var upgradeRecommendations: [UpgradeRecommendation] = []
    
    // MARK: - UI State
    
    /// Whether to show upgrade prompts
    @Published public var showUpgradePrompts: Bool = true
    
    /// Whether to show detailed usage statistics
    @Published public var showUsageDetails: Bool = false
    
    /// Selected feature for detailed information
    @Published public var selectedFeature: Feature?
    
    /// Whether upgrade flow is in progress
    @Published public private(set) var isUpgradeInProgress: Bool = false
    
    /// Current subscription operation status
    @Published public private(set) var operationStatus: SubscriptionOperationStatus = .idle
    
    // MARK: - Dependencies
    
    private let subscriptionManager: SubscriptionManager
    private let authStatePublisher: AuthStatePublisher
    private let networkStatusPublisher: NetworkStatusPublisher
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let autoRefreshInterval: TimeInterval = 300 // 5 minutes
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    public init(
        subscriptionManager: SubscriptionManager,
        authStatePublisher: AuthStatePublisher,
        networkStatusPublisher: NetworkStatusPublisher
    ) {
        self.subscriptionManager = subscriptionManager
        self.authStatePublisher = authStatePublisher
        self.networkStatusPublisher = networkStatusPublisher
        
        setupBindings()
        setupAutoRefresh()
        
        Task {
            await refreshSubscriptionData()
        }
    }
    
    // MARK: - Subscription Operations
    
    /// Refresh subscription status and feature access
    public func refreshSubscriptionData() async {
        guard !isValidating else { return }
        
        await validateSubscription()
        await validateAllFeatures()
        await validateUsageLimits()
        await updateSubscriptionInsights()
    }
    
    /// Validate current subscription status
    public func validateSubscription(forceRefresh: Bool = false) async {
        isValidating = true
        operationStatus = .validating
        
        let result = await subscriptionManager.validateSubscription(forceRefresh: forceRefresh)
        
        await MainActor.run {
            self.subscriptionStatus = result
            self.currentTier = result.tier
            self.hasActiveSubscription = result.isValid && !result.isExpired
            self.availableFeatures = result.availableFeatures
            self.lastValidationError = result.error
            self.isValidating = false
            self.operationStatus = result.error != nil ? .failed : .completed
            
            self.updateQuickAccessFlags()
            self.updateExpirationInfo()
        }
    }
    
    /// Check access to a specific feature
    public func validateFeatureAccess(_ feature: Feature) async -> FeatureAccessResult {
        guard !featuresBeingValidated.contains(feature) else {
            return featureAccessCache[feature] ?? FeatureAccessResult.denied(
                for: feature,
                reason: .validationFailed,
                requiredTier: .pro
            )
        }
        
        featuresBeingValidated.insert(feature)
        
        let result = await subscriptionManager.validateFeatureAccess(feature)
        
        await MainActor.run {
            self.featureAccessCache[feature] = result
            self.featuresBeingValidated.remove(feature)
        }
        
        return result
    }
    
    /// Validate access to multiple features at once
    public func validateFeatures(_ features: Set<Feature>) async {
        for feature in features {
            _ = await validateFeatureAccess(feature)
        }
    }
    
    /// Validate all common features
    public func validateAllFeatures() async {
        await validateFeatures(Set(Feature.allCases))
    }
    
    // MARK: - Usage Limits Management
    
    /// Validate all usage limits
    public func validateUsageLimits() async {
        guard authStatePublisher.currentUser != nil else { return }
        
        operationStatus = .checkingUsage
        
        var limitResults: [SubscriptionLimit: LimitValidationResult] = [:]
        var hasWarnings = false
        var hasExceeded = false
        
        for limitType in SubscriptionLimit.allCases {
            let result = await subscriptionManager.validateLimit(limitType)
            limitResults[limitType] = result
            
            // Check for warnings (>80% usage)
            if result.usagePercentage > 0.8 && result.withinLimit {
                hasWarnings = true
            }
            
            // Check for exceeded limits
            if !result.withinLimit {
                hasExceeded = true
            }
        }
        
        await MainActor.run {
            self.usageLimits = limitResults
            self.hasUsageWarnings = hasWarnings
            self.hasUsageLimitExceeded = hasExceeded
            self.storageQuota = limitResults[.storageQuota]
            self.apiCallsQuota = limitResults[.apiCalls]
            self.operationStatus = .completed
        }
    }
    
    /// Get usage percentage for a specific limit
    public func getUsagePercentage(for limitType: SubscriptionLimit) -> Double {
        return usageLimits[limitType]?.usagePercentage ?? 0.0
    }
    
    /// Get usage description for a specific limit
    public func getUsageDescription(for limitType: SubscriptionLimit) -> String {
        guard let limit = usageLimits[limitType] else {
            return "Usage data unavailable"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        let current = formatter.string(from: NSNumber(value: limit.currentUsage)) ?? "0"
        let maximum = formatter.string(from: NSNumber(value: limit.maximumAllowed)) ?? "0"
        
        return "\(current) / \(maximum) \(getUnitForLimit(limitType))"
    }
    
    // MARK: - Upgrade Management
    
    /// Start subscription upgrade flow
    public func startUpgradeFlow(to targetTier: SubscriptionTier) async {
        guard !isUpgradeInProgress else { return }
        
        isUpgradeInProgress = true
        operationStatus = .upgrading
        
        // In a real implementation, this would integrate with payment system
        // For now, we'll simulate the upgrade process
        
        await simulateUpgradeProcess(to: targetTier)
    }
    
    /// Cancel active subscription
    public func cancelSubscription() async {
        guard hasActiveSubscription else { return }
        
        operationStatus = .cancelling
        
        // In a real implementation, this would call the subscription API
        // For now, we'll simulate the cancellation
        
        await simulateCancellationProcess()
    }
    
    /// Generate upgrade recommendations based on usage
    public func generateUpgradeRecommendations() async {
        var recommendations: [UpgradeRecommendation] = []
        
        // Analyze usage patterns and generate recommendations
        if hasUsageLimitExceeded {
            recommendations.append(
                UpgradeRecommendation(
                    reason: .quotaExceeded,
                    targetTier: .pro,
                    benefits: ["Increased storage quota", "Higher API limits", "Priority support"],
                    estimatedSavings: nil
                )
            )
        }
        
        if !hasRealtimeSync && currentTier == .free {
            recommendations.append(
                UpgradeRecommendation(
                    reason: .featureAccess,
                    targetTier: .pro,
                    benefits: ["Real-time synchronization", "Conflict resolution", "Multi-device support"],
                    estimatedSavings: nil
                )
            )
        }
        
        if hasUsageWarnings {
            recommendations.append(
                UpgradeRecommendation(
                    reason: .approachingLimits,
                    targetTier: .pro,
                    benefits: ["Higher usage limits", "Better performance", "Advanced features"],
                    estimatedSavings: nil
                )
            )
        }
        
        await MainActor.run {
            self.upgradeRecommendations = recommendations
            self.recommendedTier = recommendations.first?.targetTier
        }
    }
    
    // MARK: - Feature Information
    
    /// Get detailed information about a feature
    public func getFeatureInfo(_ feature: Feature) -> FeatureInfo {
        let hasAccess = featureAccessCache[feature]?.hasAccess ?? availableFeatures.contains(feature)
        let requiredTier = getRequiredTierForFeature(feature)
        
        return FeatureInfo(
            feature: feature,
            hasAccess: hasAccess,
            requiredTier: requiredTier,
            description: getFeatureDescription(feature),
            benefits: getFeatureBenefits(feature)
        )
    }
    
    /// Check if user can access a feature (with caching)
    public func canAccessFeature(_ feature: Feature) -> Bool {
        // Check cache first
        if let cachedResult = featureAccessCache[feature] {
            return cachedResult.hasAccess
        }
        
        // Fall back to subscription features
        return availableFeatures.contains(feature)
    }
    
    // MARK: - Computed Properties
    
    /// Whether user is on free tier
    public var isFreeTier: Bool {
        return currentTier == .free
    }
    
    /// Whether user is on pro tier
    public var isProTier: Bool {
        return currentTier == .pro
    }
    
    /// Whether user is on enterprise tier
    public var isEnterpriseTier: Bool {
        return currentTier == .enterprise
    }
    
    /// Subscription status color for UI
    public var statusColor: Color {
        if hasActiveSubscription {
            return isExpiringSoon ? .orange : .green
        } else {
            return .red
        }
    }
    
    /// Subscription status icon for UI
    public var statusIcon: String {
        if hasActiveSubscription {
            return isExpiringSoon ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        } else {
            return "xmark.circle.fill"
        }
    }
    
    /// User-friendly subscription status message
    public var statusMessage: String {
        guard let status = subscriptionStatus else {
            return "Subscription status unknown"
        }
        
        if let error = status.error {
            return "Error: \(error.localizedDescription)"
        }
        
        if !status.isValid {
            return "No active subscription"
        }
        
        if status.isExpired {
            return "Subscription expired"
        }
        
        if isExpiringSoon, let timeUntil = timeUntilExpiration {
            let days = Int(timeUntil / 86400)
            return "Expires in \(days) day(s)"
        }
        
        return "\(currentTier.displayName) subscription active"
    }
    
    // MARK: - Private Implementation
    
    private func setupBindings() {
        // Monitor subscription manager state
        subscriptionManager.$subscriptionStatus
            .sink { [weak self] status in
                Task { [weak self] in
                    await self?.handleSubscriptionStatusUpdate(status)
                }
            }
            .store(in: &cancellables)
        
        subscriptionManager.$isValidating
            .assign(to: \.isValidating, on: self)
            .store(in: &cancellables)
        
        subscriptionManager.$availableFeatures
            .sink { [weak self] features in
                self?.availableFeatures = features
                self?.updateQuickAccessFlags()
            }
            .store(in: &cancellables)
        
        subscriptionManager.$currentTier
            .assign(to: \.currentTier, on: self)
            .store(in: &cancellables)
        
        subscriptionManager.$hasActiveSubscription
            .assign(to: \.hasActiveSubscription, on: self)
            .store(in: &cancellables)
        
        subscriptionManager.$lastValidationError
            .assign(to: \.lastValidationError, on: self)
            .store(in: &cancellables)
        
        subscriptionManager.$featureAccessCache
            .assign(to: \.featureAccessCache, on: self)
            .store(in: &cancellables)
        
        subscriptionManager.$usageLimits
            .sink { [weak self] limits in
                self?.handleUsageLimitsUpdate(limits)
            }
            .store(in: &cancellables)
        
        // Monitor authentication changes
        authStatePublisher.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task { [weak self] in
                        await self?.refreshSubscriptionData()
                    }
                } else {
                    Task { [weak self] in
                        await self?.clearSubscriptionData()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: autoRefreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { [weak self] in
                await self?.refreshSubscriptionData()
            }
        }
    }
    
    private func handleSubscriptionStatusUpdate(_ status: SubscriptionValidationResult?) async {
        await MainActor.run {
            self.subscriptionStatus = status
            if let status = status {
                self.currentTier = status.tier
                self.hasActiveSubscription = status.isValid && !status.isExpired
                self.availableFeatures = status.availableFeatures
                self.lastValidationError = status.error
                
                self.updateQuickAccessFlags()
                self.updateExpirationInfo()
            }
        }
    }
    
    private func handleUsageLimitsUpdate(_ limits: [SubscriptionLimit: LimitValidationResult]) {
        usageLimits = limits
        
        var hasWarnings = false
        var hasExceeded = false
        
        for (_, result) in limits {
            if result.usagePercentage > 0.8 && result.withinLimit {
                hasWarnings = true
            }
            if !result.withinLimit {
                hasExceeded = true
            }
        }
        
        hasUsageWarnings = hasWarnings
        hasUsageLimitExceeded = hasExceeded
        storageQuota = limits[.storageQuota]
        apiCallsQuota = limits[.apiCalls]
    }
    
    private func updateQuickAccessFlags() {
        hasRealtimeSync = availableFeatures.contains(.realtimeSync)
        hasConflictResolution = availableFeatures.contains(.conflictResolution)
        hasMultiDevice = availableFeatures.contains(.multiDevice)
        hasCustomSchemas = availableFeatures.contains(.customSchemas)
        hasAdvancedLogging = availableFeatures.contains(.advancedLogging)
        hasPrioritySupport = availableFeatures.contains(.prioritySupport)
    }
    
    private func updateExpirationInfo() {
        guard let status = subscriptionStatus else {
            timeUntilExpiration = nil
            isExpiringSoon = false
            return
        }
        
        timeUntilExpiration = status.timeUntilExpiration
        
        if let timeUntil = timeUntilExpiration {
            isExpiringSoon = timeUntil > 0 && timeUntil < 604800 // 7 days
        } else {
            isExpiringSoon = false
        }
    }
    
    private func updateSubscriptionInsights() async {
        await generateUpgradeRecommendations()
    }
    
    private func clearSubscriptionData() async {
        await MainActor.run {
            self.subscriptionStatus = nil
            self.currentTier = .free
            self.hasActiveSubscription = false
            self.availableFeatures = User.featuresForTier(.free)
            self.lastValidationError = nil
            self.featureAccessCache.removeAll()
            self.usageLimits.removeAll()
            self.hasUsageWarnings = false
            self.hasUsageLimitExceeded = false
            self.timeUntilExpiration = nil
            self.isExpiringSoon = false
            self.upgradeRecommendations.removeAll()
            self.recommendedTier = nil
            
            self.updateQuickAccessFlags()
        }
    }
    
    // MARK: - Simulation Methods (for demonstration)
    
    private func simulateUpgradeProcess(to targetTier: SubscriptionTier) async {
        // Simulate upgrade process with delays
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await MainActor.run {
            self.isUpgradeInProgress = false
            self.operationStatus = .completed
        }
        
        // Refresh subscription data after upgrade
        await refreshSubscriptionData()
    }
    
    private func simulateCancellationProcess() async {
        // Simulate cancellation process with delays
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        await MainActor.run {
            self.operationStatus = .completed
        }
        
        // Refresh subscription data after cancellation
        await refreshSubscriptionData()
    }
    
    // MARK: - Helper Methods
    
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
    
    private func getFeatureDescription(_ feature: Feature) -> String {
        switch feature {
        case .basicSync:
            return "Synchronize your data across devices"
        case .realtimeSync:
            return "Real-time data synchronization with instant updates"
        case .conflictResolution:
            return "Automatic conflict resolution for concurrent changes"
        case .multiDevice:
            return "Sync across unlimited devices"
        case .customSchemas:
            return "Define custom data schemas and validation rules"
        case .advancedLogging:
            return "Detailed logging and debugging information"
        case .prioritySupport:
            return "Priority customer support with faster response times"
        case .customBackup:
            return "Custom backup solutions and data export options"
        }
    }
    
    private func getFeatureBenefits(_ feature: Feature) -> [String] {
        switch feature {
        case .basicSync:
            return ["Data consistency", "Offline support", "Automatic sync"]
        case .realtimeSync:
            return ["Instant updates", "Collaborative editing", "Live data"]
        case .conflictResolution:
            return ["Automatic conflict handling", "Data integrity", "Smooth collaboration"]
        case .multiDevice:
            return ["Unlimited devices", "Cross-platform sync", "Enhanced productivity"]
        case .customSchemas:
            return ["Flexible data models", "Custom validation", "Advanced features"]
        case .advancedLogging:
            return ["Detailed diagnostics", "Performance insights", "Debug support"]
        case .prioritySupport:
            return ["Faster response", "Priority queue", "Expert assistance"]
        case .customBackup:
            return ["Data security", "Custom exports", "Business continuity"]
        }
    }
    
    private func getUnitForLimit(_ limitType: SubscriptionLimit) -> String {
        switch limitType {
        case .storageQuota:
            return "MB"
        case .syncOperations, .apiCalls:
            return "per month"
        case .realtimeConnections:
            return "concurrent"
        case .modelCount, .recordCount:
            return "items"
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        refreshTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

/// Subscription operation status
public enum SubscriptionOperationStatus {
    case idle
    case validating
    case checkingUsage
    case upgrading
    case cancelling
    case completed
    case failed
}

/// Upgrade recommendation information
public struct UpgradeRecommendation: Identifiable {
    public let id = UUID()
    public let reason: UpgradeReason
    public let targetTier: SubscriptionTier
    public let benefits: [String]
    public let estimatedSavings: Double?
    
    public enum UpgradeReason {
        case quotaExceeded
        case featureAccess
        case approachingLimits
        case betterPerformance
    }
}

/// Feature information for UI display
public struct FeatureInfo {
    public let feature: Feature
    public let hasAccess: Bool
    public let requiredTier: SubscriptionTier
    public let description: String
    public let benefits: [String]
}

// MARK: - Extensions

extension SubscriptionTier {
    public var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        case .enterprise:
            return "Enterprise"
        case .custom(let name):
            return name
        }
    }
    
    public var color: Color {
        switch self {
        case .free:
            return .gray
        case .pro:
            return .blue
        case .enterprise:
            return .purple
        case .custom:
            return .orange
        }
    }
}

extension UpgradeRecommendation.UpgradeReason {
    public var title: String {
        switch self {
        case .quotaExceeded:
            return "Quota Exceeded"
        case .featureAccess:
            return "Unlock Premium Features"
        case .approachingLimits:
            return "Approaching Limits"
        case .betterPerformance:
            return "Better Performance"
        }
    }
    
    public var description: String {
        switch self {
        case .quotaExceeded:
            return "You've exceeded your current plan's limits. Upgrade for higher quotas."
        case .featureAccess:
            return "Unlock advanced features like real-time sync and conflict resolution."
        case .approachingLimits:
            return "You're approaching your plan's limits. Upgrade to avoid service interruption."
        case .betterPerformance:
            return "Upgrade for better performance and enhanced features."
        }
    }
}