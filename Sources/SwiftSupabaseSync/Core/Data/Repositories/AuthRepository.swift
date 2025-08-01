//
//  AuthRepository.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Implementation of AuthRepositoryProtocol that bridges authentication use cases with data sources
/// Coordinates between SupabaseAuthDataSource and KeychainService for complete auth management
public final class AuthRepository: AuthRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let authDataSource: SupabaseAuthDataSource
    private let keychainService: KeychainServiceProtocol
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Initialization
    
    /// Initialize auth repository
    /// - Parameters:
    ///   - authDataSource: Remote auth data source for API operations
    ///   - keychainService: Secure storage service for tokens and user data
    ///   - logger: Optional logger for debugging
    public init(
        authDataSource: SupabaseAuthDataSource,
        keychainService: KeychainServiceProtocol = KeychainService.shared,
        logger: SyncLoggerProtocol? = nil
    ) {
        self.authDataSource = authDataSource
        self.keychainService = keychainService
        self.logger = logger
    }
    
    // MARK: - AuthRepositoryProtocol Implementation
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Authentication session data
    /// - Throws: AuthRepositoryError if sign in fails
    public func signIn(email: String, password: String) async throws -> AuthSessionData {
        logger?.debug("AuthRepository: Starting sign in for email: \(email)")
        
        do {
            // Authenticate with remote data source
            let user = try await authDataSource.signIn(email: email, password: password)
            
            // Convert User to AuthSessionData
            let sessionData = try convertUserToSessionData(user)
            
            // Store user data locally for getCurrentUser
            try await saveUserData(user)
            
            logger?.info("AuthRepository: Sign in successful for user: \(user.id)")
            return sessionData
            
        } catch {
            logger?.error("AuthRepository: Sign in failed - \(error.localizedDescription)")
            throw AuthRepositoryError.signInFailed(error.localizedDescription)
        }
    }
    
    /// Sign up new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - name: Optional display name
    /// - Returns: Authentication session data
    /// - Throws: AuthRepositoryError if sign up fails
    public func signUp(email: String, password: String, name: String?) async throws -> AuthSessionData {
        logger?.debug("AuthRepository: Starting sign up for email: \(email)")
        
        do {
            // Create metadata if name is provided
            var metadata: [String: Any]? = nil
            if let name = name {
                metadata = ["name": name]
            }
            
            // Register with remote data source
            let user = try await authDataSource.signUp(email: email, password: password, metadata: metadata)
            
            // Convert User to AuthSessionData
            let sessionData = try convertUserToSessionData(user)
            
            // Store user data locally
            try await saveUserData(user)
            
            logger?.info("AuthRepository: Sign up successful for user: \(user.id)")
            return sessionData
            
        } catch {
            logger?.error("AuthRepository: Sign up failed - \(error.localizedDescription)")
            throw AuthRepositoryError.signUpFailed(error.localizedDescription)
        }
    }
    
    /// Sign out current user
    /// - Throws: AuthRepositoryError if sign out fails
    public func signOut() async throws {
        logger?.debug("AuthRepository: Starting sign out")
        
        do {
            // Sign out from remote
            try await authDataSource.signOut()
            
            // Clear local data
            try await clearUserData()
            
            logger?.info("AuthRepository: Sign out successful")
            
        } catch {
            logger?.error("AuthRepository: Sign out failed - \(error.localizedDescription)")
            throw AuthRepositoryError.signOutFailed(error.localizedDescription)
        }
    }
    
    /// Refresh authentication token
    /// - Parameter refreshToken: Current refresh token
    /// - Returns: Updated session data
    /// - Throws: AuthRepositoryError if token refresh fails
    public func refreshToken(_ refreshToken: String) async throws -> AuthSessionData {
        logger?.debug("AuthRepository: Starting token refresh")
        
        do {
            // Refresh session with remote data source
            let user = try await authDataSource.refreshSession()
            
            // Convert User to AuthSessionData
            let sessionData = try convertUserToSessionData(user)
            
            // Update stored user data
            try await saveUserData(user)
            
            logger?.info("AuthRepository: Token refresh successful for user: \(user.id)")
            return sessionData
            
        } catch {
            logger?.error("AuthRepository: Token refresh failed - \(error.localizedDescription)")
            throw AuthRepositoryError.tokenRefreshFailed(error.localizedDescription)
        }
    }
    
    /// Get current authenticated user
    /// - Returns: Current user if authenticated, nil otherwise
    /// - Throws: AuthRepositoryError if user retrieval fails
    public func getCurrentUser() async throws -> User? {
        logger?.debug("AuthRepository: Getting current user")
        
        do {
            // Try to get user from remote first (validates tokens)
            if let user = try await authDataSource.getCurrentUser() {
                // Update local storage with fresh data
                try await saveUserData(user)
                return user
            }
            
            // If remote fails, try local storage
            return try await loadUserData()
            
        } catch {
            logger?.warning("AuthRepository: Failed to get current user - \(error.localizedDescription)")
            // Return nil instead of throwing for getCurrentUser
            return nil
        }
    }
    
    /// Save user data to local storage
    /// - Parameter user: User to save
    /// - Throws: AuthRepositoryError if save fails
    public func saveUser(_ user: User) async throws {
        logger?.debug("AuthRepository: Saving user: \(user.id)")
        
        do {
            try await saveUserData(user)
            logger?.debug("AuthRepository: User saved successfully")
            
        } catch {
            logger?.error("AuthRepository: Failed to save user - \(error.localizedDescription)")
            throw AuthRepositoryError.userSaveFailed(error.localizedDescription)
        }
    }
    
    /// Clear all user data from local storage
    /// - Throws: AuthRepositoryError if clear fails
    public func clearUserData() async throws {
        logger?.debug("AuthRepository: Clearing user data")
        
        do {
            // Clear authentication data (tokens)
            try keychainService.clearAuthenticationData()
            
            // Clear stored user session
            try? keychainService.delete("user_session")
            
            logger?.debug("AuthRepository: User data cleared successfully")
            
        } catch {
            logger?.error("AuthRepository: Failed to clear user data - \(error.localizedDescription)")
            throw AuthRepositoryError.userClearFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Convert User object to AuthSessionData
    /// - Parameter user: User object from data source
    /// - Returns: AuthSessionData for use case
    /// - Throws: AuthRepositoryError if conversion fails
    private func convertUserToSessionData(_ user: User) throws -> AuthSessionData {
        guard let accessToken = user.accessToken else {
            throw AuthRepositoryError.missingTokens("User missing access token")
        }
        
        return AuthSessionData(
            userID: user.id,
            email: user.email,
            name: user.name,
            avatarURL: user.avatarURL,
            accessToken: accessToken,
            refreshToken: user.refreshToken,
            expiresAt: user.tokenExpiresAt,
            createdAt: user.createdAt
        )
    }
    
    /// Save user data to keychain as JSON
    /// - Parameter user: User to save
    /// - Throws: Error if save fails
    private func saveUserData(_ user: User) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let userData = try encoder.encode(user)
        let userJson = String(data: userData, encoding: .utf8) ?? ""
        
        try keychainService.store(userJson, forKey: "user_session")
    }
    
    /// Load user data from keychain
    /// - Returns: User if found, nil otherwise
    /// - Throws: Error if decode fails
    private func loadUserData() async throws -> User? {
        guard let userJson = try keychainService.retrieve(key: "user_session") else {
            return nil
        }
        
        guard let userData = userJson.data(using: String.Encoding.utf8) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(User.self, from: userData)
    }
}

// MARK: - Auth Repository Error

/// Errors that can occur in AuthRepository operations
public enum AuthRepositoryError: Error, LocalizedError, Equatable {
    case signInFailed(String)
    case signUpFailed(String)
    case signOutFailed(String)
    case tokenRefreshFailed(String)
    case userSaveFailed(String)
    case userClearFailed(String)
    case missingTokens(String)
    case conversionFailed(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .tokenRefreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .userSaveFailed(let message):
            return "Failed to save user: \(message)"
        case .userClearFailed(let message):
            return "Failed to clear user data: \(message)"
        case .missingTokens(let message):
            return "Missing authentication tokens: \(message)"
        case .conversionFailed(let message):
            return "Data conversion failed: \(message)"
        case .unknown(let message):
            return "Unknown auth repository error: \(message)"
        }
    }
}