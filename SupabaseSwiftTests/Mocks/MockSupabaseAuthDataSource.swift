//
//  MockSupabaseAuthDataSource.swift
//  SwiftSupabaseSyncTests
//
//  Created by Parham on 01/08/2025.
//

import Foundation
@testable import SwiftSupabaseSync

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