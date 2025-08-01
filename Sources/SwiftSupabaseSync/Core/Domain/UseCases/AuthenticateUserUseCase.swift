//
//  AuthenticateUserUseCase.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Use case for handling user authentication workflows
/// Orchestrates login, logout, token refresh, and session management
public protocol AuthenticateUserUseCaseProtocol {
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Authentication result with user data
    func signIn(email: String, password: String) async throws -> AuthenticationResult
    
    /// Sign up new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - name: Optional display name
    /// - Returns: Authentication result with user data
    func signUp(email: String, password: String, name: String?) async throws -> AuthenticationResult
    
    /// Sign out current user
    /// - Returns: Sign out result
    func signOut() async throws -> SignOutResult
    
    /// Refresh authentication token
    /// - Parameter user: Current user to refresh token for
    /// - Returns: Updated authentication result
    func refreshToken(for user: User) async throws -> AuthenticationResult
    
    /// Get current authenticated user
    /// - Returns: Current user if authenticated, nil otherwise
    func getCurrentUser() async throws -> User?
    
    /// Validate current session
    /// - Returns: Session validation result
    func validateSession() async throws -> SessionValidationResult
}

public struct AuthenticateUserUseCase: AuthenticateUserUseCaseProtocol {
    
    // MARK: - Dependencies
    
    private let authRepository: AuthRepositoryProtocol
    private let subscriptionValidator: SubscriptionValidating
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Configuration
    
    private let tokenRefreshThreshold: TimeInterval
    private let sessionValidationInterval: TimeInterval
    
    // MARK: - Initialization
    
    public init(
        authRepository: AuthRepositoryProtocol,
        subscriptionValidator: SubscriptionValidating,
        logger: SyncLoggerProtocol? = nil,
        tokenRefreshThreshold: TimeInterval = 300, // 5 minutes
        sessionValidationInterval: TimeInterval = 3600 // 1 hour
    ) {
        self.authRepository = authRepository
        self.subscriptionValidator = subscriptionValidator
        self.logger = logger
        self.tokenRefreshThreshold = tokenRefreshThreshold
        self.sessionValidationInterval = sessionValidationInterval
    }
    
    // MARK: - Public Methods
    
    public func signIn(email: String, password: String) async throws -> AuthenticationResult {
        logger?.debug("Starting sign in for email: \(email)")
        
        // Validate input
        try validateEmailAndPassword(email: email, password: password)
        
        do {
            // Attempt authentication
            let authData = try await authRepository.signIn(email: email, password: password)
            
            // Create user from auth data
            let user = try await createUserFromAuthData(authData)
            
            // Validate subscription
            let subscriptionResult = try await subscriptionValidator.validateSubscription(for: user)
            
            // Update user with subscription info
            let updatedUser = updateUserWithSubscription(user, subscriptionResult: subscriptionResult)
            
            // Save authenticated user
            try await authRepository.saveUser(updatedUser)
            
            logger?.info("Sign in successful for user: \(updatedUser.id)")
            
            return AuthenticationResult(
                success: true,
                user: updatedUser,
                authenticationMethod: .emailPassword,
                sessionData: authData
            )
            
        } catch {
            logger?.error("Sign in failed for email: \(email), error: \(error)")
            throw AuthenticationError.from(error)
        }
    }
    
    public func signUp(email: String, password: String, name: String?) async throws -> AuthenticationResult {
        logger?.debug("Starting sign up for email: \(email)")
        
        // Validate input
        try validateEmailAndPassword(email: email, password: password)
        
        do {
            // Attempt user creation
            let authData = try await authRepository.signUp(email: email, password: password, name: name)
            
            // Create user from auth data
            let user = try await createUserFromAuthData(authData)
            
            // For new users, start with free tier
            let updatedUser = user.withSubscription(tier: .free, status: .active)
            
            // Save new user
            try await authRepository.saveUser(updatedUser)
            
            logger?.info("Sign up successful for user: \(updatedUser.id)")
            
            return AuthenticationResult(
                success: true,
                user: updatedUser,
                authenticationMethod: .emailPassword,
                sessionData: authData,
                isNewUser: true
            )
            
        } catch {
            logger?.error("Sign up failed for email: \(email), error: \(error)")
            throw AuthenticationError.from(error)
        }
    }
    
    public func signOut() async throws -> SignOutResult {
        logger?.debug("Starting sign out")
        
        do {
            // Get current user before signing out
            let currentUser = try await getCurrentUser()
            
            // Sign out from auth provider
            try await authRepository.signOut()
            
            // Clear local user data
            try await authRepository.clearUserData()
            
            logger?.info("Sign out successful")
            
            return SignOutResult(
                success: true,
                clearedUserID: currentUser?.id
            )
            
        } catch {
            logger?.error("Sign out failed: \(error)")
            throw AuthenticationError.from(error)
        }
    }
    
