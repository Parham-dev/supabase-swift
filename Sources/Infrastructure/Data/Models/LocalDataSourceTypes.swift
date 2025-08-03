//
//  LocalDataSourceTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Error Types

/// Errors that can occur during local data source operations
public enum LocalDataSourceError: Error, LocalizedError, Equatable {
    case fetchFailed(String)
    case insertFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case validationFailed(String)
    case contextNotAvailable
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .insertFailed(let message):
            return "Insert failed: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .contextNotAvailable:
            return "Model context not available"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Result Types

/// Result of a batch operation on a single record
public struct BatchOperationResult {
    /// Sync ID of the record operated on
    public let syncID: UUID
    
    /// Whether the operation was successful
    public let success: Bool
    
    /// Error if operation failed
    public let error: Error?
    
    /// Timestamp when operation completed
    public let timestamp: Date
    
    public init(syncID: UUID, success: Bool, error: Error?, timestamp: Date = Date()) {
        self.syncID = syncID
        self.success = success
        self.error = error
        self.timestamp = timestamp
    }
}

