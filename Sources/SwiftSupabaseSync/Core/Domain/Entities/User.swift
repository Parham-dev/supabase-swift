import Foundation

/// Domain entity representing a user in the synchronization system
/// Contains authentication state, permissions, and subscription information
public struct User {
    
    // MARK: - Core Properties
    
    /// Unique identifier for the user from Supabase Auth
    public let id: UUID
    
    /// User's email address
    public let email: String
    
    /// Display name or full name
    public let name: String?
    
    /// Profile image URL
    public let avatarURL: URL?
    
    /// Timestamp when the user account was created
    public let createdAt: Date
    
    /// Timestamp when the user last updated their profile
    public let updatedAt: Date
    
    // MARK: - Authentication State
    
    /// Current authentication status
    public let authenticationStatus: AuthenticationStatus
    
    /// Access token for API requests (stored securely)
    public let accessToken: String?
    
    /// Refresh token for token renewal
    public let refreshToken: String?
    
    /// Token expiration timestamp
    public let tokenExpiresAt: Date?
    
    /// Last successful authentication timestamp
    public let lastAuthenticatedAt: Date?
    
    // MARK: - Subscription & Permissions
    
    /// Current subscription tier
    public let subscriptionTier: SubscriptionTier
    
    /// Subscription status (active, expired, trial, etc.)
    public let subscriptionStatus: UserSubscriptionStatus
    
    /// Subscription expiration date
    public let subscriptionExpiresAt: Date?
    
    /// Features available to this user based on subscription
    public let availableFeatures: Set<Feature>
    
    // MARK: - Sync Preferences
    
    /// User's sync preferences and settings
    public let syncPreferences: SyncPreferences
    
    /// Whether user has enabled sync functionality
    public let isSyncEnabled: Bool
    
    /// Last successful sync timestamp
    public let lastSyncAt: Date?
    
    // MARK: - Initializer
    
    public init(
        id: UUID,
        email: String,
        name: String? = nil,
        avatarURL: URL? = nil,
        createdAt: Date,
        updatedAt: Date,
        authenticationStatus: AuthenticationStatus = .unauthenticated,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        tokenExpiresAt: Date? = nil,
        lastAuthenticatedAt: Date? = nil,
        subscriptionTier: SubscriptionTier = .free,
        subscriptionStatus: UserSubscriptionStatus = .inactive,
        subscriptionExpiresAt: Date? = nil,
        availableFeatures: Set<Feature> = [],
        syncPreferences: SyncPreferences = SyncPreferences(),
        isSyncEnabled: Bool = false,
        lastSyncAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.avatarURL = avatarURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authenticationStatus = authenticationStatus
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiresAt = tokenExpiresAt
        self.lastAuthenticatedAt = lastAuthenticatedAt
        self.subscriptionTier = subscriptionTier
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.availableFeatures = availableFeatures
        self.syncPreferences = syncPreferences
        self.isSyncEnabled = isSyncEnabled
        self.lastSyncAt = lastSyncAt
    }
}

// MARK: - Supporting Types

public enum AuthenticationStatus: Equatable {
    case authenticated
    case unauthenticated
    case expired
    case refreshing
    case error(AuthenticationError)
}

public enum SubscriptionTier: Equatable {
    case free
    case pro
    case enterprise
    case custom(String)
}

public enum Feature: String, CaseIterable, Codable {
    case basicSync = "basic_sync"
    case realtimeSync = "realtime_sync"
    case conflictResolution = "conflict_resolution"
    case multiDevice = "multi_device"
    case customSchemas = "custom_schemas"
    case advancedLogging = "advanced_logging"
    case prioritySupport = "priority_support"
    case customBackup = "custom_backup"
}

public struct SyncPreferences {
    /// How frequently to perform automatic sync
    public let syncFrequency: SyncFrequency
    
    /// Whether to sync only on Wi-Fi
    public let wifiOnly: Bool
    
    /// Whether to show sync status notifications
    public let showNotifications: Bool
    
    /// Maximum number of sync retries
    public let maxRetries: Int
    
    /// Conflict resolution strategy preference
    public let conflictResolution: ConflictResolutionStrategy
    
