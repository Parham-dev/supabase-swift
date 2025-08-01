//
//  NetworkErrorTests.swift
//  SwiftSupabaseSyncTests
//
//  Created by Testing Framework on 01/08/2025.
//

import XCTest
@testable import SwiftSupabaseSync

final class NetworkErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        // Test basic error descriptions
        XCTAssertEqual(NetworkError.noConnection.errorDescription, "No internet connection available")
        XCTAssertEqual(NetworkError.timeout.errorDescription, "Request timed out")
        XCTAssertEqual(NetworkError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(NetworkError.unauthorized.errorDescription, "Authentication required")
        XCTAssertEqual(NetworkError.forbidden.errorDescription, "Access forbidden")
        XCTAssertEqual(NetworkError.notFound.errorDescription, "Resource not found")
        XCTAssertEqual(NetworkError.cancelled.errorDescription, "Request was cancelled")
    }
    
    func testErrorDescriptionsWithParameters() {
        // Test errors with parameters
        let invalidRequest = NetworkError.invalidRequest("Missing parameter")
        XCTAssertEqual(invalidRequest.errorDescription, "Invalid request: Missing parameter")
        
        let httpError = NetworkError.httpError(statusCode: 500, message: "Internal Server Error")
        XCTAssertEqual(httpError.errorDescription, "HTTP 500: Internal Server Error")
        
        let decodingError = NetworkError.decodingError("Invalid JSON")
        XCTAssertEqual(decodingError.errorDescription, "Failed to decode response: Invalid JSON")
        
        let encodingError = NetworkError.encodingError("Cannot encode object")
        XCTAssertEqual(encodingError.errorDescription, "Failed to encode request: Cannot encode object")
        
        let rateLimitError = NetworkError.rateLimitExceeded(retryAfter: 60)
        XCTAssertEqual(rateLimitError.errorDescription, "Rate limit exceeded. Retry after 60 seconds")
        
        let rateLimitErrorNoTime = NetworkError.rateLimitExceeded(retryAfter: nil)
        XCTAssertEqual(rateLimitErrorNoTime.errorDescription, "Rate limit exceeded")
        
        let serverError = NetworkError.serverError("Database connection failed")
        XCTAssertEqual(serverError.errorDescription, "Server error: Database connection failed")
        
        let sslError = NetworkError.sslError("Certificate expired")
        XCTAssertEqual(sslError.errorDescription, "SSL error: Certificate expired")
    }
    
    func testErrorFromStatusCode() {
        // Test creating errors from HTTP status codes
        XCTAssertEqual(NetworkError.from(statusCode: 401, data: nil), .unauthorized)
        XCTAssertEqual(NetworkError.from(statusCode: 403, data: nil), .forbidden)
        XCTAssertEqual(NetworkError.from(statusCode: 404, data: nil), .notFound)
        XCTAssertEqual(NetworkError.from(statusCode: 429, data: nil), .rateLimitExceeded(retryAfter: nil))
        
        // Test server errors
        let serverErrorCase = NetworkError.from(statusCode: 500, data: nil)
        if case .serverError(let message) = serverErrorCase {
            XCTAssertEqual(message, "Internal server error")
        } else {
            XCTFail("Expected server error")
        }
        
        // Test with data
        let errorData = "Custom error message".data(using: .utf8)
        let customError = NetworkError.from(statusCode: 400, data: errorData)
        if case .httpError(let statusCode, let message) = customError {
            XCTAssertEqual(statusCode, 400)
            XCTAssertEqual(message, "Custom error message")
        } else {
            XCTFail("Expected HTTP error with custom message")
        }
    }
    
    func testRetryableErrors() {
        // Test which errors are retryable
        XCTAssertTrue(NetworkError.noConnection.isRetryable)
        XCTAssertTrue(NetworkError.timeout.isRetryable)
        XCTAssertTrue(NetworkError.rateLimitExceeded(retryAfter: nil).isRetryable)
        XCTAssertTrue(NetworkError.serverError("Server error").isRetryable)
        XCTAssertTrue(NetworkError.httpError(statusCode: 500, message: nil).isRetryable)
        XCTAssertTrue(NetworkError.httpError(statusCode: 429, message: nil).isRetryable)
        
        // Test non-retryable errors
        XCTAssertFalse(NetworkError.invalidURL.isRetryable)
        XCTAssertFalse(NetworkError.unauthorized.isRetryable)
        XCTAssertFalse(NetworkError.forbidden.isRetryable)
        XCTAssertFalse(NetworkError.notFound.isRetryable)
        XCTAssertFalse(NetworkError.cancelled.isRetryable)
        XCTAssertFalse(NetworkError.httpError(statusCode: 400, message: nil).isRetryable)
        XCTAssertFalse(NetworkError.decodingError("Invalid JSON").isRetryable)
        XCTAssertFalse(NetworkError.encodingError("Cannot encode").isRetryable)
    }
    
    func testSuggestedRetryDelay() {
        // Test suggested retry delays
        XCTAssertEqual(NetworkError.rateLimitExceeded(retryAfter: 120)?.suggestedRetryDelay, 120)
        XCTAssertEqual(NetworkError.rateLimitExceeded(retryAfter: nil)?.suggestedRetryDelay, 60.0)
        XCTAssertEqual(NetworkError.timeout.suggestedRetryDelay, 5.0)
        XCTAssertEqual(NetworkError.noConnection.suggestedRetryDelay, 10.0)
        XCTAssertEqual(NetworkError.serverError("Error").suggestedRetryDelay, 30.0)
        XCTAssertEqual(NetworkError.httpError(statusCode: 500, message: nil).suggestedRetryDelay, 30.0)
        
        // Test errors with no suggested retry delay
        XCTAssertNil(NetworkError.unauthorized.suggestedRetryDelay)
        XCTAssertNil(NetworkError.notFound.suggestedRetryDelay)
        XCTAssertNil(NetworkError.httpError(statusCode: 400, message: nil).suggestedRetryDelay)
    }
    
    func testEquality() {
        // Test equality for simple cases
        XCTAssertEqual(NetworkError.noConnection, NetworkError.noConnection)
        XCTAssertEqual(NetworkError.timeout, NetworkError.timeout)
        XCTAssertEqual(NetworkError.unauthorized, NetworkError.unauthorized)
        
        // Test equality for cases with parameters
        XCTAssertEqual(
            NetworkError.invalidRequest("Same message"),
            NetworkError.invalidRequest("Same message")
        )
        XCTAssertNotEqual(
            NetworkError.invalidRequest("Different message"),
            NetworkError.invalidRequest("Another message")
        )
        
        XCTAssertEqual(
            NetworkError.httpError(statusCode: 500, message: "Error"),
            NetworkError.httpError(statusCode: 500, message: "Error")
        )
        XCTAssertNotEqual(
            NetworkError.httpError(statusCode: 500, message: "Error"),
            NetworkError.httpError(statusCode: 404, message: "Error")
        )
        
        XCTAssertEqual(
            NetworkError.rateLimitExceeded(retryAfter: 60),
            NetworkError.rateLimitExceeded(retryAfter: 60)
        )
        XCTAssertNotEqual(
            NetworkError.rateLimitExceeded(retryAfter: 60),
            NetworkError.rateLimitExceeded(retryAfter: 30)
        )
    }
}