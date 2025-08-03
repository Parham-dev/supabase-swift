//
//  AuthExtensions.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Foundation

// MARK: - Internal Model Extensions

extension User {
    func toPublicUserInfo() -> UserInfo {
        return UserInfo(
            id: self.id,
            email: self.email,
            displayName: self.name,
            avatarURL: self.avatarURL,
            metadata: [:],   // Not available in internal User model
            createdAt: self.createdAt,
            lastSignInAt: self.lastAuthenticatedAt,
            emailVerified: true,  // Assume verified if user exists
            subscriptionTier: PublicSubscriptionTier.fromInternal(self.subscriptionTier)
        )
    }
}

extension AuthenticationError {
    func toSwiftSupabaseSyncError() -> SwiftSupabaseSyncError {
        switch self {
        case .invalidCredentials:
            return SwiftSupabaseSyncError.authenticationFailed(reason: .invalidCredentials)
        case .userNotFound:
            return SwiftSupabaseSyncError.authenticationFailed(reason: .userNotFound)
        case .emailNotVerified:
            return SwiftSupabaseSyncError.authenticationFailed(reason: .emailNotVerified)
        case .accountLocked:
            return SwiftSupabaseSyncError.authenticationFailed(reason: .accountDisabled)
        case .networkError:
            return SwiftSupabaseSyncError.networkUnavailable
        case .tokenExpired:
            return SwiftSupabaseSyncError.authenticationExpired
        case .tokenRefreshFailed:
            return SwiftSupabaseSyncError.authenticationFailed(reason: .tokenInvalid)
        case .unknownError(let message):
            return SwiftSupabaseSyncError.unknown(underlyingError: NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }
}

extension PublicSubscriptionTier {
    static func fromInternal(_ tier: SubscriptionTier) -> PublicSubscriptionTier {
        switch tier {
        case .free:
            return .free
        case .pro:
            return .pro
        case .enterprise:
            return .enterprise
        case .custom(_):
            return .enterprise  // Map custom to enterprise for public API
        }
    }
}

// MARK: - AuthAPI Conversion Extensions

extension AuthAPI {
    
    /// Convert internal AuthenticationResult to public result
    internal func convertToPublicResult(_ result: AuthenticationResult) -> PublicAuthenticationResult {
        if result.success, let user = result.user {
            let publicUser = user.toPublicUserInfo()
            return PublicAuthenticationResult(
                isSuccess: true,
                user: publicUser,
                isNewUser: result.isNewUser,
                authenticatedAt: result.authenticatedAt,
                error: nil
            )
        } else {
            let error = result.error?.toSwiftSupabaseSyncError() ?? 
                       SwiftSupabaseSyncError.unknown(underlyingError: NSError(domain: "AuthAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unknown authentication error"]))
            return PublicAuthenticationResult(
                isSuccess: false,
                user: nil,
                isNewUser: false,
                authenticatedAt: result.authenticatedAt,
                error: error
            )
        }
    }
    
    /// Convert any error to SwiftSupabaseSyncError
    internal func convertToSyncError(_ error: Error) -> SwiftSupabaseSyncError {
        if let authError = error as? AuthenticationError {
            return authError.toSwiftSupabaseSyncError()
        } else if let syncError = error as? SwiftSupabaseSyncError {
            return syncError
        } else {
            return SwiftSupabaseSyncError.unknown(underlyingError: error)
        }
    }
}