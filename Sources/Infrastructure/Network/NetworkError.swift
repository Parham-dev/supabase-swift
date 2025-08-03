//
//  NetworkError.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Comprehensive error types for network operations
public enum NetworkError: Error, LocalizedError, Equatable {
    /// No internet connection available
    case noConnection
    
    /// Request timed out
    case timeout
    
    /// Invalid URL formation
    case invalidURL
    
    /// Invalid request parameters
    case invalidRequest(String)
    
    /// HTTP error with status code
    case httpError(statusCode: Int, message: String?)
    
    /// Server returned invalid or unparseable data
    case invalidResponse
    
    /// Failed to decode response data
    case decodingError(String)
    
    /// Failed to encode request data
    case encodingError(String)
    
    /// Authentication required but not provided
    case unauthorized
    
    /// Access forbidden for the current user
    case forbidden
    
    /// Requested resource not found
    case notFound
    
    /// Rate limit exceeded
    case rateLimitExceeded(retryAfter: TimeInterval?)
    
    /// Server error (5xx)
    case serverError(String)
    
    /// Network operation was cancelled
    case cancelled
    
    /// SSL/TLS certificate error
    case sslError(String)
    
    /// Unknown error occurred
    case unknown(Error)
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection available"
        case .timeout:
            return "Request timed out"
        case .invalidURL:
            return "Invalid URL"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message ?? "Unknown error")"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .encodingError(let message):
            return "Failed to encode request: \(message)"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limit exceeded"
        case .serverError(let message):
            return "Server error: \(message)"
        case .cancelled:
            return "Request was cancelled"
        case .sslError(let message):
            return "SSL error: \(message)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - HTTP Status Code Helpers
    
    /// Create NetworkError from HTTP status code
    public static func from(statusCode: Int, data: Data?) -> NetworkError {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        
        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 429:
            // Try to parse retry-after header
            return .rateLimitExceeded(retryAfter: nil)
        case 500...599:
            return .serverError(message ?? "Internal server error")
        default:
            return .httpError(statusCode: statusCode, message: message)
        }
    }
    
    /// Check if error is retryable
    public var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .rateLimitExceeded, .serverError:
            return true
        case .httpError(let statusCode, _):
            return statusCode >= 500 || statusCode == 429
        default:
            return false
        }
    }
    
    /// Suggested retry delay for retryable errors
    public var suggestedRetryDelay: TimeInterval? {
        switch self {
        case .rateLimitExceeded(let retryAfter):
            return retryAfter ?? 60.0
        case .timeout:
            return 5.0
        case .noConnection:
            return 10.0
        case .serverError:
            return 30.0
        case .httpError(let statusCode, _) where statusCode >= 500:
            return 30.0
        default:
            return nil
        }
    }
}

// MARK: - Equatable

extension NetworkError {
    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.noConnection, .noConnection),
             (.timeout, .timeout),
             (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.cancelled, .cancelled):
            return true
            
        case (.invalidRequest(let lhsMessage), .invalidRequest(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        case (.httpError(let lhsCode, let lhsMessage), .httpError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
            
        case (.decodingError(let lhsMessage), .decodingError(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        case (.encodingError(let lhsMessage), .encodingError(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        case (.rateLimitExceeded(let lhsRetry), .rateLimitExceeded(let rhsRetry)):
            return lhsRetry == rhsRetry
            
        case (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        case (.sslError(let lhsMessage), .sslError(let rhsMessage)):
            return lhsMessage == rhsMessage
            
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
            
        default:
            return false
        }
    }
}