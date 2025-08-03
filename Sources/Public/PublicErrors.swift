//
//  PublicErrors.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation

// MARK: - Main Public Error Types

/// Primary error type for all SwiftSupabaseSync operations
/// Provides user-friendly error messages and recovery suggestions
public enum SwiftSupabaseSyncError: Error, Sendable {
    
    // MARK: - Authentication Errors
    case authenticationFailed(reason: AuthenticationFailureReason)
    case authenticationExpired
    case insufficientPermissions(required: [String])
    case subscriptionRequired(feature: SyncFeature, currentTier: SubscriptionTier)
    
    // MARK: - Network Errors
    case networkUnavailable
    case serverUnreachable(url: String)
    case requestTimeout(duration: TimeInterval)
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(statusCode: Int, message: String?)
    
    // MARK: - Sync Errors
    case syncInProgress
    case syncConflict(conflicts: [ConflictInfo])
    case syncValidationFailed(errors: [String])
    case syncDataCorrupted(modelType: String, recordID: String)
    case syncSchemaIncompatible(localVersion: String, remoteVersion: String)
    
    // MARK: - Configuration Errors
    case invalidConfiguration(parameter: String, reason: String)
    case missingConfiguration(parameter: String)
    case configurationConflict(parameters: [String])
    
    // MARK: - Data Errors
    case dataValidationFailed(field: String, value: Any?, reason: String)
    case dataTransformationFailed(from: String, to: String, reason: String)
    case dataIntegrityViolation(constraint: String, value: Any?)
    case recordNotFound(modelType: String, id: String)
    case duplicateRecord(modelType: String, conflictingField: String)
    
    // MARK: - Storage Errors
    case storageUnavailable
    case storageFull(availableSpace: Int64, requiredSpace: Int64)
    case storageCorrupted(location: String)
    case storagePermissionDenied
    
    // MARK: - System Errors
    case lowMemory
    case backgroundProcessingUnavailable
    case deviceNotSupported(requirement: String)
    case operatingSystemNotSupported(minimum: String, current: String)
    
    // MARK: - Unknown/Unexpected Errors
    case unknown(underlyingError: Error?)
    case internalError(code: String, description: String)
}

/// Specific reasons for authentication failures
public enum AuthenticationFailureReason: String, CaseIterable, Sendable {
    case invalidCredentials = "invalid_credentials"
    case userNotFound = "user_not_found"
    case emailNotVerified = "email_not_verified"
    case accountDisabled = "account_disabled"
    case tooManyAttempts = "too_many_attempts"
    case sessionExpired = "session_expired"
    case tokenInvalid = "token_invalid"
    case biometricFailed = "biometric_failed"
    case networkError = "network_error"
    case serverError = "server_error"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .invalidCredentials: return "The email or password is incorrect"
        case .userNotFound: return "No account found with this email address"
        case .emailNotVerified: return "Please verify your email address before signing in"
        case .accountDisabled: return "This account has been disabled"
        case .tooManyAttempts: return "Too many failed attempts. Please try again later"
        case .sessionExpired: return "Your session has expired. Please sign in again"
        case .tokenInvalid: return "Authentication token is invalid"
        case .biometricFailed: return "Biometric authentication failed"
        case .networkError: return "Network connection required for authentication"
        case .serverError: return "Authentication server is currently unavailable"
        }
    }
    
    /// Whether the user can retry this operation
    public var isRetryable: Bool {
        switch self {
        case .invalidCredentials, .userNotFound, .emailNotVerified, .accountDisabled:
            return false
        case .tooManyAttempts, .sessionExpired, .tokenInvalid, .biometricFailed, .networkError, .serverError:
            return true
        }
    }
}

// MARK: - Error Extensions

extension SwiftSupabaseSyncError: LocalizedError {
    
