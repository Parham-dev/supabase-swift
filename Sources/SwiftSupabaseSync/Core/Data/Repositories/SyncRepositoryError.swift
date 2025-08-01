//
//  SyncRepositoryError.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Errors that can occur in SyncRepository operations
public enum SyncRepositoryError: Error, LocalizedError, Equatable {
    case fetchFailed(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case applyFailed(String)
    case updateFailed(String)
    case conflictDetectionFailed(String)
    case conflictResolutionFailed(String)
    case schemaError(String)
    case notImplemented(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .applyFailed(let message):
            return "Apply changes failed: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        case .conflictDetectionFailed(let message):
            return "Conflict detection failed: \(message)"
        case .conflictResolutionFailed(let message):
            return "Conflict resolution failed: \(message)"
        case .schemaError(let message):
            return "Schema error: \(message)"
        case .notImplemented(let message):
            return "Not implemented: \(message)"
        case .unknown(let message):
            return "Unknown sync repository error: \(message)"
        }
    }
}