//
//  SupabaseAuthDataSource.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Remote data source for Supabase authentication operations
/// Handles user authentication, session management, and token operations
public final class SupabaseAuthDataSource {
    
    // MARK: - Properties
    
    private let httpClient: SupabaseClient
    private let keychainService: KeychainServiceProtocol
    private let baseURL: URL
    
    // MARK: - Initialization
    
    /// Initialize auth data source
    /// - Parameters:
    ///   - httpClient: HTTP client for API requests
    ///   - baseURL: Supabase project URL
    ///   - keychainService: Keychain service for secure token storage
    public init(
        httpClient: SupabaseClient,
        baseURL: URL,
        keychainService: KeychainServiceProtocol = KeychainService.shared
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.keychainService = keychainService
    }
    
    // MARK: - Authentication
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Authenticated user
    /// - Throws: AuthDataSourceError
    public func signIn(email: String, password: String) async throws -> User {
        do {
            let requestData = try JSONSerialization.data(withJSONObject: [
                "email": email,
                "password": password
            ])
            let request = RequestBuilder.post("/auth/v1/token", baseURL: baseURL)
                .header("grant_type", "password")
                .rawBody(requestData)
            
            let response: AuthResponse = try await httpClient.execute(request, expecting: AuthResponse.self)
            
            let user = try await convertToUser(from: response)
            try await storeAuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
            
            return user
            
        } catch {
            throw AuthDataSourceError.signInFailed(error.localizedDescription)
        }
    }
    
    /// Sign up with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - metadata: Optional user metadata
    /// - Returns: User (may require email confirmation)
    /// - Throws: AuthDataSourceError
    public func signUp(
        email: String,
        password: String,
        metadata: [String: Any]? = nil
    ) async throws -> User {
        do {
            var requestBody: [String: Any] = [
                "email": email,
                "password": password
            ]
            
            if let metadata = metadata {
                requestBody["data"] = metadata
            }
            
            let requestData = try JSONSerialization.data(withJSONObject: requestBody)
            let request = RequestBuilder.post("/auth/v1/signup", baseURL: baseURL)
                .rawBody(requestData)
            
            let response: AuthResponse = try await httpClient.execute(request, expecting: AuthResponse.self)
            
            let user = try await convertToUser(from: response)
            if let accessToken = response.accessToken, let refreshToken = response.refreshToken {
                try await storeAuthTokens(accessToken: accessToken, refreshToken: refreshToken)
            }
            
            return user
            
        } catch {
            throw AuthDataSourceError.signUpFailed(error.localizedDescription)
        }
    }
    
    /// Sign out current user
    /// - Throws: AuthDataSourceError
    public func signOut() async throws {
        do {
            let request = RequestBuilder.post("/auth/v1/logout", baseURL: baseURL)
            try await httpClient.execute(request)
            try await clearStoredTokens()
        } catch {
            throw AuthDataSourceError.signOutFailed(error.localizedDescription)
        }
    }
    
    /// Get current authenticated user
    /// - Returns: Current user if authenticated, nil otherwise
    /// - Throws: AuthDataSourceError
    public func getCurrentUser() async throws -> User? {
        do {
            guard let accessToken = try keychainService.retrieveAccessToken() else {
                return nil
            }
            
            let request = RequestBuilder.get("/auth/v1/user", baseURL: baseURL)
                .authenticated(with: accessToken)
            
            let response: UserResponse = try await httpClient.execute(request, expecting: UserResponse.self)
            return try await convertToUser(from: response)
            
        } catch {
            if error.localizedDescription.contains("unauthorized") {
                return nil
            }
            throw AuthDataSourceError.userFetchFailed(error.localizedDescription)
        }
    }
    
