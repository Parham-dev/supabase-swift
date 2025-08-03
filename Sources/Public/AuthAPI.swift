//
//  AuthAPI.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Public Authentication Status

/// Public authentication status enum
public enum PublicAuthenticationStatus: String, CaseIterable, Sendable {
    case signedOut = "signed_out"
    case signingIn = "signing_in"
    case signedIn = "signed_in"
    case signingOut = "signing_out"
    case refreshingToken = "refreshing_token"
    case sessionExpired = "session_expired"
    case error = "error"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .signedOut: return "Signed Out"
        case .signingIn: return "Signing In"
        case .signedIn: return "Signed In"
        case .signingOut: return "Signing Out"
        case .refreshingToken: return "Refreshing Token"
        case .sessionExpired: return "Session Expired"
        case .error: return "Authentication Error"
        }
    }
    
    /// Whether user can perform sync operations in this state
    public var canSync: Bool {
        return self == .signedIn
    }
    
    /// Convert from internal authentication status
    internal static func fromInternal(_ status: AuthenticationStatus) -> PublicAuthenticationStatus {
        switch status {
        case .unauthenticated: return .signedOut
        case .authenticated: return .signedIn
        case .expired: return .sessionExpired
        case .refreshing: return .refreshingToken
        case .error(_): return .error
        }
    }
}

// MARK: - Public Authentication Result

/// Public authentication result for external consumers
public struct PublicAuthenticationResult: Sendable {
    /// Whether authentication was successful
    public let isSuccess: Bool
    
    /// Authenticated user information (if successful)
    public let user: UserInfo?
    
    /// Whether this represents a new user registration
    public let isNewUser: Bool
    
    /// Authentication timestamp
    public let authenticatedAt: Date
    
    /// Error information (if failed)
    public let error: SwiftSupabaseSyncError?
    
    public init(
        isSuccess: Bool,
        user: UserInfo? = nil,
        isNewUser: Bool = false,
        authenticatedAt: Date = Date(),
        error: SwiftSupabaseSyncError? = nil
    ) {
        self.isSuccess = isSuccess
        self.user = user
        self.isNewUser = isNewUser
        self.authenticatedAt = authenticatedAt
        self.error = error
    }
}

// MARK: - Public Authentication Error Helper

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
    
    private func setLoading(_ loading: Bool) {
        Task { @MainActor in
            self.isLoading = loading
        }
    }
}

// MARK: - Conversion Extensions

extension AuthAPI {
    
    /// Convert internal AuthenticationResult to public result
    private func convertToPublicResult(_ result: AuthenticationResult) -> PublicAuthenticationResult {
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
    private func convertToSyncError(_ error: Error) -> SwiftSupabaseSyncError {
        if let authError = error as? AuthenticationError {
            return authError.toSwiftSupabaseSyncError()
        } else if let syncError = error as? SwiftSupabaseSyncError {
            return syncError
        } else {
            return SwiftSupabaseSyncError.unknown(underlyingError: error)
        }
    }
}

// MARK: - Internal Extensions

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

// MARK: - Subscription Information

/// Subscription information for public consumption
public struct SubscriptionInfo: Sendable {
    /// Current subscription tier
    public let tier: PublicSubscriptionTier
    
    /// Available features for this tier
    public let availableFeatures: [SyncFeature]
    
    /// Maximum number of devices allowed
    public let maxDevices: Int
    
    /// Minimum sync interval allowed (in seconds)
    public let minSyncInterval: TimeInterval
    
    /// Whether subscription is active
    public let isActive: Bool
    
    /// Subscription expiration date (if applicable)
    public let expiresAt: Date?
    
    public init(
        tier: PublicSubscriptionTier,
        availableFeatures: [SyncFeature],
        maxDevices: Int,
        minSyncInterval: TimeInterval,
        isActive: Bool,
        expiresAt: Date? = nil
    ) {
        self.tier = tier
        self.availableFeatures = availableFeatures
        self.maxDevices = maxDevices
        self.minSyncInterval = minSyncInterval
        self.isActive = isActive
        self.expiresAt = expiresAt
    }
}
