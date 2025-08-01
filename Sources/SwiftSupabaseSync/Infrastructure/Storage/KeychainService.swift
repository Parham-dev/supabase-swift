//
//  KeychainService.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Security

// Security framework constants for compatibility
private let errSecUserCancel: OSStatus = -128

/// Secure storage service for sensitive data using iOS Keychain
/// Provides encrypted storage for tokens, keys, and other sensitive information
public final class KeychainService {
    
    // MARK: - Properties
    
    private let service: String
    private let accessGroup: String?
    
    // MARK: - Singleton
    
    /// Shared keychain service instance
    public static let shared = KeychainService()
    
    // MARK: - Initialization
    
    /// Initialize keychain service
    /// - Parameters:
    ///   - service: Service identifier for keychain items
    ///   - accessGroup: Optional access group for shared keychain access
    public init(service: String = "SwiftSupabaseSync", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
    
    // MARK: - Public Methods
    
    /// Store a string value in keychain
    /// - Parameters:
    ///   - value: String value to store
    ///   - key: Unique identifier for the value
    /// - Throws: KeychainError if storage fails
    public func store(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.conversionError("Failed to convert string to data")
        }
        try store(data, forKey: key)
    }
    
    /// Store data in keychain
    /// - Parameters:
    ///   - data: Data to store
    ///   - key: Unique identifier for the data
    /// - Throws: KeychainError if storage fails
    public func store(_ data: Data, forKey key: String) throws {
        // Delete existing item first
        try? delete(key)
        
        var query = baseQuery(for: key)
        query[kSecValueData] = data
        query[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
    }
    
    /// Retrieve a string value from keychain
    /// - Parameter key: Unique identifier for the value
    /// - Returns: String value if found, nil otherwise
    /// - Throws: KeychainError if retrieval fails
    public func retrieve(key: String) throws -> String? {
        guard let data = try retrieveData(key: key) else {
            return nil
        }
        
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.conversionError("Failed to convert data to string")
        }
        
        return string
    }
    
    /// Retrieve data from keychain
    /// - Parameter key: Unique identifier for the data
    /// - Returns: Data if found, nil otherwise
    /// - Throws: KeychainError if retrieval fails
    public func retrieveData(key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
        
        return result as? Data
    }
    
    /// Update an existing value in keychain
    /// - Parameters:
    ///   - value: New string value
    ///   - key: Unique identifier for the value
    /// - Throws: KeychainError if update fails
    public func update(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.conversionError("Failed to convert string to data")
        }
        try update(data, forKey: key)
    }
    
    /// Update existing data in keychain
    /// - Parameters:
    ///   - data: New data
    ///   - key: Unique identifier for the data
    /// - Throws: KeychainError if update fails
    public func update(_ data: Data, forKey key: String) throws {
        let query = baseQuery(for: key)
        let attributes: [CFString: Any] = [
            kSecValueData: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
    }
    
    /// Delete a value from keychain
    /// - Parameter key: Unique identifier for the value
    /// - Throws: KeychainError if deletion fails
    public func delete(_ key: String) throws {
        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.from(status: status)
        }
    }
    
    /// Check if a key exists in keychain
    /// - Parameter key: Unique identifier to check
    /// - Returns: Whether the key exists
    public func exists(_ key: String) -> Bool {
        let query = baseQuery(for: key)
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Clear all items for this service
    /// - Throws: KeychainError if clearing fails
    public func clearAll() throws {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.from(status: status)
        }
    }
    
    /// Get all keys stored by this service
    /// - Returns: Array of all keys
    /// - Throws: KeychainError if retrieval fails
    public func allKeys() throws -> [String] {
        var query = baseQuery()
        query[kSecReturnAttributes] = true
        query[kSecMatchLimit] = kSecMatchLimitAll
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status != errSecItemNotFound else {
            return []
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.from(status: status)
        }
        
        guard let items = result as? [[CFString: Any]] else {
            return []
        }
        
        return items.compactMap { item in
            item[kSecAttrAccount] as? String
        }
    }
    
    // MARK: - Private Methods
    
    private func baseQuery(for key: String? = nil) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]
        
        if let key = key {
            query[kSecAttrAccount] = key
        }
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        
        return query
    }
}

// MARK: - KeychainError

public enum KeychainError: Error, LocalizedError, Equatable {
    case conversionError(String)
    case osError(OSStatus)
    case unexpectedData
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .conversionError(let message):
            return "Keychain conversion error: \(message)"
        case .osError(let status):
            return "Keychain OS error: \(status) - \(SecCopyErrorMessageString(status, nil) ?? "Unknown error" as CFString)"
        case .unexpectedData:
            return "Unexpected data format in keychain"
        case .unknown:
            return "Unknown keychain error"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .conversionError:
            return "Failed to convert data format"
        case .osError:
            return "System keychain operation failed"
        case .unexpectedData:
            return "Data retrieved from keychain was in unexpected format"
        case .unknown:
            return "An unknown error occurred"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .conversionError:
            return "Ensure data is in correct format before storing"
        case .osError(let status):
            switch status {
            case errSecUserCancel:
                return "User cancelled the operation. Try again."
            case errSecAuthFailed:
                return "Authentication failed. Check device passcode/biometrics."
            case errSecDuplicateItem:
                return "Item already exists. Use update instead of store."
            case errSecItemNotFound:
                return "Item not found. Ensure key exists before retrieving."
            default:
                return "Check device keychain status and permissions"
            }
        case .unexpectedData:
            return "Delete and recreate the keychain item"
        case .unknown:
            return "Try the operation again"
        }
    }
    
    static func from(status: OSStatus) -> KeychainError {
        return .osError(status)
    }
}

