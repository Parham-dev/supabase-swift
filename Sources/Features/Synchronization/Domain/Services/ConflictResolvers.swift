//
//  ConflictResolvers.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Built-in Conflict Resolvers

/// Simple strategy-based conflict resolver
/// Provides automatic resolution based on predefined strategies
public struct StrategyBasedConflictResolver: ConflictResolvable {
    private let strategy: ConflictResolutionStrategy
    
    /// Initialize with a specific resolution strategy
    /// - Parameter strategy: The strategy to use for all conflicts
    public init(strategy: ConflictResolutionStrategy) {
        self.strategy = strategy
    }
    
    public func resolveConflict(_ conflict: SyncConflict) async throws -> ConflictResolution {
        switch strategy {
        case .lastWriteWins:
            let chosenVersion: ConflictVersion = conflict.localSnapshot.lastModified > conflict.remoteSnapshot.lastModified ? .local : .remote
            return ConflictResolution(
                strategy: .lastWriteWins,
                chosenVersion: chosenVersion,
                explanation: "Resolved using last write wins strategy"
            )
            
        case .firstWriteWins:
            let chosenVersion: ConflictVersion = conflict.localSnapshot.lastModified < conflict.remoteSnapshot.lastModified ? .local : .remote
            return ConflictResolution(
                strategy: .firstWriteWins,
                chosenVersion: chosenVersion,
                explanation: "Resolved using first write wins strategy"
            )
            
        case .localWins:
            return ConflictResolution(
                strategy: .localWins,
                chosenVersion: .local,
                explanation: "Resolved by keeping local version"
            )
            
        case .remoteWins:
            return ConflictResolution(
                strategy: .remoteWins,
                chosenVersion: .remote,
                explanation: "Resolved by keeping remote version"
            )
            
        case .manual:
            throw ConflictResolutionError.manualResolutionRequired(conflict)
        }
    }
    
    public func getResolverCapabilities() -> ConflictResolverCapabilities {
        return ConflictResolverCapabilities(
            supportedStrategies: [strategy],
            supportsBatchResolution: true,
            supportsAutoResolution: strategy != .manual,
            maxBatchSize: 100
        )
    }
}

// MARK: - Error Types

/// Errors that can occur during conflict resolution
public enum ConflictResolutionError: Error, LocalizedError {
    case unsupportedStrategy(ConflictResolutionStrategy)
    case invalidConflictData
    case manualResolutionRequired(SyncConflict)
    case resolutionValidationFailed
    case batchSizeExceeded(Int)
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedStrategy(let strategy):
            return "Unsupported conflict resolution strategy: \(strategy)"
        case .invalidConflictData:
            return "Invalid conflict data provided"
        case .manualResolutionRequired:
            return "Manual conflict resolution required"
        case .resolutionValidationFailed:
            return "Conflict resolution validation failed"
        case .batchSizeExceeded(let size):
            return "Batch size exceeded: \(size)"
        case .unknownError(let message):
            return "Conflict resolution error: \(message)"
        }
    }
}