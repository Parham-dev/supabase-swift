//
//  SupabaseClient.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// HTTP client configured for Supabase API operations
/// Handles authentication, retries, and error handling
public actor SupabaseClient {
    
    // MARK: - Properties
    
    private let baseURL: URL
    private let apiKey: String
    private let session: URLSession
    private var authToken: String?
    private let maxRetryAttempts: Int
    private let retryDelay: TimeInterval
    
    // MARK: - Initialization
    
    /// Initialize Supabase client
    /// - Parameters:
    ///   - baseURL: Supabase project URL
    ///   - apiKey: Supabase anon/service key
    ///   - session: URLSession to use (defaults to shared)
    ///   - maxRetryAttempts: Maximum retry attempts for failed requests
    ///   - retryDelay: Base delay between retries
    public init(
        baseURL: URL,
        apiKey: String,
        session: URLSession = .shared,
        maxRetryAttempts: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
    }
    
    // MARK: - Authentication
    
    /// Set the authentication token
    /// - Parameter token: Bearer token for authenticated requests
    public func setAuthToken(_ token: String?) {
        self.authToken = token
    }
    
    /// Get current authentication token
    /// - Returns: Current auth token if available
    public func getAuthToken() -> String? {
        return authToken
    }
    
    // MARK: - Request Execution
    
    /// Execute a request and decode the response
    /// - Parameters:
    ///   - request: Request builder
    ///   - type: Expected response type
    /// - Returns: Decoded response
    /// - Throws: NetworkError
    public func execute<T: Decodable>(
        _ request: RequestBuilder,
        expecting type: T.Type
    ) async throws -> T {
        let urlRequest = try buildURLRequest(from: request)
        let data = try await executeWithRetry(urlRequest)
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingError(error.localizedDescription)
        }
    }
    
    /// Execute a request without expecting a response body
    /// - Parameter request: Request builder
    /// - Throws: NetworkError
    public func execute(_ request: RequestBuilder) async throws {
        let urlRequest = try buildURLRequest(from: request)
        _ = try await executeWithRetry(urlRequest)
    }
    
    /// Execute a request and return raw data
    /// - Parameter request: Request builder
    /// - Returns: Response data
    /// - Throws: NetworkError
    public func executeRaw(_ request: RequestBuilder) async throws -> Data {
        let urlRequest = try buildURLRequest(from: request)
        return try await executeWithRetry(urlRequest)
    }
    
    // MARK: - Private Methods
    
    private func buildURLRequest(from builder: RequestBuilder) throws -> URLRequest {
        // Add default Supabase headers
        var request = builder
            .apiKey(apiKey)
        
        // Add auth token if available
        if let token = authToken {
            request = request.authenticated(with: token)
        }
        
        return try request.build()
    }
    
    private func executeWithRetry(_ request: URLRequest) async throws -> Data {
        var lastError: NetworkError?
        
        for attempt in 0..<maxRetryAttempts {
            do {
                return try await performRequest(request)
            } catch let error as NetworkError {
                lastError = error
                
                // Check if error is retryable
                guard error.isRetryable, attempt < maxRetryAttempts - 1 else {
                    throw error
                }
                
                // Calculate retry delay with exponential backoff
                let delay = error.suggestedRetryDelay ?? (retryDelay * pow(2.0, Double(attempt)))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NetworkError.unknown(NSError(domain: "SupabaseClient", code: -1))
    }
    
    private func performRequest(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Check for successful status code
            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.from(statusCode: httpResponse.statusCode, data: data)
            }
            
            return data
            
        } catch let error as NetworkError {
            throw error
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw NetworkError.unknown(error)
        }
    }
    
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnection
        case .timedOut:
            return .timeout
        case .cancelled:
            return .cancelled
        case .badURL:
            return .invalidURL
        case .secureConnectionFailed:
            return .sslError(error.localizedDescription)
        default:
            return .unknown(error)
        }
    }
}

// MARK: - Convenience Methods

public extension SupabaseClient {
    
    /// Execute a GET request
    /// - Parameters:
    ///   - path: API endpoint path
    ///   - type: Expected response type
    ///   - queryParameters: Optional query parameters
    /// - Returns: Decoded response
    func get<T: Decodable>(
        _ path: String,
        expecting type: T.Type,
        queryParameters: [String: String]? = nil
    ) async throws -> T {
        var request = RequestBuilder.get(path, baseURL: baseURL)
        
        if let params = queryParameters {
            request = request.queries(params)
        }
        
        return try await execute(request, expecting: type)
    }
    
    /// Execute a POST request
    /// - Parameters:
    ///   - path: API endpoint path
    ///   - body: Request body
    ///   - type: Expected response type
    /// - Returns: Decoded response
    func post<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        expecting type: T.Type
    ) async throws -> T {
        let request = try RequestBuilder.post(path, baseURL: baseURL)
            .body(body)
        
        return try await execute(request, expecting: type)
    }
    
    /// Execute a PUT request
    /// - Parameters:
    ///   - path: API endpoint path
    ///   - body: Request body
    ///   - type: Expected response type
    /// - Returns: Decoded response
    func put<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        expecting type: T.Type
    ) async throws -> T {
        let request = try RequestBuilder.put(path, baseURL: baseURL)
            .body(body)
        
        return try await execute(request, expecting: type)
    }
    
    /// Execute a PATCH request
    /// - Parameters:
    ///   - path: API endpoint path
    ///   - body: Request body
    ///   - type: Expected response type
    /// - Returns: Decoded response
    func patch<B: Encodable, T: Decodable>(
        _ path: String,
        body: B,
        expecting type: T.Type
    ) async throws -> T {
        let request = try RequestBuilder.patch(path, baseURL: baseURL)
            .body(body)
        
        return try await execute(request, expecting: type)
    }
    
    /// Execute a DELETE request
    /// - Parameters:
    ///   - path: API endpoint path
    ///   - type: Expected response type
    /// - Returns: Decoded response
    func delete<T: Decodable>(
        _ path: String,
        expecting type: T.Type
    ) async throws -> T {
        let request = RequestBuilder.delete(path, baseURL: baseURL)
        return try await execute(request, expecting: type)
    }
    
    /// Execute a DELETE request without response
    /// - Parameter path: API endpoint path
    func delete(_ path: String) async throws {
        let request = RequestBuilder.delete(path, baseURL: baseURL)
        try await execute(request)
    }
}