    /// Refresh current session tokens
    /// - Returns: Updated user with fresh tokens
    /// - Throws: AuthDataSourceError
    public func refreshSession() async throws -> User {
        do {
            guard let refreshToken = try keychainService.retrieveRefreshToken() else {
                throw AuthDataSourceError.tokenRefreshFailed("No refresh token available")
            }
            
            let requestData = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
            let request = RequestBuilder.post("/auth/v1/token", baseURL: baseURL)
                .header("grant_type", "refresh_token")
                .rawBody(requestData)
            
            let response: AuthResponse = try await httpClient.execute(request, expecting: AuthResponse.self)
            
            let user = try await convertToUser(from: response)
            try await storeAuthTokens(accessToken: response.accessToken, refreshToken: response.refreshToken)
            
            return user
            
        } catch {
            throw AuthDataSourceError.tokenRefreshFailed(error.localizedDescription)
        }
    }
    
    /// Check if user is currently authenticated
    /// - Returns: Authentication status
    public func isAuthenticated() async -> Bool {
        do {
            return try keychainService.retrieveAccessToken() != nil
        } catch {
            return false
        }
    }
    
    /// Get current access token
    /// - Returns: Current access token if available
    public func getCurrentAccessToken() async -> String? {
        return try? keychainService.retrieveAccessToken()
    }
    
    // MARK: - Private Methods
    
    private func convertToUser(from authResponse: AuthResponse) async throws -> User {
        return User(
            id: authResponse.user.id,
            email: authResponse.user.email,
            name: authResponse.user.userMetadata?["name"] as? String,
            avatarURL: (authResponse.user.userMetadata?["avatar_url"] as? String).flatMap { URL(string: $0) },
            createdAt: authResponse.user.createdAt,
            updatedAt: authResponse.user.updatedAt ?? authResponse.user.createdAt,
            authenticationStatus: .authenticated,
            accessToken: authResponse.accessToken,
            refreshToken: authResponse.refreshToken,
            tokenExpiresAt: authResponse.expiresAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            lastAuthenticatedAt: Date(),
            subscriptionTier: extractSubscriptionTier(from: authResponse.user.userMetadata),
            subscriptionStatus: extractSubscriptionStatus(from: authResponse.user.userMetadata),
            availableFeatures: getAvailableFeatures(for: extractSubscriptionTier(from: authResponse.user.userMetadata)),
            isSyncEnabled: extractSubscriptionTier(from: authResponse.user.userMetadata) != .free
        )
    }
    
    private func convertToUser(from userResponse: UserResponse) async throws -> User {
        return User(
            id: userResponse.id,
            email: userResponse.email,
            name: userResponse.userMetadata?["name"] as? String,
            avatarURL: (userResponse.userMetadata?["avatar_url"] as? String).flatMap { URL(string: $0) },
            createdAt: userResponse.createdAt,
            updatedAt: userResponse.updatedAt ?? userResponse.createdAt,
            authenticationStatus: .authenticated,
            accessToken: try? keychainService.retrieveAccessToken(),
            refreshToken: try? keychainService.retrieveRefreshToken(),
            lastAuthenticatedAt: Date(),
            subscriptionTier: extractSubscriptionTier(from: userResponse.userMetadata),
            subscriptionStatus: extractSubscriptionStatus(from: userResponse.userMetadata),
            availableFeatures: getAvailableFeatures(for: extractSubscriptionTier(from: userResponse.userMetadata)),
            isSyncEnabled: extractSubscriptionTier(from: userResponse.userMetadata) != .free
        )
    }
    
    private func storeAuthTokens(accessToken: String?, refreshToken: String?) async throws {
        if let accessToken = accessToken {
            try keychainService.store(accessToken, forKey: "access_token")
        }
        if let refreshToken = refreshToken {
            try keychainService.store(refreshToken, forKey: "refresh_token")
        }
    }
    
    private func clearStoredTokens() async throws {
        try keychainService.clearAuthenticationData()
    }
    
    private func extractSubscriptionTier(from metadata: [String: Any]?) -> SubscriptionTier {
        guard let metadata = metadata,
              let tierString = metadata["subscription_tier"] as? String else {
            return .free
        }
        
        switch tierString {
        case "pro":
            return .pro
        case "enterprise":
            return .enterprise
        case "custom":
            return .custom(tierString)
        default:
            return .free
        }
    }
    
