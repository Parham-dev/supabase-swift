//
//  ConfigurationBuilder.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation

/// Public API for building SwiftSupabaseSync configuration using fluent builder pattern
/// Provides a clean, type-safe way to configure the SDK with validation and sensible defaults
public final class ConfigurationBuilder {
    
    // MARK: - Required Configuration
    
    private var supabaseURL: String?
    private var supabaseAnonKey: String?
    private var environment: Environment = .development
    
    // MARK: - Optional Configuration Builders
    
    private var syncConfigurationBuilder = SyncConfigurationBuilder()
    private var loggingConfigurationBuilder = LoggingConfigurationBuilder()
    private var securityConfigurationBuilder = SecurityConfigurationBuilder()
    
    // MARK: - App Metadata (Auto-detected)
    
    private var bundleIdentifier: String?
    private var appVersion: String?
    private var buildNumber: String?
    
    // MARK: - Validation State
    
    private var validationErrors: [ConfigurationValidationError] = []
    
    // MARK: - Initialization
    
    /// Create a new configuration builder
    public init() {}
    
    // MARK: - Required Configuration Methods
    
    /// Set the Supabase project URL
    /// - Parameter url: Your Supabase project URL (e.g., "https://your-project.supabase.co")
    /// - Returns: Self for method chaining
    @discardableResult
    public func supabaseURL(_ url: String) -> ConfigurationBuilder {
        self.supabaseURL = url
        return self
    }
    
    /// Set the Supabase anonymous key
    /// - Parameter key: Your Supabase anonymous/public key
    /// - Returns: Self for method chaining
    @discardableResult
    public func supabaseAnonKey(_ key: String) -> ConfigurationBuilder {
        self.supabaseAnonKey = key
        return self
    }
    
    /// Set the deployment environment
    /// - Parameter env: Target environment (.development, .staging, .production, .testing)
    /// - Returns: Self for method chaining
    @discardableResult
    public func environment(_ env: Environment) -> ConfigurationBuilder {
        self.environment = env
        return self
    }
    
    // MARK: - App Metadata Configuration
    
    /// Override the bundle identifier (auto-detected by default)
    /// - Parameter identifier: App bundle identifier
    /// - Returns: Self for method chaining
    @discardableResult
    public func bundleIdentifier(_ identifier: String) -> ConfigurationBuilder {
        self.bundleIdentifier = identifier
        return self
    }
    
    /// Override the app version (auto-detected by default)
    /// - Parameter version: App version string
    /// - Returns: Self for method chaining
    @discardableResult
    public func appVersion(_ version: String) -> ConfigurationBuilder {
        self.appVersion = version
        return self
    }
    
    /// Override the build number (auto-detected by default)
    /// - Parameter number: Build number string
    /// - Returns: Self for method chaining
    @discardableResult
    public func buildNumber(_ number: String) -> ConfigurationBuilder {
        self.buildNumber = number
        return self
    }
    
    // MARK: - Sync Configuration
    
    /// Configure sync behavior using a builder pattern
    /// - Parameter builder: Closure to configure sync settings
    /// - Returns: Self for method chaining
    @discardableResult
    public func sync(_ builder: (SyncConfigurationBuilder) -> Void) -> ConfigurationBuilder {
        builder(syncConfigurationBuilder)
        return self
    }
    
    /// Set sync policy using predefined policies
    /// - Parameter policy: Predefined sync policy (.conservative, .balanced, .aggressive, .manual, .realtime)
    /// - Returns: Self for method chaining
    @discardableResult
    public func syncPolicy(_ policy: SyncPolicy) -> ConfigurationBuilder {
        syncConfigurationBuilder.applyPolicy(policy)
        return self
    }
    
    /// Quick configuration for common sync scenarios
    /// - Parameter preset: Sync preset configuration
    /// - Returns: Self for method chaining
    @discardableResult
    public func syncPreset(_ preset: SyncPreset) -> ConfigurationBuilder {
        switch preset {
        case .offlineFirst:
            syncConfigurationBuilder
                .enableOfflineMode(true)
                .enableRealtime(false)
                .maxRetryAttempts(5)
                .batchSize(50)
        case .realtimeFirst:
            syncConfigurationBuilder
                .enableRealtime(true)
                .enableOfflineMode(true)
                .maxRetryAttempts(3)
                .batchSize(100)
        case .batteryOptimized:
            syncConfigurationBuilder
                .enableOfflineMode(true)
                .compressionEnabled(true)
                .batchSize(25)
                .maxRetryAttempts(2)
        case .performanceOptimized:
            syncConfigurationBuilder
                .batchSize(200)
                .compressionEnabled(true)
                .maxRetryAttempts(5)
                .requestTimeoutInterval(60.0)
        }
        return self
    }
    
