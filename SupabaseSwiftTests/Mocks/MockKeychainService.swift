//
//  MockKeychainService.swift
//  SwiftSupabaseSyncTests
//
//  Created by Parham on 01/08/2025.
//

import Foundation
@testable import SwiftSupabaseSync

/// Mock keychain service for testing
public final class MockKeychainService: KeychainServiceProtocol {
    
    private var storage: [String: String] = [:]
    private var shouldThrowError = false
    private var errorToThrow: KeychainError?
    
    public init() {}
    
    public func store(_ value: String, forKey key: String) throws {
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        storage[key] = value
    }
    
    public func retrieve(key: String) throws -> String? {
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        return storage[key]
    }
    
    public func delete(_ key: String) throws {
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        storage.removeValue(forKey: key)
    }
    
    public func exists(_ key: String) -> Bool {
        return storage[key] != nil
    }
    
    public func clearAll() throws {
        if shouldThrowError, let error = errorToThrow {
            throw error
        }
        storage.removeAll()
    }
    
    public func clearAuthenticationData() throws {
        try? delete("access_token")
        try? delete("refresh_token")
        try? delete("user_session")
    }
    
    public func retrieveAccessToken() throws -> String? {
        return try retrieve(key: "access_token")
    }
    
    public func retrieveRefreshToken() throws -> String? {
        return try retrieve(key: "refresh_token")
    }
    
    // MARK: - Test Helpers
    
    public func setError(_ error: KeychainError?) {
        self.errorToThrow = error
        self.shouldThrowError = error != nil
    }
    
    public func clearError() {
        self.errorToThrow = nil
        self.shouldThrowError = false
    }
    
    public var storedKeys: [String] {
        return Array(storage.keys)
    }
    
    public var storedValues: [String: String] {
        return storage
    }
}