// MARK: - Convenience Extensions

public extension KeychainService {
    
    // MARK: - Authentication Tokens
    
    /// Store access token
    /// - Parameter token: Access token to store
    /// - Throws: KeychainError if storage fails
    func storeAccessToken(_ token: String) throws {
        try store(token, forKey: "access_token")
    }
    
    /// Retrieve access token
    /// - Returns: Access token if available
    /// - Throws: KeychainError if retrieval fails
    func retrieveAccessToken() throws -> String? {
        return try retrieve(key: "access_token")
    }
    
    /// Store refresh token
    /// - Parameter token: Refresh token to store
    /// - Throws: KeychainError if storage fails
    func storeRefreshToken(_ token: String) throws {
        try store(token, forKey: "refresh_token")
    }
    
    /// Retrieve refresh token
    /// - Returns: Refresh token if available
    /// - Throws: KeychainError if retrieval fails
    func retrieveRefreshToken() throws -> String? {
        return try retrieve(key: "refresh_token")
    }
    
    /// Store user session
    /// - Parameter session: User session data as JSON string
    /// - Throws: KeychainError if storage fails
    func storeUserSession(_ session: String) throws {
        try store(session, forKey: "user_session")
    }
    
    /// Retrieve user session
    /// - Returns: User session data as JSON string if available
    /// - Throws: KeychainError if retrieval fails
    func retrieveUserSession() throws -> String? {
        return try retrieve(key: "user_session")
    }
    
    /// Clear all authentication data
    /// - Throws: KeychainError if clearing fails
    func clearAuthenticationData() throws {
        try? delete("access_token")
        try? delete("refresh_token")
        try? delete("user_session")
    }
    
    // MARK: - Supabase Configuration
    
    /// Store Supabase URL
    /// - Parameter url: Supabase project URL
    /// - Throws: KeychainError if storage fails
    func storeSupabaseURL(_ url: String) throws {
        try store(url, forKey: "supabase_url")
    }
    
    /// Retrieve Supabase URL
    /// - Returns: Supabase URL if available
    /// - Throws: KeychainError if retrieval fails
    func retrieveSupabaseURL() throws -> String? {
        return try retrieve(key: "supabase_url")
    }
    
    /// Store Supabase API key
    /// - Parameter key: Supabase anon/service key
    /// - Throws: KeychainError if storage fails
    func storeSupabaseKey(_ key: String) throws {
        try store(key, forKey: "supabase_key")
    }
    
    /// Retrieve Supabase API key
    /// - Returns: Supabase key if available
    /// - Throws: KeychainError if retrieval fails
    func retrieveSupabaseKey() throws -> String? {
        return try retrieve(key: "supabase_key")
    }
    
    // MARK: - Encryption Keys
    
    /// Store encryption key for local data
    /// - Parameter key: Encryption key as base64 string
    /// - Throws: KeychainError if storage fails
    func storeEncryptionKey(_ key: String) throws {
        try store(key, forKey: "encryption_key")
    }
    
    /// Retrieve encryption key for local data
    /// - Returns: Encryption key as base64 string if available
    /// - Throws: KeychainError if retrieval fails
    func retrieveEncryptionKey() throws -> String? {
        return try retrieve(key: "encryption_key")
    }
    
    // MARK: - Sync Metadata
    
    /// Store sync device ID
    /// - Parameter deviceID: Unique device identifier
    /// - Throws: KeychainError if storage fails
    func storeDeviceID(_ deviceID: String) throws {
        try store(deviceID, forKey: "device_id")
    }
    
    /// Retrieve sync device ID
    /// - Returns: Device ID if available
    /// - Throws: KeychainError if retrieval fails
    func retrieveDeviceID() throws -> String? {
        return try retrieve(key: "device_id")
    }
}

// MARK: - Async Extensions

public extension KeychainService {
    
    /// Async wrapper for store operation
    /// - Parameters:
    ///   - value: String value to store
    ///   - key: Unique identifier for the value
    /// - Throws: KeychainError if storage fails
    func store(_ value: String, forKey key: String) async throws {
        try await Task.detached {
            try self.store(value, forKey: key)
        }.value
    }
    
    /// Async wrapper for retrieve operation
    /// - Parameter key: Unique identifier for the value
    /// - Returns: String value if found, nil otherwise
    /// - Throws: KeychainError if retrieval fails
    func retrieve(key: String) async throws -> String? {
        return try await Task.detached {
            try self.retrieve(key: key)
        }.value
    }
    
    /// Async wrapper for delete operation
    /// - Parameter key: Unique identifier for the value
    /// - Throws: KeychainError if deletion fails
    func delete(_ key: String) async throws {
        try await Task.detached {
            try self.delete(key)
        }.value
    }
    
    /// Async wrapper for exists check
    /// - Parameter key: Unique identifier to check
    /// - Returns: Whether the key exists
    func exists(_ key: String) async -> Bool {
        return await Task.detached {
            self.exists(key)
        }.value
    }
    
    /// Async wrapper for clearAll operation
    /// - Throws: KeychainError if clearing fails
    func clearAll() async throws {
        try await Task.detached {
            try self.clearAll()
        }.value
    }
}

// MARK: - Keychain Service Protocol

/// Protocol for keychain operations to enable testing
public protocol KeychainServiceProtocol {
    func store(_ value: String, forKey key: String) throws
    func retrieve(key: String) throws -> String?
    func delete(_ key: String) throws
    func exists(_ key: String) -> Bool
    func clearAll() throws
}

extension KeychainService: KeychainServiceProtocol {}

// MARK: - Mock Keychain Service

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