    private func extractSubscriptionStatus(from metadata: [String: Any]?) -> UserSubscriptionStatus {
        guard let metadata = metadata,
              let statusString = metadata["subscription_status"] as? String else {
            return .inactive
        }
        
        switch statusString {
        case "active":
            return .active
        case "expired":
            return .expired
        case "trial":
            return .trial
        case "cancelled":
            return .cancelled
        case "pending":
            return .pending
        default:
            return .inactive
        }
    }
    
    private func getAvailableFeatures(for tier: SubscriptionTier) -> Set<Feature> {
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
}

// MARK: - Supporting Types

public struct AuthResponse: Codable {
    public let accessToken: String?
    public let refreshToken: String?
    public let expiresAt: Int?
    public let tokenType: String?
    public let user: AuthUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
        case user
    }
}

public struct AuthUser: Codable {
    public let id: UUID
    public let email: String
    public let createdAt: Date
    public let updatedAt: Date?
    public let userMetadata: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userMetadata = "user_metadata"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        
        if let metadataData = try container.decodeIfPresent(Data.self, forKey: .userMetadata) {
            userMetadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        } else {
            userMetadata = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        
        if let userMetadata = userMetadata {
            let metadataData = try JSONSerialization.data(withJSONObject: userMetadata)
            try container.encode(metadataData, forKey: .userMetadata)
        }
    }
}

public struct UserResponse: Codable {
    public let id: UUID
    public let email: String
    public let createdAt: Date
    public let updatedAt: Date?
    public let userMetadata: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userMetadata = "user_metadata"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        
        if let metadataData = try container.decodeIfPresent(Data.self, forKey: .userMetadata) {
            userMetadata = try JSONSerialization.jsonObject(with: metadataData) as? [String: Any]
        } else {
            userMetadata = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        
        if let userMetadata = userMetadata {
            let metadataData = try JSONSerialization.data(withJSONObject: userMetadata)
            try container.encode(metadataData, forKey: .userMetadata)
        }
    }
}

public enum AuthDataSourceError: Error, LocalizedError, Equatable {
    case signInFailed(String)
    case signUpFailed(String)
    case signOutFailed(String)
    case userFetchFailed(String)
    case tokenRefreshFailed(String)
    case invalidCredentials
    case userNotFound
    case emailNotConfirmed
    case networkError(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .userFetchFailed(let message):
            return "Failed to fetch user: \(message)"
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .emailNotConfirmed:
            return "Email address not confirmed"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Mock Implementation

/// Mock auth data source for testing
public final class MockSupabaseAuthDataSource {  
    private var mockUsers: [String: User] = [:]
    private var mockCurrentUser: User?
    private var shouldFailAuth = false
    private var authErrorToThrow: AuthDataSourceError?
    private let keychainService: KeychainServiceProtocol
    
    public init(keychainService: KeychainServiceProtocol = MockKeychainService()) {
        self.keychainService = keychainService
    }
    
    // MARK: - Test Helpers
    
    public func setMockUser(_ user: User) {
        mockCurrentUser = user
        mockUsers[user.email] = user
    }
    
    public func setAuthError(_ error: AuthDataSourceError?) {
        authErrorToThrow = error
        shouldFailAuth = error != nil
    }
    
    public func clearMockData() {
        mockUsers.removeAll()
        mockCurrentUser = nil
        shouldFailAuth = false
        authErrorToThrow = nil
    }
    
    // MARK: - Auth Methods
    
    public func signIn(email: String, password: String) async throws -> User {
        if shouldFailAuth, let error = authErrorToThrow {
            throw error
        }
        
        guard let user = mockUsers[email] else {
            throw AuthDataSourceError.userNotFound
        }
        
        mockCurrentUser = user
        return user
    }
    
    public func getCurrentUser() async throws -> User? {
        if shouldFailAuth, let error = authErrorToThrow {
            throw error
        }
        
        return mockCurrentUser
    }
    
    public func isAuthenticated() async -> Bool {
        return mockCurrentUser != nil && !shouldFailAuth
    }
    
    public func signOut() async throws {
        if shouldFailAuth, let error = authErrorToThrow {
            throw error
        }
        mockCurrentUser = nil
    }
}