    public func refreshToken(for user: User) async throws -> AuthenticationResult {
        logger?.debug("Starting token refresh for user: \(user.id)")
        
        // Check if refresh is needed
        guard user.needsTokenRefresh else {
            logger?.debug("Token refresh not needed for user: \(user.id)")
            return AuthenticationResult(
                success: true,
                user: user,
                authenticationMethod: .tokenRefresh
            )
        }
        
        guard let refreshToken = user.refreshToken else {
            logger?.error("No refresh token available for user: \(user.id)")
            throw AuthenticationError.tokenRefreshFailed
        }
        
        do {
            // Refresh the token
            let authData = try await authRepository.refreshToken(refreshToken)
            
            // Update user with new tokens
            let updatedUser = user.withTokens(
                accessToken: authData.accessToken,
                refreshToken: authData.refreshToken,
                expiresAt: authData.expiresAt
            )
            
            // Save updated user
            try await authRepository.saveUser(updatedUser)
            
            logger?.info("Token refresh successful for user: \(user.id)")
            
            return AuthenticationResult(
                success: true,
                user: updatedUser,
                authenticationMethod: .tokenRefresh,
                sessionData: authData
            )
            
        } catch {
            logger?.error("Token refresh failed for user: \(user.id), error: \(error)")
            throw AuthenticationError.from(error)
        }
    }
    
    public func getCurrentUser() async throws -> User? {
        return try await authRepository.getCurrentUser()
    }
    
    public func validateSession() async throws -> SessionValidationResult {
        logger?.debug("Validating current session")
        
        guard let user = try await getCurrentUser() else {
            return SessionValidationResult(isValid: false, validationError: .noActiveSession)
        }
        
        // Check token expiration
        if !user.isAuthenticated {
            logger?.debug("Session invalid - token expired for user: \(user.id)")
            return SessionValidationResult(
                isValid: false,
                user: user,
                validationError: .tokenExpired
            )
        }
        
        // Check if token needs refresh
        if user.needsTokenRefresh {
            logger?.debug("Session needs token refresh for user: \(user.id)")
            
            do {
                let refreshResult = try await refreshToken(for: user)
                return SessionValidationResult(
                    isValid: true,
                    user: refreshResult.user,
                    wasRefreshed: true
                )
            } catch {
                logger?.error("Session validation failed during token refresh: \(error)")
                return SessionValidationResult(
                    isValid: false,
                    user: user,
                    validationError: .tokenRefreshFailed
                )
            }
        }
        
        logger?.debug("Session valid for user: \(user.id)")
        return SessionValidationResult(isValid: true, user: user)
    }
    
    // MARK: - Private Helper Methods
    
    private func validateEmailAndPassword(email: String, password: String) throws {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthenticationError.invalidCredentials
        }
        
        guard email.contains("@") && email.contains(".") else {
            throw AuthenticationError.invalidCredentials
        }
        
        guard password.count >= 6 else {
            throw AuthenticationError.invalidCredentials
        }
    }
    
    private func createUserFromAuthData(_ authData: AuthSessionData) async throws -> User {
        return User(
            id: authData.userID,
            email: authData.email,
            name: authData.name,
            avatarURL: authData.avatarURL,
            createdAt: authData.createdAt ?? Date(),
            updatedAt: Date(),
            authenticationStatus: .authenticated,
            accessToken: authData.accessToken,
            refreshToken: authData.refreshToken,
            tokenExpiresAt: authData.expiresAt,
            lastAuthenticatedAt: Date()
        )
    }
    
    private func updateUserWithSubscription(_ user: User, subscriptionResult: SubscriptionValidationResult) -> User {
        return User(
            id: user.id,
            email: user.email,
            name: user.name,
            avatarURL: user.avatarURL,
            createdAt: user.createdAt,
            updatedAt: Date(),
            authenticationStatus: user.authenticationStatus,
            accessToken: user.accessToken,
            refreshToken: user.refreshToken,
            tokenExpiresAt: user.tokenExpiresAt,
            lastAuthenticatedAt: user.lastAuthenticatedAt,
            subscriptionTier: subscriptionResult.tier,
            subscriptionStatus: subscriptionResult.status,
            subscriptionExpiresAt: subscriptionResult.expiresAt,
            availableFeatures: subscriptionResult.availableFeatures,
            syncPreferences: user.syncPreferences,
            isSyncEnabled: subscriptionResult.allowsFeature(.basicSync),
            lastSyncAt: user.lastSyncAt
        )
    }
}

// MARK: - Supporting Types

public struct AuthenticationResult: Codable, Equatable {
    /// Whether authentication was successful
    public let success: Bool
    
    /// Authenticated user (if successful)
    public let user: User?
    
    /// Method used for authentication
    public let authenticationMethod: AuthenticationMethod
    
    /// Session data from auth provider
    public let sessionData: AuthSessionData?
    
    /// Whether this is a new user registration
    public let isNewUser: Bool
    
    /// Authentication timestamp
    public let authenticatedAt: Date
    
    /// Error if authentication failed
    public let error: AuthenticationError?
    