    /// User-facing error description
    public var errorDescription: String? {
        switch self {
        // Authentication Errors
        case .authenticationFailed(let reason):
            return reason.description
        case .authenticationExpired:
            return "Your session has expired. Please sign in again."
        case .insufficientPermissions(let required):
            return "You don't have permission to perform this action. Required: \(required.joined(separator: ", "))"
        case .subscriptionRequired(let feature, let currentTier):
            return "The \(feature.description) feature requires a higher subscription tier. You currently have \(currentTier)."
            
        // Network Errors
        case .networkUnavailable:
            return "No internet connection available. Please check your network settings."
        case .serverUnreachable(let url):
            return "Unable to connect to the server at \(url). Please try again later."
        case .requestTimeout(let duration):
            return "The request timed out after \(Int(duration)) seconds. Please try again."
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Too many requests. Please wait \(Int(retry)) seconds before trying again."
            } else {
                return "Too many requests. Please try again later."
            }
        case .serverError(let statusCode, let message):
            return message ?? "Server error (\(statusCode)). Please try again later."
            
        // Sync Errors
        case .syncInProgress:
            return "A sync operation is already in progress. Please wait for it to complete."
        case .syncConflict(let conflicts):
            return "Found \(conflicts.count) conflicts that need to be resolved before syncing can continue."
        case .syncValidationFailed(let errors):
            return "Sync validation failed: \(errors.joined(separator: ", "))"
        case .syncDataCorrupted(let modelType, let recordID):
            return "Data corruption detected in \(modelType) record \(recordID)."
        case .syncSchemaIncompatible(let local, let remote):
            return "Local schema version (\(local)) is incompatible with remote version (\(remote))."
            
        // Configuration Errors
        case .invalidConfiguration(let parameter, let reason):
            return "Invalid configuration for '\(parameter)': \(reason)"
        case .missingConfiguration(let parameter):
            return "Missing required configuration: \(parameter)"
        case .configurationConflict(let parameters):
            return "Configuration conflict between: \(parameters.joined(separator: ", "))"
            
        // Data Errors
        case .dataValidationFailed(let field, let value, let reason):
            return "Invalid value for '\(field)' (\(value ?? "nil")): \(reason)"
        case .dataTransformationFailed(let from, let to, let reason):
            return "Failed to transform data from \(from) to \(to): \(reason)"
        case .dataIntegrityViolation(let constraint, let value):
            return "Data integrity violation: \(constraint) failed for value \(value ?? "nil")"
        case .recordNotFound(let modelType, let id):
            return "No \(modelType) record found with ID: \(id)"
        case .duplicateRecord(let modelType, let field):
            return "A \(modelType) record with this \(field) already exists"
            
        // Storage Errors
        case .storageUnavailable:
            return "Local storage is currently unavailable"
        case .storageFull(let available, let required):
            return "Not enough storage space. Need \(required) bytes, but only \(available) available."
        case .storageCorrupted(let location):
            return "Storage corruption detected at: \(location)"
        case .storagePermissionDenied:
            return "Permission denied to access local storage"
            
        // System Errors
        case .lowMemory:
            return "Insufficient memory to complete the operation"
        case .backgroundProcessingUnavailable:
            return "Background processing is not available on this device"
        case .deviceNotSupported(let requirement):
            return "This device doesn't support: \(requirement)"
        case .operatingSystemNotSupported(let minimum, let current):
            return "This app requires \(minimum) or later. You have \(current)."
            
        // Unknown Errors
        case .unknown(let underlyingError):
            return underlyingError?.localizedDescription ?? "An unknown error occurred"
        case .internalError(let code, let description):
            return "Internal error (\(code)): \(description)"
        }
    }
    
    /// Recovery suggestion for the user
    public var recoverySuggestion: String? {
        switch self {
        // Authentication Errors
        case .authenticationFailed(let reason):
            switch reason {
            case .invalidCredentials:
                return "Double-check your email and password, or use 'Forgot Password' if needed."
            case .userNotFound:
                return "Make sure you're using the correct email address, or create a new account."
            case .emailNotVerified:
                return "Check your email for a verification link, or request a new one."
            case .accountDisabled:
                return "Contact support to reactivate your account."
            case .tooManyAttempts:
                return "Wait a few minutes before trying to sign in again."
            case .sessionExpired, .tokenInvalid:
                return "Sign out and sign back in to refresh your session."
            case .biometricFailed:
                return "Try using your password instead, or check your biometric settings."
            case .networkError:
                return "Check your internet connection and try again."
            case .serverError:
                return "Wait a few minutes and try again. If the problem persists, contact support."
            }
        case .authenticationExpired:
            return "Sign out and sign back in to refresh your session."
        case .insufficientPermissions:
            return "Contact your administrator to request the necessary permissions."
        case .subscriptionRequired(_, _):
            return "Upgrade your subscription to access this feature."
            
        // Network Errors
        case .networkUnavailable:
            return "Turn on WiFi or cellular data, then try again."
        case .serverUnreachable:
            return "Check your internet connection and try again in a few minutes."
        case .requestTimeout:
            return "Check your internet connection and try again."
        case .rateLimited:
            return "Wait a few minutes before making more requests."
        case .serverError:
            return "The issue is on our end. Please try again in a few minutes."
            
        // Sync Errors
        case .syncInProgress:
            return "Wait for the current sync to complete, or cancel it if needed."
        case .syncConflict:
            return "Review and resolve the conflicts, then try syncing again."
        case .syncValidationFailed:
            return "Fix the validation errors and try again."
        case .syncDataCorrupted:
            return "Try deleting and recreating the affected record."
        case .syncSchemaIncompatible:
            return "Update the app to the latest version."
            
        // Configuration Errors
        case .invalidConfiguration, .missingConfiguration, .configurationConflict:
            return "Check your app configuration and update any invalid settings."
            
        // Data Errors
        case .dataValidationFailed:
            return "Correct the invalid data and try again."
        case .dataTransformationFailed:
            return "Check the data format and try again."
        case .dataIntegrityViolation:
            return "Ensure all required fields are properly filled."
        case .recordNotFound:
            return "The record may have been deleted. Try refreshing the data."
        case .duplicateRecord:
            return "Use a different value or update the existing record instead."
            
        // Storage Errors
        case .storageUnavailable:
            return "Restart the app and try again."
        case .storageFull:
            return "Free up some storage space and try again."
        case .storageCorrupted:
            return "Restart the app. If the problem persists, you may need to reinstall."
        case .storagePermissionDenied:
            return "Grant storage permissions in your device settings."
            
        // System Errors
        case .lowMemory:
            return "Close other apps to free up memory, then try again."
        case .backgroundProcessingUnavailable:
            return "Enable background app refresh in your device settings."
        case .deviceNotSupported:
            return "This feature is not available on your device."
        case .operatingSystemNotSupported:
            return "Update your device's operating system."
            
        // Unknown Errors
        case .unknown, .internalError:
            return "If this problem continues, please contact support."
        }
    }
    
    /// Error code for logging and debugging
    public var errorCode: String {
        switch self {
        case .authenticationFailed(let reason): return "AUTH_FAILED_\(reason.rawValue.uppercased())"
        case .authenticationExpired: return "AUTH_EXPIRED"
        case .insufficientPermissions: return "AUTH_INSUFFICIENT_PERMISSIONS"
        case .subscriptionRequired: return "SUBSCRIPTION_REQUIRED"
        case .networkUnavailable: return "NETWORK_UNAVAILABLE"
        case .serverUnreachable: return "SERVER_UNREACHABLE"
        case .requestTimeout: return "REQUEST_TIMEOUT"
        case .rateLimited: return "RATE_LIMITED"
        case .serverError: return "SERVER_ERROR"
        case .syncInProgress: return "SYNC_IN_PROGRESS"
        case .syncConflict: return "SYNC_CONFLICT"
        case .syncValidationFailed: return "SYNC_VALIDATION_FAILED"
        case .syncDataCorrupted: return "SYNC_DATA_CORRUPTED"
        case .syncSchemaIncompatible: return "SYNC_SCHEMA_INCOMPATIBLE"
        case .invalidConfiguration: return "CONFIG_INVALID"
        case .missingConfiguration: return "CONFIG_MISSING"
        case .configurationConflict: return "CONFIG_CONFLICT"
        case .dataValidationFailed: return "DATA_VALIDATION_FAILED"
        case .dataTransformationFailed: return "DATA_TRANSFORMATION_FAILED"
        case .dataIntegrityViolation: return "DATA_INTEGRITY_VIOLATION"
        case .recordNotFound: return "RECORD_NOT_FOUND"
        case .duplicateRecord: return "DUPLICATE_RECORD"
        case .storageUnavailable: return "STORAGE_UNAVAILABLE"
        case .storageFull: return "STORAGE_FULL"
        case .storageCorrupted: return "STORAGE_CORRUPTED"
        case .storagePermissionDenied: return "STORAGE_PERMISSION_DENIED"
        case .lowMemory: return "LOW_MEMORY"
        case .backgroundProcessingUnavailable: return "BACKGROUND_PROCESSING_UNAVAILABLE"
        case .deviceNotSupported: return "DEVICE_NOT_SUPPORTED"
        case .operatingSystemNotSupported: return "OS_NOT_SUPPORTED"
        case .unknown: return "UNKNOWN"
        case .internalError(let code, _): return "INTERNAL_\(code)"
        }
    }
    
    /// Whether this error suggests the operation can be retried
    public var isRetryable: Bool {
        switch self {
        case .authenticationFailed(let reason):
            return reason.isRetryable
        case .authenticationExpired:
            return true
        case .insufficientPermissions, .subscriptionRequired:
            return false
        case .networkUnavailable, .serverUnreachable, .requestTimeout, .rateLimited, .serverError:
            return true
        case .syncInProgress:
            return true
        case .syncConflict, .syncValidationFailed:
            return false // Need manual intervention
        case .syncDataCorrupted, .syncSchemaIncompatible:
            return false
        case .invalidConfiguration, .missingConfiguration, .configurationConflict:
            return false
        case .dataValidationFailed, .dataTransformationFailed, .dataIntegrityViolation:
            return false
        case .recordNotFound:
            return true // Might exist after refresh
        case .duplicateRecord:
            return false
        case .storageUnavailable, .storagePermissionDenied:
            return true
        case .storageFull, .storageCorrupted:
            return false
        case .lowMemory:
            return true
        case .backgroundProcessingUnavailable, .deviceNotSupported, .operatingSystemNotSupported:
            return false
        case .unknown:
            return false // Unknown errors should not be auto-retried
        case .internalError:
            return false // Internal errors need investigation
        }
    }
    
    /// Severity level of this error
    public var severity: ErrorSeverity {
        switch self {
        case .authenticationFailed, .authenticationExpired, .insufficientPermissions:
            return .medium
        case .subscriptionRequired:
            return .low
        case .networkUnavailable, .serverUnreachable, .requestTimeout:
            return .medium
        case .rateLimited:
            return .low
        case .serverError:
            return .high
        case .syncInProgress:
            return .low
        case .syncConflict:
            return .medium
        case .syncValidationFailed, .syncDataCorrupted, .syncSchemaIncompatible:
            return .high
        case .invalidConfiguration, .missingConfiguration, .configurationConflict:
            return .high
        case .dataValidationFailed, .dataTransformationFailed, .dataIntegrityViolation:
            return .medium
        case .recordNotFound:
            return .low
        case .duplicateRecord:
            return .medium
        case .storageUnavailable, .storagePermissionDenied, .storageFull, .storageCorrupted:
            return .high
        case .lowMemory:
            return .medium
        case .backgroundProcessingUnavailable:
            return .low
        case .deviceNotSupported, .operatingSystemNotSupported:
            return .high
        case .unknown, .internalError:
            return .critical
        }
    }
}

