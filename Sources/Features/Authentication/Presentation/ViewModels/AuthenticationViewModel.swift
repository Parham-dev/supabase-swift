//
//  AuthenticationViewModel.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for handling authentication flows, form validation, and user session management
/// Provides a clean interface for SwiftUI views to interact with authentication functionality
@MainActor
public final class AuthenticationViewModel: ObservableObject {
    
    // MARK: - Form State Properties
    
    /// Email input for authentication forms
    @Published public var email: String = ""
    
    /// Password input for authentication forms
    @Published public var password: String = ""
    
    /// Confirm password input for sign up forms
    @Published public var confirmPassword: String = ""
    
    /// Display name input for sign up forms
    @Published public var displayName: String = ""
    
    /// Whether to remember user credentials
    @Published public var rememberMe: Bool = false
    
    /// Whether to show password in plain text
    @Published public var showPassword: Bool = false
    
    // MARK: - Form Validation State
    
    /// Email validation result
    @Published public private(set) var emailValidation: FormValidationResult = .idle
    
    /// Password validation result
    @Published public private(set) var passwordValidation: PasswordValidation = PasswordValidation.empty
    
    /// Confirm password validation result
    @Published public private(set) var confirmPasswordValidation: FormValidationResult = .idle
    
    /// Display name validation result
    @Published public private(set) var displayNameValidation: FormValidationResult = .idle
    
    /// Overall form validation state
    @Published public private(set) var isFormValid: Bool = false
    
    // MARK: - Authentication State
    
    /// Current authenticated user (from AuthStatePublisher)
    @Published public private(set) var currentUser: User?
    
    /// Whether user is authenticated (from AuthStatePublisher)
    @Published public private(set) var isAuthenticated: Bool = false
    
    /// Whether authentication operation is in progress (from AuthStatePublisher)
    @Published public private(set) var isLoading: Bool = false
    
    /// Current authentication status (from AuthStatePublisher)
    @Published public private(set) var authStatus: AuthenticationStatus = .unauthenticated
    
    /// Last authentication error (from AuthStatePublisher)
    @Published public private(set) var lastError: AuthenticationError?
    
    // MARK: - UI State
    
    /// Current authentication flow mode
    @Published public var authMode: AuthMode = .signIn
    
    /// Whether to show biometric authentication option
    @Published public private(set) var canUseBiometrics: Bool = false
    
    /// Whether form should auto-focus on email field
    @Published public var shouldFocusEmail: Bool = true
    
    /// Form submission attempt count (for validation display)
    @Published public private(set) var submissionAttempts: Int = 0
    
    // MARK: - Dependencies
    
    private let authStatePublisher: AuthStatePublisher
    private let networkStatusPublisher: NetworkStatusPublisher
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Validation Configuration
    
    private let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
    private let minPasswordLength = 8
    private let maxPasswordLength = 128
    private let minDisplayNameLength = 2
    private let maxDisplayNameLength = 50
    
    // MARK: - Initialization
    
    public init(
        authStatePublisher: AuthStatePublisher,
        networkStatusPublisher: NetworkStatusPublisher
    ) {
        self.authStatePublisher = authStatePublisher
        self.networkStatusPublisher = networkStatusPublisher
        
        setupBindings()
        setupValidation()
    }
    
    // MARK: - Authentication Operations
    
