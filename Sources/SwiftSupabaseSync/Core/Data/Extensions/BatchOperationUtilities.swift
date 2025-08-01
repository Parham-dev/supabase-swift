//
//  BatchOperationUtilities.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - LocalDataSource Extensions

public extension LocalDataSource {
    
    /// Save the current model context
    /// - Throws: LocalDataSourceError if save fails
    func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw LocalDataSourceError.updateFailed("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    /// Check if there are unsaved changes
    /// - Returns: Whether there are unsaved changes
    var hasUnsavedChanges: Bool {
        return modelContext.hasChanges
    }
    
    /// Rollback unsaved changes
    func rollback() {
        modelContext.rollback()
    }
}

// MARK: - BatchOperationResult Collection Extensions

public extension Array where Element == BatchOperationResult {
    
    /// Filter successful operations
    var successful: [BatchOperationResult] {
        return self.filter { $0.success }
    }
    
    /// Filter failed operations
    var failed: [BatchOperationResult] {
        return self.filter { !$0.success }
    }
    
    /// Get success rate as percentage
    var successRate: Double {
        guard !isEmpty else { return 0.0 }
        return Double(successful.count) / Double(count)
    }
    
    /// Get sync IDs of successful operations
    var successfulSyncIDs: [UUID] {
        return successful.map { $0.syncID }
    }
    
    /// Get sync IDs of failed operations
    var failedSyncIDs: [UUID] {
        return failed.map { $0.syncID }
    }
    
    /// Get errors from failed operations
    var errors: [Error] {
        return failed.compactMap { $0.error }
    }
    
    /// Get summary of batch operation results
    var summary: BatchOperationSummary {
        return BatchOperationSummary(
            total: count,
            successful: successful.count,
            failed: failed.count,
            successRate: successRate,
            errors: errors
        )
    }
}

// MARK: - Batch Operation Summary

/// Summary of batch operation results
public struct BatchOperationSummary {
    /// Total number of operations
    public let total: Int
    
    /// Number of successful operations
    public let successful: Int
    
    /// Number of failed operations
    public let failed: Int
    
    /// Success rate as percentage (0.0 to 1.0)
    public let successRate: Double
    
    /// All errors from failed operations
    public let errors: [Error]
    
    /// Whether all operations were successful
    public var isCompleteSuccess: Bool {
        return failed == 0
    }
    
    /// Whether any operations were successful
    public var hasAnySuccess: Bool {
        return successful > 0
    }
    
    /// Whether all operations failed
    public var isCompleteFailure: Bool {
        return successful == 0 && total > 0
    }
    
    public init(total: Int, successful: Int, failed: Int, successRate: Double, errors: [Error]) {
        self.total = total
        self.successful = successful
        self.failed = failed
        self.successRate = successRate
        self.errors = errors
    }
}