/// Error severity levels for logging and alerting
public enum ErrorSeverity: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    /// Whether this severity should be reported to crash analytics
    public var shouldReport: Bool {
        switch self {
        case .low, .medium: return false
        case .high, .critical: return true
        }
    }
    
    /// Whether this severity should show an alert to the user
    public var shouldAlert: Bool {
        switch self {
        case .low: return false
        case .medium, .high, .critical: return true
        }
    }
}

// MARK: - Specialized Error Types

/// Authentication-specific error type
public enum PublicAuthenticationError: Error, LocalizedError, Sendable {
    case signInFailed(reason: AuthenticationFailureReason)
    case signUpFailed(reason: String)
    case signOutFailed(reason: String)
    case tokenRefreshFailed
    case biometricNotAvailable
    case biometricNotEnrolled
    case passwordResetFailed(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .signInFailed(let reason):
            return "Sign in failed: \(reason.description)"
        case .signUpFailed(let reason):
            return "Sign up failed: \(reason)"
        case .signOutFailed(let reason):
            return "Sign out failed: \(reason)"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricNotEnrolled:
            return "No biometric credentials are enrolled on this device"
        case .passwordResetFailed(let reason):
            return "Password reset failed: \(reason)"
        }
    }
}

/// Network-specific error type
public enum PublicNetworkError: Error, LocalizedError, Sendable {
    case noConnection
    case slowConnection
    case connectionLost
    case serverMaintenance
    case invalidResponse(statusCode: Int)
    case sslError(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .slowConnection:
            return "Connection is too slow for this operation"
        case .connectionLost:
            return "Connection was lost during the operation"
        case .serverMaintenance:
            return "Server is undergoing maintenance"
        case .invalidResponse(let statusCode):
            return "Received invalid response from server (HTTP \(statusCode))"
        case .sslError(let reason):
            return "SSL connection error: \(reason)"
        }
    }
}