    // MARK: - Logging Configuration
    
    /// Configure logging behavior using a builder pattern
    /// - Parameter builder: Closure to configure logging settings
    /// - Returns: Self for method chaining
    @discardableResult
    public func logging(_ builder: (LoggingConfigurationBuilder) -> Void) -> ConfigurationBuilder {
        builder(loggingConfigurationBuilder)
        return self
    }
    
    /// Quick logging configuration for common scenarios
    /// - Parameter preset: Logging preset configuration
    /// - Returns: Self for method chaining
    @discardableResult
    public func loggingPreset(_ preset: LoggingPreset) -> ConfigurationBuilder {
        switch preset {
        case .debug:
            loggingConfigurationBuilder
                .logLevel(.debug)
                .enableConsoleLogging(true)
                .enableFileLogging(true)
                .enableOSLogging(true)
        case .production:
            loggingConfigurationBuilder
                .logLevel(.error)
                .enableConsoleLogging(false)
                .enableFileLogging(false)
                .enableOSLogging(true)
        case .testing:
            loggingConfigurationBuilder
                .logLevel(.info)
                .enableConsoleLogging(true)
                .enableFileLogging(false)
                .enableOSLogging(false)
        case .minimal:
            loggingConfigurationBuilder
                .logLevel(.error)
                .enableConsoleLogging(false)
                .enableFileLogging(false)
                .enableOSLogging(false)
        }
        return self
    }
    
    // MARK: - Security Configuration
    
    /// Configure security settings using a builder pattern
    /// - Parameter builder: Closure to configure security settings
    /// - Returns: Self for method chaining
    @discardableResult
    public func security(_ builder: (SecurityConfigurationBuilder) -> Void) -> ConfigurationBuilder {
        builder(securityConfigurationBuilder)
        return self
    }
    
    /// Quick security configuration for common scenarios
    /// - Parameter preset: Security preset configuration
    /// - Returns: Self for method chaining
    @discardableResult
    public func securityPreset(_ preset: SecurityPreset) -> ConfigurationBuilder {
        switch preset {
        case .standard:
            securityConfigurationBuilder
                .enableSSLPinning(false)
                .allowSelfSignedCertificates(false)
                .enableBiometricAuth(false)
                .tokenExpirationThreshold(300) // 5 minutes
        case .enhanced:
            securityConfigurationBuilder
                .enableSSLPinning(true)
                .allowSelfSignedCertificates(false)
                .enableBiometricAuth(true)
                .tokenExpirationThreshold(180) // 3 minutes
        case .development:
            securityConfigurationBuilder
                .enableSSLPinning(false)
                .allowSelfSignedCertificates(true)
                .enableBiometricAuth(false)
                .tokenExpirationThreshold(600) // 10 minutes
        case .maximum:
            securityConfigurationBuilder
                .enableSSLPinning(true)
                .allowSelfSignedCertificates(false)
                .enableBiometricAuth(true)
                .tokenExpirationThreshold(120) // 2 minutes
                .sessionTimeoutInterval(1800) // 30 minutes
        }
        return self
    }
    
    // MARK: - Validation
    
    /// Validate the current configuration
    /// - Returns: Validation result with any errors found
    public func validate() -> ConfigurationValidationResult {
        validationErrors.removeAll()
        
        // Validate required fields
        validateRequiredFields()
        
        // Validate URLs and keys
        validateSupabaseConfiguration()
        
        // Validate sub-configurations
        validateSyncConfiguration()
        validateLoggingConfiguration()
        validateSecurityConfiguration()
        
        // Validate cross-configuration dependencies
        validateConfigurationDependencies()
        
        return ConfigurationValidationResult(
            isValid: validationErrors.isEmpty,
            errors: validationErrors
        )
    }
    
    // MARK: - Build Configuration
    
