//
//  RequestBuilder.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Type-safe HTTP request builder for Supabase API operations
public struct RequestBuilder {
    
    // MARK: - Properties
    
    private let baseURL: URL
    private var path: String = ""
    private var method: HTTPMethod = .get
    private var headers: [String: String] = [:]
    private var queryParameters: [String: String] = [:]
    private var body: Data?
    private var timeoutInterval: TimeInterval = 30.0
    
    // MARK: - Initialization
    
    /// Initialize with base URL
    /// - Parameter baseURL: The base URL for all requests
    public init(baseURL: URL) {
        self.baseURL = baseURL
        
        // Set default headers
        self.headers["Content-Type"] = "application/json"
        self.headers["Accept"] = "application/json"
    }
    
    // MARK: - Builder Methods
    
    /// Set the request path
    /// - Parameter path: The API endpoint path
    /// - Returns: Updated request builder
    public func path(_ path: String) -> RequestBuilder {
        var builder = self
        builder.path = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return builder
    }
    
    /// Set the HTTP method
    /// - Parameter method: The HTTP method to use
    /// - Returns: Updated request builder
    public func method(_ method: HTTPMethod) -> RequestBuilder {
        var builder = self
        builder.method = method
        return builder
    }
    
    /// Add a header to the request
    /// - Parameters:
    ///   - key: Header name
    ///   - value: Header value
    /// - Returns: Updated request builder
    public func header(_ key: String, _ value: String) -> RequestBuilder {
        var builder = self
        builder.headers[key] = value
        return builder
    }
    
    /// Add multiple headers to the request
    /// - Parameter headers: Dictionary of headers to add
    /// - Returns: Updated request builder
    public func headers(_ headers: [String: String]) -> RequestBuilder {
        var builder = self
        headers.forEach { builder.headers[$0.key] = $0.value }
        return builder
    }
    
    /// Add authentication token
    /// - Parameter token: Bearer token for authentication
    /// - Returns: Updated request builder
    public func authenticated(with token: String) -> RequestBuilder {
        return header("Authorization", "Bearer \(token)")
    }
    
    /// Add API key for Supabase
    /// - Parameter apiKey: Supabase anon/service key
    /// - Returns: Updated request builder
    public func apiKey(_ apiKey: String) -> RequestBuilder {
        return header("apikey", apiKey)
    }
    
    /// Add query parameter
    /// - Parameters:
    ///   - key: Parameter name
    ///   - value: Parameter value
    /// - Returns: Updated request builder
    public func query(_ key: String, _ value: String) -> RequestBuilder {
        var builder = self
        builder.queryParameters[key] = value
        return builder
    }
    
    /// Add multiple query parameters
    /// - Parameter parameters: Dictionary of query parameters
    /// - Returns: Updated request builder
    public func queries(_ parameters: [String: String]) -> RequestBuilder {
        var builder = self
        parameters.forEach { builder.queryParameters[$0.key] = $0.value }
        return builder
    }
    
    /// Set request body with Encodable object
    /// - Parameter body: Encodable object to send as JSON
    /// - Returns: Updated request builder
    /// - Throws: EncodingError if encoding fails
    public func body<T: Encodable>(_ body: T) throws -> RequestBuilder {
        var builder = self
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        builder.body = try encoder.encode(body)
        return builder
    }
    
    /// Set raw request body
    /// - Parameter data: Raw data to send
    /// - Returns: Updated request builder
    public func rawBody(_ data: Data) -> RequestBuilder {
        var builder = self
        builder.body = data
        return builder
    }
    
    /// Set request timeout
    /// - Parameter timeout: Timeout interval in seconds
    /// - Returns: Updated request builder
    public func timeout(_ timeout: TimeInterval) -> RequestBuilder {
        var builder = self
        builder.timeoutInterval = timeout
        return builder
    }
    
    // MARK: - Build Request
    
    /// Build the URLRequest
    /// - Returns: Configured URLRequest
    /// - Throws: NetworkError if request cannot be built
    public func build() throws -> URLRequest {
        // Construct URL with path
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            throw NetworkError.invalidURL
        }
        
        // Add path
        if !path.isEmpty {
            components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/" + path
        }
        
        // Add query parameters
        if !queryParameters.isEmpty {
            components.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval
        
        // Add headers
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        // Add body
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
}

// MARK: - HTTP Method

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

// MARK: - Convenience Extensions

public extension RequestBuilder {
    
    /// Create a GET request
    static func get(_ path: String, baseURL: URL) -> RequestBuilder {
        return RequestBuilder(baseURL: baseURL)
            .method(.get)
            .path(path)
    }
    
    /// Create a POST request
    static func post(_ path: String, baseURL: URL) -> RequestBuilder {
        return RequestBuilder(baseURL: baseURL)
            .method(.post)
            .path(path)
    }
    
    /// Create a PUT request
    static func put(_ path: String, baseURL: URL) -> RequestBuilder {
        return RequestBuilder(baseURL: baseURL)
            .method(.put)
            .path(path)
    }
    
    /// Create a PATCH request
    static func patch(_ path: String, baseURL: URL) -> RequestBuilder {
        return RequestBuilder(baseURL: baseURL)
            .method(.patch)
            .path(path)
    }
    
    /// Create a DELETE request
    static func delete(_ path: String, baseURL: URL) -> RequestBuilder {
        return RequestBuilder(baseURL: baseURL)
            .method(.delete)
            .path(path)
    }
}

// MARK: - Request Logging

public extension RequestBuilder {
    
    /// Build a debug description of the request
    func debugDescription() -> String {
        var description = "\(method.rawValue) \(baseURL.absoluteString)/\(path)"
        
        if !queryParameters.isEmpty {
            let queryString = queryParameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            description += "?\(queryString)"
        }
        
        if !headers.isEmpty {
            description += "\nHeaders: \(headers)"
        }
        
        if let body = body, let bodyString = String(data: body, encoding: .utf8) {
            description += "\nBody: \(bodyString)"
        }
        
        return description
    }
}