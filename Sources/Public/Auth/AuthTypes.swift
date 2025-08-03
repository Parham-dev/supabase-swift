//
//  AuthTypes.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Foundation
import Combine

// MARK: - Authentication Status

/// Public authentication status enum
public enum PublicAuthenticationStatus: String, CaseIterable, Sendable {
    case signedOut = "signed_out"
    case signingIn = "signing_in"
    case signedIn = "signed_in"
    case signingOut = "signing_out"
    case refreshingToken = "refreshing_token"
    case sessionExpired = "session_expired"
    case error = "error"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .signedOut: return "Signed Out"
        case .signingIn: return "Signing In"
        case .signedIn: return "Signed In"
        case .signingOut: return "Signing Out"
        case .refreshingToken: return "Refreshing Token"
        case .sessionExpired: return "Session Expired"
        case .error: return "Authentication Error"
        }
    }
    
    /// Whether user can perform sync operations in this state
    public var canSync: Bool {
        return self == .signedIn
    }
    
    /// Whether authentication is in a loading state
    public var isLoading: Bool {
        switch self {
        case .signingIn, .signingOut, .refreshingToken:
            return true
        case .signedOut, .signedIn, .sessionExpired, .error:
            return false
        }
    }
    
    /// Convert from internal authentication status
    internal static func fromInternal(_ status: AuthenticationStatus) -> PublicAuthenticationStatus {
        switch status {
        case .unauthenticated: return .signedOut
        case .authenticated: return .signedIn
        case .expired: return .sessionExpired
        case .refreshing: return .refreshingToken
        case .error(_): return .error
        }
    }
}

// MARK: - Authentication Result

/// Public authentication result for external consumers
public struct PublicAuthenticationResult: Sendable {
    /// Whether authentication was successful
    public let isSuccess: Bool
    
    /// Authenticated user information (if successful)
    public let user: UserInfo?
    
    /// Whether this represents a new user registration
    public let isNewUser: Bool
    
    /// Authentication timestamp
    public let authenticatedAt: Date
    
    /// Error information (if failed)
    public let error: SwiftSupabaseSyncError?
    
    public init(
        isSuccess: Bool,
        user: UserInfo? = nil,
        isNewUser: Bool = false,
        authenticatedAt: Date = Date(),
        error: SwiftSupabaseSyncError? = nil
    ) {
        self.isSuccess = isSuccess
        self.user = user
        self.isNewUser = isNewUser
        self.authenticatedAt = authenticatedAt
        self.error = error
    }
}

// MARK: - Authentication Error Types
// Note: PublicAuthenticationError is defined in PublicErrors.swift to avoid duplication

/// Specific registration failure reasons
public enum RegistrationFailureReason: String, CaseIterable, Sendable {
    case emailAlreadyExists = "email_already_exists"
    case weakPassword = "weak_password"
    case invalidEmail = "invalid_email"
    case networkError = "network_error"
    case serverError = "server_error"
    case termsNotAccepted = "terms_not_accepted"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .emailAlreadyExists: return "Email address already registered"
        case .weakPassword: return "Password does not meet requirements"
        case .invalidEmail: return "Invalid email address format"
        case .networkError: return "Network connection error"
        case .serverError: return "Server error occurred"
        case .termsNotAccepted: return "Terms of service must be accepted"
        }
    }
}

// MARK: - Subscription Information

/// Subscription information for public consumption
public struct SubscriptionInfo: Sendable {
    /// Current subscription tier
    public let tier: PublicSubscriptionTier
    
    /// Available features for this tier
    public let availableFeatures: [SyncFeature]
    
    /// Maximum number of devices allowed
    public let maxDevices: Int
    
    /// Minimum sync interval allowed (in seconds)
    public let minSyncInterval: TimeInterval
    
    /// Whether subscription is active
    public let isActive: Bool
    
    /// Subscription expiration date (if applicable)
    public let expiresAt: Date?
    
    public init(
        tier: PublicSubscriptionTier,
        availableFeatures: [SyncFeature],
        maxDevices: Int,
        minSyncInterval: TimeInterval,
        isActive: Bool,
        expiresAt: Date? = nil
    ) {
        self.tier = tier
        self.availableFeatures = availableFeatures
        self.maxDevices = maxDevices
        self.minSyncInterval = minSyncInterval
        self.isActive = isActive
        self.expiresAt = expiresAt
    }
}

// MARK: - Authentication Extensions

public extension PublicAuthenticationResult {
    
    /// Whether this represents a successful authentication
    var wasSuccessful: Bool {
        return isSuccess && user != nil
    }
    
    /// Whether this represents a failed authentication
    var hasFailed: Bool {
        return !isSuccess || error != nil
    }
    
    /// Get user identifier if available
    var userID: UUID? {
        return user?.id
    }
    
    /// Get user email if available
    var userEmail: String? {
        return user?.email
    }
    
    /// Create a success result
    static func success(user: UserInfo, isNewUser: Bool = false) -> PublicAuthenticationResult {
        return PublicAuthenticationResult(
            isSuccess: true,
            user: user,
            isNewUser: isNewUser,
            authenticatedAt: Date()
        )
    }
    
    /// Create a failure result
    static func failure(error: SwiftSupabaseSyncError) -> PublicAuthenticationResult {
        return PublicAuthenticationResult(
            isSuccess: false,
            authenticatedAt: Date(),
            error: error
        )
    }
}

public extension SubscriptionInfo {
    
    /// Whether user has access to a specific feature
    /// - Parameter feature: The feature to check
    /// - Returns: True if feature is available
    func hasAccess(to feature: SyncFeature) -> Bool {
        return availableFeatures.contains(feature)
    }
    
    /// Get subscription status summary
    var statusSummary: String {
        if !isActive {
            return "Inactive (\(tier.displayName))"
        }
        
        if let expiresAt = expiresAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(tier.displayName) (expires \(formatter.string(from: expiresAt)))"
        }
        
        return tier.displayName
    }
    
    /// Whether subscription is near expiration (within 7 days)
    var isNearExpiration: Bool {
        guard let expiresAt = expiresAt else { return false }
        let sevenDaysFromNow = Date().addingTimeInterval(7 * 24 * 60 * 60)
        return expiresAt <= sevenDaysFromNow
    }
}