    public init(
        syncFrequency: SyncFrequency = .automatic,
        wifiOnly: Bool = false,
        showNotifications: Bool = true,
        maxRetries: Int = 3,
        conflictResolution: ConflictResolutionStrategy = .lastWriteWins
    ) {
        self.syncFrequency = syncFrequency
        self.wifiOnly = wifiOnly
        self.showNotifications = showNotifications
        self.maxRetries = maxRetries
        self.conflictResolution = conflictResolution
    }
}


public enum UserSubscriptionStatus: String, Codable {
    case active
    case inactive
    case expired
    case trial
    case cancelled
    case pending
}

public enum AuthenticationError: Error, LocalizedError, Equatable, Codable {
    case invalidCredentials
    case networkError
    case tokenExpired
    case tokenRefreshFailed
    case userNotFound
    case emailNotVerified
    case accountLocked
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection error"
        case .tokenExpired:
            return "Authentication token has expired"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .userNotFound:
            return "User account not found"
        case .emailNotVerified:
            return "Email address not verified"
        case .accountLocked:
            return "Account has been locked"
        case .unknownError(let message):
            return "Authentication error: \(message)"
        }
    }
}

// MARK: - User Extensions

extension User {
    /// Check if user has a specific feature available
    public func hasFeature(_ feature: Feature) -> Bool {
        return availableFeatures.contains(feature)
    }
    
    /// Check if user is currently authenticated with valid token
    public var isAuthenticated: Bool {
        guard authenticationStatus == .authenticated else { return false }
        guard let expiresAt = tokenExpiresAt else { return false }
        return Date() < expiresAt
    }
    
    /// Check if authentication token needs refresh
    public var needsTokenRefresh: Bool {
        guard let expiresAt = tokenExpiresAt else { return false }
        let refreshThreshold = expiresAt.addingTimeInterval(-300) // 5 minutes before expiry
        return Date() >= refreshThreshold
    }
    
    /// Check if user has an active subscription
    public var hasActiveSubscription: Bool {
        guard subscriptionStatus == .active else { return false }
        guard let expiresAt = subscriptionExpiresAt else { return true }
        return Date() < expiresAt
    }
    
    /// Get features available based on subscription tier
    public static func featuresForTier(_ tier: SubscriptionTier) -> Set<Feature> {
        switch tier {
        case .free:
            return [.basicSync]
        case .pro:
            return [.basicSync, .realtimeSync, .conflictResolution, .multiDevice]
        case .enterprise:
            return Set(Feature.allCases)
        case .custom:
            return [] // Should be configured separately
        }
    }
    
    /// Create a copy with updated authentication status
    public func withAuthenticationStatus(_ status: AuthenticationStatus) -> User {
        User(
            id: id,
            email: email,
            name: name,
            avatarURL: avatarURL,
            createdAt: createdAt,
            updatedAt: Date(),
            authenticationStatus: status,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiresAt: tokenExpiresAt,
            lastAuthenticatedAt: status == .authenticated ? Date() : lastAuthenticatedAt,
            subscriptionTier: subscriptionTier,
            subscriptionStatus: subscriptionStatus,
            subscriptionExpiresAt: subscriptionExpiresAt,
            availableFeatures: availableFeatures,
            syncPreferences: syncPreferences,
            isSyncEnabled: isSyncEnabled,
            lastSyncAt: lastSyncAt
        )
    }
    
    /// Create a copy with updated tokens
    public func withTokens(
        accessToken: String?,
        refreshToken: String?,
        expiresAt: Date?
    ) -> User {
        User(
            id: id,
            email: email,
            name: name,
            avatarURL: avatarURL,
            createdAt: createdAt,
            updatedAt: Date(),
            authenticationStatus: authenticationStatus,
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenExpiresAt: expiresAt,
            lastAuthenticatedAt: lastAuthenticatedAt,
            subscriptionTier: subscriptionTier,
            subscriptionStatus: subscriptionStatus,
            subscriptionExpiresAt: subscriptionExpiresAt,
            availableFeatures: availableFeatures,
            syncPreferences: syncPreferences,
            isSyncEnabled: isSyncEnabled,
            lastSyncAt: lastSyncAt
        )
    }
}

// MARK: - Equatable & Hashable