    /// Sign in with email and password
    public func signIn() async {
        await performAuthenticationOperation { [self] in
            try await authStatePublisher.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), 
                                               password: password)
        }
    }
    
    /// Sign up with email, password, and optional display name
    public func signUp() async {
        await performAuthenticationOperation { [self] in
            let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = trimmedName.isEmpty ? nil : trimmedName
            
            return try await authStatePublisher.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                name: name
            )
        }
    }
    
    /// Sign out current user
    public func signOut() async {
        await performAuthenticationOperation { [self] in
            let signOutResult = try await authStatePublisher.signOut()
            return AuthenticationResult(success: signOutResult.success, user: nil, authenticationMethod: .emailPassword, error: signOutResult.error)
        }
    }
    
    /// Refresh current authentication token
    public func refreshToken() async {
        guard !isLoading else { return }
        
        do {
            _ = try await authStatePublisher.refreshToken()
        } catch {
            // Error handling managed by AuthStatePublisher
        }
    }
    
    /// Validate current session
    public func validateSession() async {
        do {
            _ = try await authStatePublisher.validateSession()
        } catch {
            // Error handling managed by AuthStatePublisher
        }
    }
    
    // MARK: - Form Management
    
    /// Clear all form fields
    public func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        rememberMe = false
        showPassword = false
        submissionAttempts = 0
        
        // Reset validation states
        emailValidation = .idle
        passwordValidation = PasswordValidation.empty
        confirmPasswordValidation = .idle
        displayNameValidation = .idle
    }
    
    /// Switch between sign in and sign up modes
    public func toggleAuthMode() {
        authMode = authMode == .signIn ? .signUp : .signIn
        clearForm()
        shouldFocusEmail = true
    }
    
    /// Pre-fill form with remembered credentials
    public func loadRememberedCredentials() {
        // This would typically load from secure storage
        // Implementation depends on keychain integration
    }
    
    /// Clear authentication error
    public func clearError() {
        authStatePublisher.clearError()
    }
    
    // MARK: - Validation Methods
    
    /// Validate email format and availability
    public func validateEmail() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic format validation
        guard !trimmedEmail.isEmpty else {
            emailValidation = FormValidationResult.idle
            return
        }
        
        guard trimmedEmail.range(of: emailRegex, options: .regularExpression) != nil else {
            emailValidation = FormValidationResult.invalid("Please enter a valid email address")
            return
        }
        
        // Check for common typos
        if trimmedEmail.contains("..") || trimmedEmail.hasPrefix(".") || trimmedEmail.hasSuffix(".") {
            emailValidation = FormValidationResult.invalid("Please check your email address for typos")
            return
        }
        
        emailValidation = FormValidationResult.valid("Email format is valid")
        
        // TODO: Add email availability check for sign up mode
        // This would require an email availability API endpoint
    }
    
    /// Validate password strength and requirements
    public func validatePassword() {
        passwordValidation = authStatePublisher.validatePassword(password)
    }
    
    /// Validate password confirmation matches
    public func validateConfirmPassword() {
        guard authMode == .signUp else {
            confirmPasswordValidation = .idle
            return
        }
        
        if confirmPassword.isEmpty {
            confirmPasswordValidation = FormValidationResult.idle
        } else if password != confirmPassword {
            confirmPasswordValidation = FormValidationResult.invalid("Passwords do not match")
        } else {
            confirmPasswordValidation = FormValidationResult.valid("Passwords match")
        }
    }
    
    /// Validate display name requirements
    public func validateDisplayName() {
        guard authMode == .signUp else {
            displayNameValidation = FormValidationResult.idle
            return
        }
        
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            displayNameValidation = FormValidationResult.idle // Optional field
        } else if trimmed.count < minDisplayNameLength {
            displayNameValidation = FormValidationResult.invalid("Name must be at least \(minDisplayNameLength) characters")
        } else if trimmed.count > maxDisplayNameLength {
            displayNameValidation = FormValidationResult.invalid("Name must be less than \(maxDisplayNameLength) characters")
        } else {
            displayNameValidation = FormValidationResult.valid("Name looks good")
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether the form can be submitted
    public var canSubmit: Bool {
        return isFormValid && !isLoading && networkStatusPublisher.isConnected
    }
    
    /// Current form validation message
    public var formValidationMessage: String? {
        if !networkStatusPublisher.isConnected {
            return "Internet connection required"
        }
        
        if submissionAttempts > 0 && !isFormValid {
            return "Please correct the errors above"
        }
        
        return nil
    }
    
    /// User-friendly authentication status
    public var statusMessage: String {
        if isLoading {
            switch authMode {
            case .signIn: return "Signing in..."
            case .signUp: return "Creating account..."
            }
        }
        
        if let error = lastError {
            return error.localizedDescription
        }
        
        if isAuthenticated {
            return "Successfully signed in"
        }
        
        return ""
    }
    
    /// Whether to show validation errors
    public var shouldShowValidationErrors: Bool {
        return submissionAttempts > 0
    }
    
    // MARK: - Private Implementation
    
    private func setupBindings() {
        // Bind AuthStatePublisher properties
        authStatePublisher.$currentUser
            .assign(to: \.currentUser, on: self)
            .store(in: &cancellables)
        
        authStatePublisher.$isAuthenticated
            .assign(to: \.isAuthenticated, on: self)
            .store(in: &cancellables)
        
        authStatePublisher.$isLoading
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        authStatePublisher.$authStatus
            .assign(to: \.authStatus, on: self)
            .store(in: &cancellables)
        
        authStatePublisher.$lastError
            .assign(to: \.lastError, on: self)
            .store(in: &cancellables)
    }
    
    private func setupValidation() {
        // Email validation
        $email
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.validateEmail()
                }
            }
            .store(in: &cancellables)
        
        // Password validation
        $password
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validatePassword()
                self?.validateConfirmPassword() // Re-validate confirmation when password changes
            }
            .store(in: &cancellables)
        
        // Confirm password validation
        $confirmPassword
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateConfirmPassword()
            }
            .store(in: &cancellables)
        
        // Display name validation
        $displayName
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateDisplayName()
            }
            .store(in: &cancellables)
        
        // Overall form validation
        Publishers.CombineLatest4(
            $emailValidation,
            $passwordValidation,
            $confirmPasswordValidation,
            $displayNameValidation
        )
        .map { [weak self] email, password, confirmPassword, displayName in
            guard let self = self else { return false }
            
            let emailValid = email == FormValidationResult.valid("Email format is valid") || (email.isValid && !email.message.isEmpty)
            let passwordValid = password.isValid
            
            if self.authMode == .signIn {
                return emailValid && passwordValid
            } else {
                let confirmValid = confirmPassword.isValid || confirmPassword == .idle
                let nameValid = displayName.isValid || displayName == .idle
                return emailValid && passwordValid && confirmValid && nameValid
            }
        }
        .assign(to: \.isFormValid, on: self)
        .store(in: &cancellables)
    }
    
    private func performAuthenticationOperation(_ operation: @escaping () async throws -> AuthenticationResult) async {
        submissionAttempts += 1
        
        guard canSubmit else { return }
        
        do {
            let result = try await operation()
            if result.success {
                // Success handling is managed by AuthStatePublisher
                clearForm()
            }
        } catch {
            // Error handling is managed by AuthStatePublisher
        }
    }
}

