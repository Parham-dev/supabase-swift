//
//  AuthRepositoryProtocol.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Authentication Repository Protocol

/// Protocol defining the interface for authentication data operations
public protocol AuthRepositoryProtocol {
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Authentication session data
    func signIn(email: String, password: String) async throws -> AuthSessionData
    
    /// Sign up new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - name: Optional display name
    /// - Returns: Authentication session data
    func signUp(email: String, password: String, name: String?) async throws -> AuthSessionData
    
    /// Sign out current user
    func signOut() async throws
    
    /// Refresh authentication token
    /// - Parameter refreshToken: Current refresh token
    /// - Returns: Updated session data
    func refreshToken(_ refreshToken: String) async throws -> AuthSessionData
    
    /// Get current authenticated user
    /// - Returns: Current user if authenticated, nil otherwise
    func getCurrentUser() async throws -> User?
    
    /// Save user data to local storage
    /// - Parameter user: User to save
    func saveUser(_ user: User) async throws
    
    /// Clear all user data from local storage
    func clearUserData() async throws
}

// MARK: - Logger Protocol

/// Protocol for sync logging operations
public protocol SyncLoggerProtocol {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}