    /// Build the final AppConfiguration
    /// - Throws: ConfigurationValidationError if validation fails
    /// - Returns: Validated AppConfiguration ready for use
    public func build() throws -> AppConfiguration {
        let validationResult = validate()
        
        guard validationResult.isValid else {
            throw ConfigurationValidationError.validationFailed(validationResult.errors)
        }
        
        return AppConfiguration(
            environment: environment,
            supabaseURL: supabaseURL!,
            supabaseAnonKey: supabaseAnonKey!,
            bundleIdentifier: bundleIdentifier,
            appVersion: appVersion,
            buildNumber: buildNumber,
            syncConfiguration: syncConfigurationBuilder.build(),
            loggingConfiguration: loggingConfigurationBuilder.build(),
            securityConfiguration: securityConfigurationBuilder.build()
        )
    }
    
    /// Build configuration with automatic validation and helpful error messages
    /// - Returns: Result containing either valid configuration or detailed error information
    public func buildSafely() -> Result<AppConfiguration, ConfigurationBuildError> {
        do {
            let config = try build()
            return .success(config)
        } catch {
            if let validationError = error as? ConfigurationValidationError {
                return .failure(.validationFailed(validationError))
            } else {
                return .failure(.buildFailed(error))
            }
        }
    }
    
    // MARK: - Quick Build Methods
    
    /// Quick build for development with minimal required configuration
    /// - Parameters:
    ///   - url: Supabase project URL
    ///   - key: Supabase anonymous key
    /// - Returns: Development-optimized configuration
    /// - Throws: ConfigurationValidationError if validation fails
    public static func development(url: String, key: String) throws -> AppConfiguration {
        return try ConfigurationBuilder()
            .supabaseURL(url)
            .supabaseAnonKey(key)
            .environment(.development)
            .syncPreset(.offlineFirst)
            .loggingPreset(.debug)
            .securityPreset(.development)
            .build()
    }
    
    /// Quick build for production with security-focused configuration
    /// - Parameters:
    ///   - url: Supabase project URL
    ///   - key: Supabase anonymous key
    /// - Returns: Production-optimized configuration
    /// - Throws: ConfigurationValidationError if validation fails
    public static func production(url: String, key: String) throws -> AppConfiguration {
        return try ConfigurationBuilder()
            .supabaseURL(url)
            .supabaseAnonKey(key)
            .environment(.production)
            .syncPreset(.performanceOptimized)
            .loggingPreset(.production)
            .securityPreset(.enhanced)
            .build()
    }
    
    /// Quick build for testing with minimal logging and fast sync
    /// - Parameters:
    ///   - url: Supabase project URL
    ///   - key: Supabase anonymous key
    /// - Returns: Testing-optimized configuration
    /// - Throws: ConfigurationValidationError if validation fails
    public static func testing(url: String, key: String) throws -> AppConfiguration {
        return try ConfigurationBuilder()
            .supabaseURL(url)
            .supabaseAnonKey(key)
            .environment(.testing)
            .syncPreset(.performanceOptimized)
            .loggingPreset(.testing)
            .securityPreset(.standard)
            .build()
    }
}

// MARK: - Private Validation Methods

private extension ConfigurationBuilder {
    
    func validateRequiredFields() {
        if supabaseURL == nil || supabaseURL?.isEmpty == true {
            validationErrors.append(.missingRequiredField("supabaseURL", "Supabase project URL is required"))
        }
        
        if supabaseAnonKey == nil || supabaseAnonKey?.isEmpty == true {
            validationErrors.append(.missingRequiredField("supabaseAnonKey", "Supabase anonymous key is required"))
        }
    }
    
    func validateSupabaseConfiguration() {
        // Validate Supabase URL format
        if let url = supabaseURL, !url.isEmpty {
            guard let urlComponents = URLComponents(string: url),
                  urlComponents.scheme != nil,
                  urlComponents.host != nil else {
                validationErrors.append(.invalidValue("supabaseURL", "Invalid URL format. Expected format: https://your-project.supabase.co"))
                return
            }
            
            // Check if it looks like a Supabase URL
            if !url.contains("supabase.co") && !url.contains("localhost") {
                validationErrors.append(.invalidValue("supabaseURL", "URL should be a Supabase project URL or localhost for development"))
            }
        }
        
        // Validate anonymous key format (basic length check)
        if let key = supabaseAnonKey, !key.isEmpty {
            if key.count < 20 {
                validationErrors.append(.invalidValue("supabaseAnonKey", "Anonymous key appears to be too short"))
            }
        }
    }
    
    func validateSyncConfiguration() {
        let syncValidation = syncConfigurationBuilder.validate()
        validationErrors.append(contentsOf: syncValidation.errors)
    }
    