    public init(
        success: Bool,
        user: User? = nil,
        authenticationMethod: AuthenticationMethod,
        sessionData: AuthSessionData? = nil,
        isNewUser: Bool = false,
        authenticatedAt: Date = Date(),
        error: AuthenticationError? = nil
    ) {
        self.success = success
        self.user = user
        self.authenticationMethod = authenticationMethod
        self.sessionData = sessionData
        self.isNewUser = isNewUser
        self.authenticatedAt = authenticatedAt
        self.error = error
    }
    
    /// Create a failed authentication result
    public static func failed(
        method: AuthenticationMethod,
        error: AuthenticationError
    ) -> AuthenticationResult {
        return AuthenticationResult(
            success: false,
            authenticationMethod: method,
            error: error
        )
    }
}

public struct SignOutResult: Codable, Equatable {
    /// Whether sign out was successful
    public let success: Bool
    
    /// ID of user that was signed out
    public let clearedUserID: UUID?
    
    /// Sign out timestamp
    public let signedOutAt: Date
    
    /// Error if sign out failed
    public let error: AuthenticationError?
    
    public init(
        success: Bool,
        clearedUserID: UUID? = nil,
        signedOutAt: Date = Date(),
        error: AuthenticationError? = nil
    ) {
        self.success = success
        self.clearedUserID = clearedUserID
        self.signedOutAt = signedOutAt
        self.error = error
    }
}

public struct SessionValidationResult: Codable, Equatable {
    /// Whether the session is valid
    public let isValid: Bool
    
    /// Current user (if session is valid)
    public let user: User?
    
    /// Whether token was refreshed during validation
    public let wasRefreshed: Bool
    
    /// Validation timestamp
    public let validatedAt: Date
    
    /// Error if validation failed
    public let validationError: SessionValidationError?
    
    public init(
        isValid: Bool,
        user: User? = nil,
        wasRefreshed: Bool = false,
        validatedAt: Date = Date(),
        validationError: SessionValidationError? = nil
    ) {
        self.isValid = isValid
        self.user = user
        self.wasRefreshed = wasRefreshed
        self.validatedAt = validatedAt
        self.validationError = validationError
    }
}

public struct AuthSessionData: Codable, Equatable {
    /// User ID from auth provider
    public let userID: UUID
    
    /// User's email address
    public let email: String
    
    /// Display name
    public let name: String?
    
    /// Avatar URL
    public let avatarURL: URL?
    
    /// Access token
    public let accessToken: String
    
    /// Refresh token
    public let refreshToken: String?
    
    /// Token expiration time
    public let expiresAt: Date?
    
    /// Account creation time
    public let createdAt: Date?
    
    public init(
        userID: UUID,
        email: String,
        name: String? = nil,
        avatarURL: URL? = nil,
        accessToken: String,
        refreshToken: String? = nil,
        expiresAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.userID = userID
        self.email = email
        self.name = name
        self.avatarURL = avatarURL
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

// MARK: - Enums

public enum AuthenticationMethod: String, Codable, CaseIterable {
    case emailPassword = "email_password"
    case tokenRefresh = "token_refresh"
    case biometric = "biometric"
    case sso = "sso"
    case anonymous = "anonymous"
}

public enum SessionValidationError: String, Codable, CaseIterable {
    case noActiveSession = "no_active_session"
    case tokenExpired = "token_expired"
    case tokenRefreshFailed = "token_refresh_failed"
    case networkError = "network_error"
    case unknownError = "unknown_error"
    
    public var localizedDescription: String {
        switch self {
        case .noActiveSession:
            return "No active session found"
        case .tokenExpired:
            return "Authentication token has expired"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .networkError:
            return "Network error during session validation"
        case .unknownError:
            return "Unknown session validation error"
        }
    }
}

// MARK: - Protocol Definitions for Dependencies

public protocol AuthRepositoryProtocol {
    func signIn(email: String, password: String) async throws -> AuthSessionData
    func signUp(email: String, password: String, name: String?) async throws -> AuthSessionData
    func signOut() async throws
    func refreshToken(_ refreshToken: String) async throws -> AuthSessionData
    func getCurrentUser() async throws -> User?
    func saveUser(_ user: User) async throws
    func clearUserData() async throws
}

public protocol SyncLoggerProtocol {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

// MARK: - Error Extensions

extension AuthenticationError {
    static func from(_ error: Error) -> AuthenticationError {
        if let authError = error as? AuthenticationError {
            return authError
        }
        return .unknownError(error.localizedDescription)
    }
}

// MARK: - User Extensions

extension User {
    func withSubscription(tier: SubscriptionTier, status: UserSubscriptionStatus) -> User {
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
            tokenExpiresAt: tokenExpiresAt,
            lastAuthenticatedAt: lastAuthenticatedAt,
            subscriptionTier: tier,
            subscriptionStatus: status,
            subscriptionExpiresAt: subscriptionExpiresAt,
            availableFeatures: User.featuresForTier(tier),
            syncPreferences: syncPreferences,
            isSyncEnabled: isSyncEnabled,
            lastSyncAt: lastSyncAt
        )
    }
}