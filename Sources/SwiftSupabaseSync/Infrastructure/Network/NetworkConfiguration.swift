//
//  NetworkConfiguration.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Network configuration for Supabase client
public struct NetworkConfiguration {
    
    // MARK: - Properties
    
    /// Supabase project URL
    public let supabaseURL: URL
    
    /// Supabase anon/service key
    public let supabaseKey: String
    
    /// Request timeout interval
    public let requestTimeout: TimeInterval
    
    /// Maximum retry attempts for failed requests
    public let maxRetryAttempts: Int
    
    /// Base delay between retries (uses exponential backoff)
    public let retryDelay: TimeInterval
    
    /// Whether to enable request/response logging
    public let enableLogging: Bool
    
    /// Custom URLSession configuration
    public let sessionConfiguration: URLSessionConfiguration
    
    // MARK: - Initialization
    
    /// Initialize network configuration
    /// - Parameters:
    ///   - supabaseURL: Supabase project URL
    ///   - supabaseKey: Supabase anon/service key
    ///   - requestTimeout: Request timeout interval (default: 30 seconds)
    ///   - maxRetryAttempts: Maximum retry attempts (default: 3)
    ///   - retryDelay: Base retry delay (default: 1 second)
    ///   - enableLogging: Enable request/response logging (default: false in release)
    ///   - sessionConfiguration: Custom URLSession configuration
    public init(
        supabaseURL: URL,
        supabaseKey: String,
        requestTimeout: TimeInterval = 30.0,
        maxRetryAttempts: Int = 3,
        retryDelay: TimeInterval = 1.0,
        enableLogging: Bool = false,
        sessionConfiguration: URLSessionConfiguration = .default
    ) {
        self.supabaseURL = supabaseURL
        self.supabaseKey = supabaseKey
        self.requestTimeout = requestTimeout
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
        self.enableLogging = enableLogging
        self.sessionConfiguration = sessionConfiguration
    }
    
    // MARK: - Factory Methods
    
    /// Create default configuration for development
    public static func development(url: URL, key: String) -> NetworkConfiguration {
        return NetworkConfiguration(
            supabaseURL: url,
            supabaseKey: key,
            enableLogging: true
        )
    }
    
    /// Create default configuration for production
    public static func production(url: URL, key: String) -> NetworkConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        
        return NetworkConfiguration(
            supabaseURL: url,
            supabaseKey: key,
            maxRetryAttempts: 3,
            enableLogging: false,
            sessionConfiguration: config
        )
    }
    
    /// Create configuration for background sync
    public static func backgroundSync(
        url: URL,
        key: String,
        identifier: String
    ) -> NetworkConfiguration {
        let config = URLSessionConfiguration.background(withIdentifier: identifier)
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = false
        
        return NetworkConfiguration(
            supabaseURL: url,
            supabaseKey: key,
            requestTimeout: 60.0,
            maxRetryAttempts: 5,
            retryDelay: 2.0,
            enableLogging: false,
            sessionConfiguration: config
        )
    }
}

// MARK: - Network Service Protocol

/// Protocol for network service operations
public protocol NetworkServiceProtocol {
    /// Execute a request and decode the response
    func execute<T: Decodable>(_ request: RequestBuilder, expecting type: T.Type) async throws -> T
    
    /// Execute a request without expecting a response body
    func execute(_ request: RequestBuilder) async throws
    
    /// Execute a request and return raw data
    func executeRaw(_ request: RequestBuilder) async throws -> Data
    
    /// Set authentication token
    func setAuthToken(_ token: String?) async
}

// MARK: - Network Service Implementation

/// Main network service that coordinates all network operations
public final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    
    private let client: SupabaseClient
    private let monitor: NetworkMonitor
    private let configuration: NetworkConfiguration
    private let logger: NetworkLogger?
    
    // MARK: - Initialization
    
    /// Initialize network service
    /// - Parameters:
    ///   - configuration: Network configuration
    ///   - monitor: Network monitor (defaults to shared instance)
    public init(
        configuration: NetworkConfiguration,
        monitor: NetworkMonitor = .shared
    ) {
        self.configuration = configuration
        self.monitor = monitor
        
        // Create URL session
        let session = URLSession(configuration: configuration.sessionConfiguration)
        
        // Create Supabase client
        self.client = SupabaseClient(
            baseURL: configuration.supabaseURL,
            apiKey: configuration.supabaseKey,
            session: session,
            maxRetryAttempts: configuration.maxRetryAttempts,
            retryDelay: configuration.retryDelay
        )
        
        // Create logger if enabled
        self.logger = configuration.enableLogging ? NetworkLogger() : nil
    }
    
    // MARK: - NetworkServiceProtocol
    
    public func execute<T: Decodable>(
        _ request: RequestBuilder,
        expecting type: T.Type
    ) async throws -> T {
        // Check network availability
        guard monitor.isConnected else {
            throw NetworkError.noConnection
        }
        
        // Log request
        await logger?.logRequest(request)
        
        do {
            let result = try await client.execute(request, expecting: type)
            await logger?.logResponse(result, for: request)
            return result
        } catch {
            await logger?.logError(error, for: request)
            throw error
        }
    }
    
    public func execute(_ request: RequestBuilder) async throws {
        // Check network availability
        guard monitor.isConnected else {
            throw NetworkError.noConnection
        }
        
        // Log request
        await logger?.logRequest(request)
        
        do {
            try await client.execute(request)
            await logger?.logSuccess(for: request)
        } catch {
            await logger?.logError(error, for: request)
            throw error
        }
    }
    
    public func executeRaw(_ request: RequestBuilder) async throws -> Data {
        // Check network availability
        guard monitor.isConnected else {
            throw NetworkError.noConnection
        }
        
        // Log request
        await logger?.logRequest(request)
        
        do {
            let data = try await client.executeRaw(request)
            await logger?.logRawResponse(data, for: request)
            return data
        } catch {
            await logger?.logError(error, for: request)
            throw error
        }
    }
    
    public func setAuthToken(_ token: String?) async {
        await client.setAuthToken(token)
    }
}

// MARK: - Network Logger

/// Simple network logger for debugging
actor NetworkLogger {
    
    func logRequest(_ request: RequestBuilder) {
        #if DEBUG
        print("🌐 [Network] Request: \(request.debugDescription())")
        #endif
    }
    
    func logResponse<T>(_ response: T, for request: RequestBuilder) {
        #if DEBUG
        print("✅ [Network] Response for \(request.debugDescription())")
        // Only attempt to encode if response conforms to Encodable
        if let encodableResponse = response as? Encodable,
           let data = try? JSONEncoder().encode(encodableResponse),
           let json = String(data: data, encoding: .utf8) {
            print("📦 [Network] Data: \(json)")
        }
        #endif
    }
    
    func logRawResponse(_ data: Data, for request: RequestBuilder) {
        #if DEBUG
        print("✅ [Network] Raw response for \(request.debugDescription())")
        print("📦 [Network] Data size: \(data.count) bytes")
        #endif
    }
    
    func logSuccess(for request: RequestBuilder) {
        #if DEBUG
        print("✅ [Network] Success for \(request.debugDescription())")
        #endif
    }
    
    func logError(_ error: Error, for request: RequestBuilder) {
        #if DEBUG
        print("❌ [Network] Error for \(request.debugDescription()): \(error)")
        #endif
    }
}