    func validateLoggingConfiguration() {
        let loggingValidation = loggingConfigurationBuilder.validate()
        validationErrors.append(contentsOf: loggingValidation.errors)
    }
    
    func validateSecurityConfiguration() {
        let securityValidation = securityConfigurationBuilder.validate()
        validationErrors.append(contentsOf: securityValidation.errors)
    }
    
    func validateConfigurationDependencies() {
        // Validate environment-specific constraints
        switch environment {
        case .production:
            // Production should use secure settings
            if securityConfigurationBuilder.allowsSelfSignedCertificates == true {
                validationErrors.append(.configurationMismatch("Production environment should not allow self-signed certificates"))
            }
            
            if loggingConfigurationBuilder.currentLogLevel == LogLevel.debug {
                validationErrors.append(.configurationMismatch("Production environment should not use debug logging"))
            }
            
        case .development:
            // Development warnings (not errors)
            if securityConfigurationBuilder.sslPinningEnabled == true {
                // This is just a note, not an error
            }
            
        case .testing:
            // Testing should have reliable settings
            if syncConfigurationBuilder.currentMaxRetryAttempts > 2 {
                validationErrors.append(.configurationMismatch("Testing environment should use minimal retry attempts for faster tests"))
            }
            
        case .staging:
            // Staging should be close to production
            break
        }
    }
}

// MARK: - Supporting Types

/// Predefined sync configuration presets
public enum SyncPreset {
    case offlineFirst      // Optimized for offline-first apps
    case realtimeFirst     // Optimized for real-time collaboration
    case batteryOptimized  // Minimal battery usage
    case performanceOptimized // Maximum sync performance
}

/// Predefined logging configuration presets
public enum LoggingPreset {
    case debug        // Verbose logging for development
    case production   // Minimal logging for production
    case testing      // Balanced logging for testing
    case minimal      // No logging
}

/// Predefined security configuration presets
public enum SecurityPreset {
    case standard     // Standard security settings
    case enhanced     // Enhanced security with biometrics
    case development  // Development-friendly settings
    case maximum      // Maximum security settings
}

/// Configuration validation result
public struct ConfigurationValidationResult {
    public let isValid: Bool
    public let errors: [ConfigurationValidationError]
    
    /// Human-readable summary of validation issues
    public var errorSummary: String? {
        guard !errors.isEmpty else { return nil }
        return errors.map { $0.localizedDescription }.joined(separator: "\n")
    }
}

/// Configuration validation errors
public enum ConfigurationValidationError: Error, LocalizedError {
    case missingRequiredField(String, String)
    case invalidValue(String, String)
    case configurationMismatch(String)
    case validationFailed([ConfigurationValidationError])
    
    public var errorDescription: String? {
        switch self {
        case .missingRequiredField(let field, let message):
            return "Missing required field '\(field)': \(message)"
        case .invalidValue(let field, let message):
            return "Invalid value for '\(field)': \(message)"
        case .configurationMismatch(let message):
            return "Configuration mismatch: \(message)"
        case .validationFailed(let errors):
            return "Validation failed with \(errors.count) error(s)"
        }
    }
    
    /// Provides actionable suggestions for fixing the error
    public var recoverySuggestion: String? {
        switch self {
        case .missingRequiredField(let field, _):
            switch field {
            case "supabaseURL":
                return "Set your Supabase project URL using .supabaseURL(\"https://your-project.supabase.co\")"
            case "supabaseAnonKey":
                return "Set your Supabase anonymous key using .supabaseAnonKey(\"your-anon-key\")"
            default:
                return "Provide a value for the required field '\(field)'"
            }
        case .invalidValue(let field, _):
            switch field {
            case "supabaseURL":
                return "Use a valid URL format like https://your-project.supabase.co"
            case "supabaseAnonKey":
                return "Use the anonymous/public key from your Supabase project settings"
            default:
                return "Check the value format for '\(field)'"
            }
        case .configurationMismatch:
            return "Adjust your configuration to match the recommended settings for your environment"
        case .validationFailed:
            return "Fix the validation errors listed above"
        }
    }
}

/// Configuration build errors
public enum ConfigurationBuildError: Error, LocalizedError {
    case validationFailed(ConfigurationValidationError)
    case buildFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let validationError):
            return "Configuration validation failed: \(validationError.localizedDescription)"
        case .buildFailed(let error):
            return "Configuration build failed: \(error.localizedDescription)"
        }
    }
}
