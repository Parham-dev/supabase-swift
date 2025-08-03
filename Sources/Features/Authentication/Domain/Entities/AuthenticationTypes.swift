//
//  AuthenticationTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Authentication Result Types

/// Result of an authentication operation
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

/// Result of a sign out operation
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

/// Result of session validation
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

/// Session data from authentication provider
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

// MARK: - Authentication Enums

/// Methods used for user authentication
public enum AuthenticationMethod: String, Codable, CaseIterable {
    case emailPassword = "email_password"
    case tokenRefresh = "token_refresh"
    case biometric = "biometric"
    case sso = "sso"
    case anonymous = "anonymous"
}

/// Errors that can occur during session validation
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