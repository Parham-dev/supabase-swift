//
//  AuthObservers.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Foundation
import Dispatch

// MARK: - Auth Observer Manager

/// Internal class to manage authentication observers
internal class AuthObserverManager {
    private var observers: [WeakAuthObserver] = []
    private let queue = DispatchQueue(label: "auth.observer.queue", attributes: .concurrent)
    
    func addObserver(_ observer: AuthenticationObserver) {
        queue.async(flags: .barrier) {
            self.observers.append(WeakAuthObserver(observer))
            self.cleanupDeallocatedObservers()
        }
    }
    
    func removeObserver(_ observer: AuthenticationObserver) {
        queue.async(flags: .barrier) {
            self.observers.removeAll { $0.observer === observer }
        }
    }
    
    func notifySignIn(_ user: UserInfo) {
        queue.async {
            self.observers.forEach { $0.observer?.userDidSignIn(user) }
        }
    }
    
    func notifySignOut() {
        queue.async {
            self.observers.forEach { $0.observer?.userDidSignOut() }
        }
    }
    
    func notifyTokenRefresh(_ user: UserInfo) {
        queue.async {
            self.observers.forEach { $0.observer?.authenticationDidRefresh(for: user) }
        }
    }
    
    func notifyAuthenticationFailure(_ error: SwiftSupabaseSyncError) {
        queue.async {
            let publicError = self.convertToPublicAuthError(error)
            self.observers.forEach { $0.observer?.authenticationDidFail(with: publicError) }
        }
    }
    
    private func cleanupDeallocatedObservers() {
        observers.removeAll { $0.observer == nil }
    }
    
    private func convertToPublicAuthError(_ error: SwiftSupabaseSyncError) -> PublicAuthenticationError {
        switch error {
        case .authenticationFailed(let reason):
            return PublicAuthenticationError.signInFailed(reason: reason)
        case .authenticationExpired:
            return PublicAuthenticationError.tokenRefreshFailed
        case .networkUnavailable, .serverUnreachable, .requestTimeout:
            return PublicAuthenticationError.signInFailed(reason: .networkError)
        case .serverError(_, _):
            return PublicAuthenticationError.signInFailed(reason: .serverError)
        default:
            return PublicAuthenticationError.signInFailed(reason: .serverError)
        }
    }
}

/// Weak reference wrapper for observers
private class WeakAuthObserver {
    weak var observer: AuthenticationObserver?
    
    init(_ observer: AuthenticationObserver) {
        self.observer = observer
    }
}