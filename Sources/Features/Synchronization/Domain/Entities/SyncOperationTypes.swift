//
//  SyncOperationTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Result of a sync operation execution
public struct SyncOperationResult: Codable, Equatable {
    /// The sync operation that was performed
    public let operation: SyncOperation
    
    /// Whether the operation was successful
    public let success: Bool
    
    /// Number of records uploaded
    public let uploadedCount: Int
    
    /// Number of records downloaded
    public let downloadedCount: Int
    
    /// Number of conflicts encountered
    public let conflictCount: Int
    
    /// Operation duration in seconds
    public let duration: TimeInterval
    
    /// Errors encountered during operation
    public let errors: [SyncError]
    
    /// Operation completion timestamp
    public let completedAt: Date
    
    public init(
        operation: SyncOperation,
        success: Bool,
        uploadedCount: Int = 0,
        downloadedCount: Int = 0,
        conflictCount: Int = 0,
        duration: TimeInterval = 0,
        errors: [SyncError] = [],
        completedAt: Date = Date()
    ) {
        self.operation = operation
        self.success = success
        self.uploadedCount = uploadedCount
        self.downloadedCount = downloadedCount
        self.conflictCount = conflictCount
        self.duration = duration
        self.errors = errors
        self.completedAt = completedAt
    }
    
    /// Create a failed operation result
    public static func failed(
        operation: SyncOperation,
        error: SyncError
    ) -> SyncOperationResult {
        return SyncOperationResult(
            operation: operation,
            success: false,
            errors: [error]
        )
    }
}

/// Result of checking sync eligibility
public struct SyncEligibilityResult: Codable, Equatable {
    /// Whether sync is eligible to start
    public let isEligible: Bool
    
    /// Reason for ineligibility (if applicable)
    public let reason: SyncIneligibilityReason?
    
    /// Recommendations to make sync eligible
    public let recommendations: [String]
    
    /// Check timestamp
    public let checkedAt: Date
    
    public init(
        isEligible: Bool,
        reason: SyncIneligibilityReason? = nil,
        recommendations: [String] = [],
        checkedAt: Date = Date()
    ) {
        self.isEligible = isEligible
        self.reason = reason
        self.recommendations = recommendations
        self.checkedAt = checkedAt
    }
}

/// Result of sync operation cancellation
public struct SyncCancellationResult: Codable, Equatable {
    /// Whether cancellation was successful
    public let success: Bool
    
    /// ID of cancelled operation
    public let operationID: UUID
    
    /// Cancellation timestamp
    public let cancelledAt: Date
    
    /// Error if cancellation failed
    public let error: SyncCancellationError?
    
    public init(
        success: Bool,
        operationID: UUID,
        cancelledAt: Date = Date(),
        error: SyncCancellationError? = nil
    ) {
        self.success = success
        self.operationID = operationID
        self.cancelledAt = cancelledAt
        self.error = error
    }
}

// MARK: - Supporting Enums

/// Reasons why sync may not be eligible
public enum SyncIneligibilityReason: String, Codable, CaseIterable, Error {
    case notAuthenticated = "not_authenticated"
    case subscriptionRequired = "subscription_required"
    case policyDisabled = "policy_disabled"
    case conditionsNotMet = "conditions_not_met"
    case tooManyConcurrentSyncs = "too_many_concurrent_syncs"
    case networkUnavailable = "network_unavailable"
    
    public var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .subscriptionRequired:
            return "Pro subscription required"
        case .policyDisabled:
            return "Sync policy is disabled"
        case .conditionsNotMet:
            return "Sync conditions not met"
        case .tooManyConcurrentSyncs:
            return "Too many concurrent sync operations"
        case .networkUnavailable:
            return "Network connection unavailable"
        }
    }
}

/// Errors that can occur during sync cancellation
public enum SyncCancellationError: String, Codable, CaseIterable, Error {
    case operationNotFound = "operation_not_found"
    case operationAlreadyCompleted = "operation_already_completed"
    case cancellationNotAllowed = "cancellation_not_allowed"
    
    public var localizedDescription: String {
        switch self {
        case .operationNotFound:
            return "Sync operation not found"
        case .operationAlreadyCompleted:
            return "Operation already completed"
        case .cancellationNotAllowed:
            return "Cancellation not allowed for this operation"
        }
    }
}

// MARK: - Extensions

public extension SyncOperationResult {
    /// Get a summary of the operation result
    var summary: String {
        let status = success ? "SUCCESS" : "FAILED"
        let items = "↑\(uploadedCount) ↓\(downloadedCount)"
        let conflicts = conflictCount > 0 ? " ⚠️\(conflictCount)" : ""
        let duration = String(format: "%.1fs", self.duration)
        
        return "\(status): \(items)\(conflicts) (\(duration))"
    }
    
    /// Check if operation had any conflicts
    var hasConflicts: Bool {
        return conflictCount > 0
    }
    
    /// Check if operation processed any data
    var processedData: Bool {
        return uploadedCount > 0 || downloadedCount > 0
    }
}

public extension SyncEligibilityResult {
    /// Create an eligible result
    static var eligible: SyncEligibilityResult {
        return SyncEligibilityResult(isEligible: true)
    }
    
    /// Create an ineligible result with reason
    static func ineligible(
        reason: SyncIneligibilityReason,
        recommendations: [String] = []
    ) -> SyncEligibilityResult {
        return SyncEligibilityResult(
            isEligible: false,
            reason: reason,
            recommendations: recommendations
        )
    }
}