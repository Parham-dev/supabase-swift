//
//  SecurityConfigurationBuilder.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation

/// Builder for configuring security settings with fluent API
public final class SecurityConfigurationBuilder {
    
    // MARK: - Configuration Properties
    
    private var enableSSLPinning: Bool = false
    private var allowSelfSignedCertificates: Bool = false
    private var tokenExpirationThreshold: TimeInterval = 300 // 5 minutes
    private var sessionTimeoutInterval: TimeInterval = 3600 // 1 hour
    private var enableBiometricAuth: Bool = false
    
    // MARK: - Initialization
    
    internal init() {}
    
    // MARK: - SSL Configuration
    
    /// Enable or disable SSL certificate pinning
    /// - Parameter enabled: Whether to enable SSL pinning
    /// - Returns: Self for method chaining
    @discardableResult
    public func enableSSLPinning(_ enabled: Bool) -> SecurityConfigurationBuilder {
        self.enableSSLPinning = enabled
        return self
    }
    
    /// Allow or disallow self-signed certificates (development only)
    /// - Parameter allowed: Whether to allow self-signed certificates
    /// - Returns: Self for method chaining
    @discardableResult
    public func allowSelfSignedCertificates(_ allowed: Bool) -> SecurityConfigurationBuilder {
        self.allowSelfSignedCertificates = allowed
        return self
    }
    
    // MARK: - Session Configuration
    
    /// Set token expiration threshold for auto-refresh
    /// - Parameter threshold: Time in seconds before expiration to trigger refresh (60-1800)
    /// - Returns: Self for method chaining
    @discardableResult
    public func tokenExpirationThreshold(_ threshold: TimeInterval) -> SecurityConfigurationBuilder {
        self.tokenExpirationThreshold = max(60.0, min(1800.0, threshold))
        return self
    }
    
    /// Set token expiration threshold using convenience units
    /// - Parameter minutes: Time in minutes before expiration to trigger refresh (1-30)
    /// - Returns: Self for method chaining
    @discardableResult
    public func tokenExpirationThreshold(minutes: Int) -> SecurityConfigurationBuilder {
        let thresholdInSeconds = max(1, min(30, minutes)) * 60
        return tokenExpirationThreshold(TimeInterval(thresholdInSeconds))
    }
    
    /// Set session timeout interval
    /// - Parameter interval: Maximum session duration in seconds (300-86400)
    /// - Returns: Self for method chaining
    @discardableResult
    public func sessionTimeoutInterval(_ interval: TimeInterval) -> SecurityConfigurationBuilder {
        self.sessionTimeoutInterval = max(300.0, min(86400.0, interval))
        return self
    }
    
    /// Set session timeout using convenience units
    /// - Parameter hours: Maximum session duration in hours (1-24)
    /// - Returns: Self for method chaining
    @discardableResult
    public func sessionTimeoutInterval(hours: Int) -> SecurityConfigurationBuilder {
        let intervalInSeconds = max(1, min(24, hours)) * 3600
        return sessionTimeoutInterval(TimeInterval(intervalInSeconds))
    }
    
    // MARK: - Authentication Configuration
    
    /// Enable or disable biometric authentication
    /// - Parameter enabled: Whether to enable biometric authentication
    /// - Returns: Self for method chaining
    @discardableResult
    public func enableBiometricAuth(_ enabled: Bool) -> SecurityConfigurationBuilder {
        self.enableBiometricAuth = enabled
        return self
    }
    
    // MARK: - Convenience Configuration Methods
    
    /// Configure for development use (relaxed security)
    /// - Returns: Self for method chaining
    @discardableResult
    public func developmentConfiguration() -> SecurityConfigurationBuilder {
        return self
            .enableSSLPinning(false)
            .allowSelfSignedCertificates(true)
            .tokenExpirationThreshold(minutes: 10)
            .sessionTimeoutInterval(hours: 8)
            .enableBiometricAuth(false)
    }
    
    /// Configure for production use (enhanced security)
    /// - Returns: Self for method chaining
    @discardableResult
    public func productionConfiguration() -> SecurityConfigurationBuilder {
        return self
            .enableSSLPinning(true)
            .allowSelfSignedCertificates(false)
            .tokenExpirationThreshold(minutes: 5)
            .sessionTimeoutInterval(hours: 1)
            .enableBiometricAuth(true)
    }
    
    /// Configure for testing use (balanced security)
    /// - Returns: Self for method chaining
    @discardableResult
    public func testingConfiguration() -> SecurityConfigurationBuilder {
        return self
            .enableSSLPinning(false)
            .allowSelfSignedCertificates(false)
            .tokenExpirationThreshold(minutes: 10)
            .sessionTimeoutInterval(hours: 2)
            .enableBiometricAuth(false)
    }
    
    /// Configure for maximum security
    /// - Returns: Self for method chaining
    @discardableResult
    public func maximumSecurityConfiguration() -> SecurityConfigurationBuilder {
        return self
            .enableSSLPinning(true)
            .allowSelfSignedCertificates(false)
            .tokenExpirationThreshold(minutes: 2)
            .sessionTimeoutInterval(TimeInterval(30 * 60)) // 30 minutes
            .enableBiometricAuth(true)
    }
    
    // MARK: - Internal Access for Validation
    
    internal var allowsSelfSignedCertificates: Bool {
        return self.allowSelfSignedCertificates
    }
    
    internal var sslPinningEnabled: Bool {
        return self.enableSSLPinning
    }
    
    // MARK: - Validation
    
    /// Validate the current security configuration
    /// - Returns: Validation result with any errors found
    internal func validate() -> SecurityConfigurationValidationResult {
        var errors: [ConfigurationValidationError] = []
        
        // Validate token expiration threshold
        if tokenExpirationThreshold < 60.0 || tokenExpirationThreshold > 1800.0 {
            errors.append(.invalidValue("tokenExpirationThreshold", "Must be between 60 and 1800 seconds (1-30 minutes)"))
        }
        
        // Validate session timeout
        if sessionTimeoutInterval < 300.0 || sessionTimeoutInterval > 86400.0 {
            errors.append(.invalidValue("sessionTimeoutInterval", "Must be between 300 and 86400 seconds (5 minutes to 24 hours)"))
        }
        
        // Validate logical constraints
        if tokenExpirationThreshold >= sessionTimeoutInterval {
            errors.append(.configurationMismatch("Token expiration threshold must be less than session timeout interval"))
        }
        
        // Security best practice warnings (not errors, but worth validating)
        if allowSelfSignedCertificates && enableSSLPinning {
            errors.append(.configurationMismatch("SSL pinning is ineffective when self-signed certificates are allowed"))
        }
        
        return SecurityConfigurationValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Build
    
    /// Build the final SecurityConfiguration
    /// - Returns: Configured SecurityConfiguration
    internal func build() -> SecurityConfiguration {
        return SecurityConfiguration(
            enableSSLPinning: enableSSLPinning,
            allowSelfSignedCertificates: allowSelfSignedCertificates,
            tokenExpirationThreshold: tokenExpirationThreshold,
            sessionTimeoutInterval: sessionTimeoutInterval,
            enableBiometricAuth: enableBiometricAuth
        )
    }
}

/// Validation result for security configuration
internal struct SecurityConfigurationValidationResult {
    let isValid: Bool
    let errors: [ConfigurationValidationError]
}
