//
//  AuthAPI.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Main AuthAPI Class

/// Main public interface for authentication operations in SwiftSupabaseSync
/// Provides a clean, type-safe API for sign in, sign up, sign out, and session management
/// Integrates seamlessly with SwiftUI through ObservableObject and Combine publishers
@MainActor
public final class AuthAPI: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current authenticated user information (public-friendly format)
    @Published public private(set) var currentUser: UserInfo?
    
    /// Whether a user is currently authenticated
    @Published public private(set) var isAuthenticated: Bool = false
    
    /// Whether an authentication operation is in progress
    @Published public private(set) var isLoading: Bool = false
    
    /// Current authentication status with user-friendly descriptions
    @Published public private(set) var authenticationStatus: PublicAuthenticationStatus = .signedOut
    
    /// Last authentication error (if any)
    @Published public private(set) var lastError: SwiftSupabaseSyncError?
    
    // MARK: - Combine Publishers
    
    /// Publisher for authentication state changes
    public var authenticationStatePublisher: AnyPublisher<PublicAuthenticationStatus, Never> {
        $authenticationStatus.eraseToAnyPublisher()
    }
    
    /// Publisher for current user changes
    public var currentUserPublisher: AnyPublisher<UserInfo?, Never> {
        $currentUser.eraseToAnyPublisher()
    }
    
    /// Publisher for loading state changes
    public var loadingStatePublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }
    
    /// Publisher for error events
    public var errorPublisher: AnyPublisher<SwiftSupabaseSyncError?, Never> {
        $lastError.eraseToAnyPublisher()
    }
    
    // MARK: - Internal Dependencies
    
    private let authManager: AuthManager
    private let observerManager: AuthObserverManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize AuthAPI with dependency injection
    /// This should be called internally by the main SwiftSupabaseSync class
    internal init(authManager: AuthManager) {
        self.authManager = authManager
        self.observerManager = AuthObserverManager()
        
        setupBindings()
    }
    
    /// Convenience initializer for internal use with service locator
    internal convenience init() {
        guard let authManager = try? ServiceLocator.shared.resolve(AuthManager.self) else {
            fatalError("AuthAPI: AuthManager not registered in ServiceLocator. Ensure SwiftSupabaseSync is properly initialized.")
        }
        self.init(authManager: authManager)
    }
    
    // MARK: - Public Authentication Methods
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Public authentication result
    /// - Throws: SwiftSupabaseSyncError for authentication failures
    @discardableResult
    public func signIn(email: String, password: String) async throws -> PublicAuthenticationResult {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let result = try await authManager.signIn(email: email, password: password)
            let publicResult = convertToPublicResult(result)
            
            // Notify observers
            if publicResult.isSuccess, let user = currentUser {
                observerManager.notifySignIn(user)
            } else if let error = publicResult.error {
                observerManager.notifyAuthenticationFailure(error)
            }
            
            return publicResult
        } catch {
            let syncError = convertToSyncError(error)
            await MainActor.run {
                self.lastError = syncError
            }
            observerManager.notifyAuthenticationFailure(syncError)
            throw syncError
        }
    }
    
    /// Sign up new user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - displayName: Optional display name for the user
    /// - Returns: Public authentication result
    /// - Throws: SwiftSupabaseSyncError for sign up failures
    @discardableResult
    public func signUp(email: String, password: String, displayName: String? = nil) async throws -> PublicAuthenticationResult {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let result = try await authManager.signUp(email: email, password: password, name: displayName)
            let publicResult = convertToPublicResult(result)
            
            // Notify observers
            if publicResult.isSuccess, let user = currentUser {
                observerManager.notifySignIn(user)
            } else if let error = publicResult.error {
                observerManager.notifyAuthenticationFailure(error)
            }
            
            return publicResult
        } catch {
            let syncError = convertToSyncError(error)
            await MainActor.run {
                self.lastError = syncError
            }
            observerManager.notifyAuthenticationFailure(syncError)
            throw syncError
        }
    }
    
    /// Sign out current user
    /// - Returns: Whether sign out was successful
    /// - Throws: SwiftSupabaseSyncError for sign out failures
    @discardableResult
    public func signOut() async throws -> Bool {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let result = try await authManager.signOut()
            
            if result.success {
                observerManager.notifySignOut()
                return true
            } else {
                if let error = result.error {
                    let syncError = convertToSyncError(error)
                    await MainActor.run {
                        self.lastError = syncError
                    }
                    throw syncError
                }
                return false
            }
        } catch {
            let syncError = convertToSyncError(error)
            await MainActor.run {
                self.lastError = syncError
            }
            throw syncError
        }
    }
    
    /// Refresh the current authentication token
    /// - Returns: Whether token refresh was successful
    /// - Throws: SwiftSupabaseSyncError for refresh failures
    @discardableResult
    public func refreshToken() async throws -> Bool {
        setLoading(true)
        defer { setLoading(false) }
        
        do {
            let result = try await authManager.refreshToken()
            
            if result.success, let user = currentUser {
                observerManager.notifyTokenRefresh(user)
                return true
            } else {
                if let error = result.error {
                    let syncError = convertToSyncError(error)
                    await MainActor.run {
                        self.lastError = syncError
                    }
                    throw syncError
                }
                return false
            }
        } catch {
            let syncError = convertToSyncError(error)
            await MainActor.run {
                self.lastError = syncError
            }
            throw syncError
        }
    }
    
    /// Validate the current session
    /// - Returns: Whether the session is valid
    /// - Throws: SwiftSupabaseSyncError for validation failures
    @discardableResult
    public func validateSession() async throws -> Bool {
        do {
            let result = try await authManager.validateSession()
            return result.isValid
        } catch {
            let syncError = convertToSyncError(error)
            await MainActor.run {
                self.lastError = syncError
            }
            throw syncError
        }
    }
    
    // MARK: - Feature Access & Subscription
    
    /// Check if current user has access to a specific sync feature
    /// - Parameter feature: The sync feature to check
    /// - Returns: Whether the user has access to the feature
    public func hasFeatureAccess(_ feature: SyncFeature) async -> Bool {
        guard let user = currentUser else { return false }
        
        // Use the subscription tier to determine feature access
        return user.subscriptionTier.features.contains(feature)
    }
    
    /// Get current user's subscription information
    /// - Returns: User's subscription tier and capabilities
    /// - Throws: SwiftSupabaseSyncError if user is not authenticated
    public func getSubscriptionInfo() async throws -> SubscriptionInfo {
        guard isAuthenticated, let user = currentUser else {
            throw SwiftSupabaseSyncError.authenticationExpired
        }
        
        return SubscriptionInfo(
            tier: user.subscriptionTier,
            availableFeatures: user.subscriptionTier.features,
            maxDevices: user.subscriptionTier.maxDevices,
            minSyncInterval: user.subscriptionTier.minSyncInterval,
            isActive: true,
            expiresAt: nil
        )
    }
    
    // MARK: - Observer Management
    
    /// Add an authentication state observer
    /// - Parameter observer: Observer to receive authentication events
    public func addAuthObserver(_ observer: AuthenticationObserver) {
        observerManager.addObserver(observer)
    }
    
    /// Remove an authentication state observer
    /// - Parameter observer: Observer to remove
    public func removeAuthObserver(_ observer: AuthenticationObserver) {
        observerManager.removeObserver(observer)
    }
    
    // MARK: - Convenience Methods
    
    /// Check if user is authenticated (synchronous)
    public var isUserAuthenticated: Bool {
        return isAuthenticated
    }
    
    /// Get current user ID if authenticated
    public var currentUserID: UUID? {
        return currentUser?.id
    }
    
    /// Get current user email if authenticated
    public var currentUserEmail: String? {
        return currentUser?.email
    }
    
    /// Get current subscription tier
    public var subscriptionTier: PublicSubscriptionTier? {
        return currentUser?.subscriptionTier
    }
    
    // MARK: - Private Implementation
    
    private func setLoading(_ loading: Bool) {
        Task { @MainActor in
            self.isLoading = loading
        }
    }
    
    /// Setup bindings between internal AuthManager and public properties
    private func setupBindings() {
        print("🔍 [AuthAPI] Setting up bindings")
        
        // Bind authentication state
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                print("🔍 [AuthAPI] Received isAuthenticated update: \(isAuthenticated)")
                self?.isAuthenticated = isAuthenticated
                print("🔍 [AuthAPI] AuthAPI isAuthenticated set to: \(self?.isAuthenticated ?? false)")
            }
            .store(in: &cancellables)
        
        authManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        // Convert internal User to public UserInfo
        authManager.$currentUser
            .map { user in
                user?.toPublicUserInfo()
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)
        
        // Convert internal AuthenticationStatus to public
        authManager.$authStatus
            .map { status in
                PublicAuthenticationStatus.fromInternal(status)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.authenticationStatus, on: self)
            .store(in: &cancellables)
        
        // Convert internal errors to public errors
        authManager.$lastError
            .map { error in
                error?.toSwiftSupabaseSyncError()
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastError, on: self)
            .store(in: &cancellables)
    }
}