extension User: Equatable {
    public static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id &&
               lhs.email == rhs.email &&
               lhs.updatedAt == rhs.updatedAt
    }
}

extension User: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(email)
        hasher.combine(updatedAt)
    }
}

// MARK: - Codable Support

extension User: Codable {
    enum CodingKeys: String, CodingKey {
        case id, email, name
        case avatarURL = "avatar_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authenticationStatus = "auth_status"
        case tokenExpiresAt = "token_expires_at"
        case lastAuthenticatedAt = "last_authenticated_at"
        case subscriptionTier = "subscription_tier"
        case subscriptionStatus = "subscription_status"
        case subscriptionExpiresAt = "subscription_expires_at"
        case availableFeatures = "available_features"
        case syncPreferences = "sync_preferences"
        case isSyncEnabled = "is_sync_enabled"
        case lastSyncAt = "last_sync_at"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        authenticationStatus = try container.decode(AuthenticationStatus.self, forKey: .authenticationStatus)
        
        // Sensitive fields are not decoded from external sources
        accessToken = nil
        refreshToken = nil
        tokenExpiresAt = try container.decodeIfPresent(Date.self, forKey: .tokenExpiresAt)
        lastAuthenticatedAt = try container.decodeIfPresent(Date.self, forKey: .lastAuthenticatedAt)
        
        subscriptionTier = try container.decode(SubscriptionTier.self, forKey: .subscriptionTier)
        subscriptionStatus = try container.decode(UserSubscriptionStatus.self, forKey: .subscriptionStatus)
        subscriptionExpiresAt = try container.decodeIfPresent(Date.self, forKey: .subscriptionExpiresAt)
        availableFeatures = try container.decode(Set<Feature>.self, forKey: .availableFeatures)
        syncPreferences = try container.decode(SyncPreferences.self, forKey: .syncPreferences)
        isSyncEnabled = try container.decode(Bool.self, forKey: .isSyncEnabled)
        lastSyncAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncAt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(authenticationStatus, forKey: .authenticationStatus)
        
        // Sensitive fields are not encoded
        try container.encodeIfPresent(tokenExpiresAt, forKey: .tokenExpiresAt)
        try container.encodeIfPresent(lastAuthenticatedAt, forKey: .lastAuthenticatedAt)
        
        try container.encode(subscriptionTier, forKey: .subscriptionTier)
        try container.encode(subscriptionStatus, forKey: .subscriptionStatus)
        try container.encodeIfPresent(subscriptionExpiresAt, forKey: .subscriptionExpiresAt)
        try container.encode(availableFeatures, forKey: .availableFeatures)
        try container.encode(syncPreferences, forKey: .syncPreferences)
        try container.encode(isSyncEnabled, forKey: .isSyncEnabled)
        try container.encodeIfPresent(lastSyncAt, forKey: .lastSyncAt)
    }
}

// MARK: - Codable Extensions for Supporting Types

extension AuthenticationStatus: Codable {
    enum CodingKeys: String, CodingKey {
        case type, error
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "authenticated":
            self = .authenticated
        case "unauthenticated":
            self = .unauthenticated
        case "expired":
            self = .expired
        case "refreshing":
            self = .refreshing
        case "error":
            let error = try container.decode(AuthenticationError.self, forKey: .error)
            self = .error(error)
        default:
            self = .unauthenticated
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .authenticated:
            try container.encode("authenticated", forKey: .type)
        case .unauthenticated:
            try container.encode("unauthenticated", forKey: .type)
        case .expired:
            try container.encode("expired", forKey: .type)
        case .refreshing:
            try container.encode("refreshing", forKey: .type)
        case .error(let error):
            try container.encode("error", forKey: .type)
            try container.encode(error, forKey: .error)
        }
    }
}

extension SubscriptionTier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        
        switch value {
        case "free":
            self = .free
        case "pro":
            self = .pro
        case "enterprise":
            self = .enterprise
        default:
            self = .custom(value)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .free:
            try container.encode("free")
        case .pro:
            try container.encode("pro")
        case .enterprise:
            try container.encode("enterprise")
        case .custom(let value):
            try container.encode(value)
        }
    }
}

extension SyncPreferences: Codable {}