// MARK: - Supporting Types

/// Authentication mode for the form
public enum AuthMode: CaseIterable {
    case signIn
    case signUp
    
    public var title: String {
        switch self {
        case .signIn: return "Sign In"
        case .signUp: return "Sign Up"
        }
    }
    
    public var buttonTitle: String {
        switch self {
        case .signIn: return "Sign In"
        case .signUp: return "Create Account"
        }
    }
    
    public var alternateActionTitle: String {
        switch self {
        case .signIn: return "Don't have an account? Sign Up"
        case .signUp: return "Already have an account? Sign In"
        }
    }
}

/// Form field validation result
public enum FormValidationResult: Equatable {
    case idle
    case valid(String)
    case invalid(String)
    
    public var isValid: Bool {
        switch self {
        case .valid: return true
        default: return false
        }
    }
    
    public var message: String {
        switch self {
        case .idle: return ""
        case .valid(let message), .invalid(let message): return message
        }
    }
    
    public var color: Color {
        switch self {
        case .idle: return .primary
        case .valid: return .green
        case .invalid: return .red
        }
    }
    
    public var icon: String? {
        switch self {
        case .idle: return nil
        case .valid: return "checkmark.circle.fill"
        case .invalid: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - SwiftUI Convenience Extensions

public extension AuthenticationViewModel {
    
    /// Binding for email field with automatic formatting
    var emailBinding: Binding<String> {
        Binding(
            get: { self.email },
            set: { self.email = $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        )
    }
    
    /// Binding for display name with automatic formatting
    var displayNameBinding: Binding<String> {
        Binding(
            get: { self.displayName },
            set: { 
                // Capitalize first letter of each word
                let formatted = $0.capitalized
                self.displayName = formatted
            }
        )
    }
    
    /// Submit button configuration
    var submitButtonConfig: ButtonConfig {
        ButtonConfig(
            title: authMode.buttonTitle,
            isEnabled: canSubmit,
            isLoading: isLoading,
            style: .primary
        )
    }
    
    /// Alternate action button configuration
    var alternateButtonConfig: ButtonConfig {
        ButtonConfig(
            title: authMode.alternateActionTitle,
            isEnabled: !isLoading,
            isLoading: false,
            style: .secondary
        )
    }
}

/// Configuration for form buttons
public struct ButtonConfig {
    public let title: String
    public let isEnabled: Bool
    public let isLoading: Bool
    public let style: ButtonStyle
    
    public enum ButtonStyle {
        case primary
        case secondary
        case destructive
    }
}

/// Password validation extension
extension PasswordValidation {
    static let empty = PasswordValidation(isValid: false, strength: .weak, issues: [])
}