/// Data validation error type
public enum PublicValidationError: Error, LocalizedError, Sendable {
    case requiredFieldMissing(field: String)
    case invalidFormat(field: String, expected: String)
    case valueOutOfRange(field: String, min: String?, max: String?)
    case customValidationFailed(field: String, rule: String)
    
    public var errorDescription: String? {
        switch self {
        case .requiredFieldMissing(let field):
            return "Required field '\(field)' is missing"
        case .invalidFormat(let field, let expected):
            return "Invalid format for '\(field)'. Expected: \(expected)"
        case .valueOutOfRange(let field, let min, let max):
            var message = "Value for '\(field)' is out of range"
            if let min = min, let max = max {
                message += " (must be between \(min) and \(max))"
            } else if let min = min {
                message += " (must be at least \(min))"
            } else if let max = max {
                message += " (must be at most \(max))"
            }
            return message
        case .customValidationFailed(let field, let rule):
            return "Validation failed for '\(field)': \(rule)"
        }
    }
}

// MARK: - Error Conversion Utilities

extension SwiftSupabaseSyncError {
    
    /// Convert from an authentication error
    public static func from(_ error: PublicAuthenticationError) -> SwiftSupabaseSyncError {
        switch error {
        case .signInFailed(let reason):
            return .authenticationFailed(reason: reason)
        case .tokenRefreshFailed:
            return .authenticationExpired
        default:
            return .unknown(underlyingError: error)
        }
    }
    
    /// Convert from a network error
    public static func from(_ error: PublicNetworkError) -> SwiftSupabaseSyncError {
        switch error {
        case .noConnection:
            return .networkUnavailable
        case .serverMaintenance:
            return .serverError(statusCode: 503, message: "Server maintenance")
        case .invalidResponse(let statusCode):
            return .serverError(statusCode: statusCode, message: nil)
        default:
            return .unknown(underlyingError: error)
        }
    }
    
    /// Convert from a validation error
    public static func from(_ error: PublicValidationError) -> SwiftSupabaseSyncError {
        switch error {
        case .requiredFieldMissing(let field):
            return .dataValidationFailed(field: field, value: nil, reason: "Required field is missing")
        case .invalidFormat(let field, let expected):
            return .dataValidationFailed(field: field, value: nil, reason: "Invalid format, expected: \(expected)")
        case .valueOutOfRange(let field, let min, let max):
            return .dataValidationFailed(field: field, value: nil, reason: "Value out of range (\(min ?? "nil") - \(max ?? "nil"))")
        case .customValidationFailed(let field, let rule):
            return .dataValidationFailed(field: field, value: nil, reason: rule)
        }
    }
}
