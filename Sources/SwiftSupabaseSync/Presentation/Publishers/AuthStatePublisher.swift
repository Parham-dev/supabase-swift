//
//  AuthStatePublisher.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Combine
import SwiftUI

/// Reactive publisher that wraps AuthManager state for seamless SwiftUI integration
/// Provides clean, observable access to authentication state, user info, and auth operations
@MainActor
public final class AuthStatePublisher: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current authenticated user
    @Published public private(set) var currentUser: User?
    
    /// Whether user is currently authenticated
    @Published public private(set) var isAuthenticated: Bool
    
    /// Whether authentication operation is in progress
    @Published public private(set) var isLoading: Bool
    
    /// Current authentication status
    @Published public private(set) var authStatus: AuthenticationStatus
    
    /// Last authentication error
    @Published public private(set) var lastError: AuthenticationError?
    
    /// Whether biometric authentication is available and enabled
    @Published public private(set) var isBiometricEnabled: Bool
    
    // MARK: - Derived Published Properties
    
    /// Whether there's an authentication error
    @Published public private(set) var hasError: Bool = false
    
    /// User-friendly authentication status description
    @Published public private(set) var statusDescription: String = "Not signed in"
    
    /// Whether user has an active subscription
    @Published public private(set) var hasActiveSubscription: Bool = false
    
    /// Current subscription tier
    @Published public private(set) var subscriptionTier: SubscriptionTier = .free
    
    /// Available features for current user
    @Published public private(set) var availableFeatures: Set<Feature> = []
    
    /// Whether user can perform auth operations (not loading)
    @Published public private(set) var canPerformAuthOperations: Bool = true
    
    // MARK: - Dependencies
    
    private let authManager: AuthManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(authManager: AuthManager) {
        self.authManager = authManager
        
        // Initialize with current values
        self.currentUser = authManager.currentUser
        self.isAuthenticated = authManager.isAuthenticated
        self.isLoading = authManager.isLoading
        self.authStatus = authManager.authStatus
        self.lastError = authManager.lastError
        self.isBiometricEnabled = authManager.isBiometricEnabled
        
        // Calculate derived properties
        updateDerivedProperties()
        
        // Setup reactive bindings
        setupPublisherBindings()
    }
    
    // MARK: - Public Computed Properties
    
    /// Whether user is signed in and authenticated
    public var isSignedIn: Bool {
        isAuthenticated && currentUser != nil
    }
    
    /// Whether authentication is in a stable state (not loading or refreshing)
    public var isStable: Bool {
        !isLoading && authStatus != .refreshing
    }
    
    /// Whether user needs to sign in
    public var needsSignIn: Bool {
        !isAuthenticated || authStatus == .unauthenticated
    }
    
    /// Whether token needs refresh
    public var needsTokenRefresh: Bool {
        currentUser?.needsTokenRefresh ?? false
    }
    
    /// User's display name or email fallback
    public var displayName: String? {
        currentUser?.name ?? currentUser?.email
    }
    
    /// User's initials for avatar display
    public var initials: String {
        guard let user = currentUser else { return "?" }
        
        if let name = user.name {
            let components = name.components(separatedBy: " ")
            let initials = components.compactMap { $0.first }.prefix(2)
            return String(initials).uppercased()
        } else {
            return String(user.email.prefix(1)).uppercased()
        }
    }
    
    /// Time since last authentication
    public var timeSinceLastAuth: TimeInterval? {
        guard let lastAuth = currentUser?.lastAuthenticatedAt else { return nil }
        return Date().timeIntervalSince(lastAuth)
    }
    
    /// Formatted time since last authentication
    public var formattedTimeSinceLastAuth: String {
        guard let timeSince = timeSinceLastAuth else {
            return "Never"
        }
        
        if timeSince < 3600 { // Less than 1 hour
            let minutes = Int(timeSince / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeSince < 86400 { // Less than 1 day
            let hours = Int(timeSince / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(timeSince / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    // MARK: - Authentication Operations
    
    /// Sign in with email and password
    public func signIn(email: String, password: String) async throws -> AuthenticationResult {
        return try await authManager.signIn(email: email, password: password)
    }
    
    /// Sign up new user with email and password
    public func signUp(email: String, password: String, name: String? = nil) async throws -> AuthenticationResult {
        return try await authManager.signUp(email: email, password: password, name: name)
    }
    
    /// Sign out current user
    public func signOut() async throws -> SignOutResult {
        return try await authManager.signOut()
    }
    
    /// Refresh authentication token
    public func refreshToken() async throws -> AuthenticationResult {
        return try await authManager.refreshToken()
    }
    
    /// Validate current session
    public func validateSession() async throws -> SessionValidationResult {
        return try await authManager.validateSession()
    }
    
    /// Clear current authentication error
    public func clearError() {
        authManager.clearError()
    }
    
    /// Force session validation
    public func forceSessionValidation() async {
        await authManager.forceSessionValidation()
    }
    
    // MARK: - Feature Access
    
    /// Check if user has access to a specific feature
    public func hasFeatureAccess(_ feature: Feature) async -> Bool {
        return await authManager.hasFeatureAccess(feature)
    }
    
    /// Get current subscription status
    public func getSubscriptionStatus() async throws -> SubscriptionValidationResult {
        return try await authManager.getSubscriptionStatus()
    }
    
    // MARK: - Private Implementation
    
    private func setupPublisherBindings() {
        // Bind AuthManager's published properties to our published properties
        authManager.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                self?.isAuthenticated = isAuthenticated
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        authManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
                self?.canPerformAuthOperations = !isLoading
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        authManager.$authStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.authStatus = status
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        authManager.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.lastError = error
                self?.hasError = error != nil
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        authManager.$isBiometricEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isBiometricEnabled = isEnabled
            }
            .store(in: &cancellables)
    }
    
    private func updateDerivedProperties() {
        // Update status description based on current state
        if let error = lastError {
            statusDescription = "Error: \(error.localizedDescription)"
        } else if isLoading {
            statusDescription = "Loading..."
        } else {
            switch authStatus {
            case .authenticated:
                statusDescription = "Signed in"
            case .unauthenticated:
                statusDescription = "Not signed in"
            case .expired:
                statusDescription = "Session expired"
            case .refreshing:
                statusDescription = "Refreshing session..."
            case .error(let error):
                statusDescription = "Error: \(error.localizedDescription)"
            }
        }
        
        // Update subscription and feature information
        if let user = currentUser {
            hasActiveSubscription = user.hasActiveSubscription
            subscriptionTier = user.subscriptionTier
            availableFeatures = user.availableFeatures
        } else {
            hasActiveSubscription = false
            subscriptionTier = .free
            availableFeatures = []
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - SwiftUI Convenience Extensions

public extension AuthStatePublisher {
    
    /// Color for current authentication status (for UI indicators)
    var statusColor: Color {
        if hasError {
            return .red
        } else if isLoading {
            return .orange
        } else if isAuthenticated {
            return .green
        } else {
            return .gray
        }
    }
    
    /// SF Symbol name for current authentication status
    var statusIcon: String {
        if hasError {
            return "exclamationmark.triangle.fill"
        } else if isLoading {
            return "arrow.triangle.2.circlepath"
        } else if isAuthenticated {
            return "person.fill.checkmark"
        } else {
            return "person.fill.xmark"
        }
    }
    
    /// SwiftUI binding for email input validation
    func emailBinding(for email: Binding<String>) -> Binding<String> {
        Binding(
            get: { email.wrappedValue },
            set: { newValue in
                email.wrappedValue = newValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            }
        )
    }
    
    /// Validate email format
    func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    /// Validate password strength
    func validatePassword(_ password: String) -> PasswordValidation {
        var issues: [String] = []
        
        if password.count < 8 {
            issues.append("At least 8 characters")
        }
        
        if !password.contains(where: { $0.isUppercase }) {
            issues.append("One uppercase letter")
        }
        
        if !password.contains(where: { $0.isLowercase }) {
            issues.append("One lowercase letter")
        }
        
        if !password.contains(where: { $0.isNumber }) {
            issues.append("One number")
        }
        
        let specialCharacters = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        if password.rangeOfCharacter(from: specialCharacters) == nil {
            issues.append("One special character")
        }
        
        return PasswordValidation(
            isValid: issues.isEmpty,
            strength: passwordStrength(for: password),
            issues: issues
        )
    }
    
    private func passwordStrength(for password: String) -> PasswordStrength {
        var score = 0
        
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isLowercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        
        let specialCharacters = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        if password.rangeOfCharacter(from: specialCharacters) != nil { score += 1 }
        
        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5...6: return .strong
        default: return .strong
        }
    }
}

// MARK: - Combine Publishers

public extension AuthStatePublisher {
    
    /// Publisher that emits when authentication state changes significantly
    var authStateChangePublisher: AnyPublisher<AuthenticationStatus, Never> {
        $authStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when user changes (sign in/out)
    var userChangePublisher: AnyPublisher<User?, Never> {
        $currentUser
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when errors occur or are cleared
    var errorPublisher: AnyPublisher<AuthenticationError?, Never> {
        $lastError
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when loading state changes
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when subscription status changes
    var subscriptionChangePublisher: AnyPublisher<SubscriptionTier, Never> {
        $subscriptionTier
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Types

/// Password validation result
public struct PasswordValidation {
    public let isValid: Bool
    public let strength: PasswordStrength
    public let issues: [String]
}

/// Password strength levels
public enum PasswordStrength: CaseIterable {
    case weak
    case medium
    case strong
    
    public var description: String {
        switch self {
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }
    
    public var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }
}