//
//  ConfigurationProvider.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Environment Types

/// Represents different deployment environments
public enum Environment {
    case development
    case staging
    case production
    case testing
    
    public var name: String {
        switch self {
        case .development: return "development"
        case .staging: return "staging"
        case .production: return "production"
        case .testing: return "testing"
        }
    }
}

/// Configuration for sync behavior
public struct SyncConfiguration {
    public let maxRetryAttempts: Int
    public let retryBackoffMultiplier: Double
    public let requestTimeoutInterval: TimeInterval
    public let batchSize: Int
    public let enableRealtime: Bool
    public let enableOfflineMode: Bool
    public let compressionEnabled: Bool
    
    public init(
        maxRetryAttempts: Int = 3,
        retryBackoffMultiplier: Double = 2.0,
        requestTimeoutInterval: TimeInterval = 30.0,
        batchSize: Int = 100,
        enableRealtime: Bool = true,
        enableOfflineMode: Bool = true,
        compressionEnabled: Bool = false
    ) {
        self.maxRetryAttempts = maxRetryAttempts
        self.retryBackoffMultiplier = retryBackoffMultiplier
        self.requestTimeoutInterval = requestTimeoutInterval
        self.batchSize = batchSize
        self.enableRealtime = enableRealtime
        self.enableOfflineMode = enableOfflineMode
        self.compressionEnabled = compressionEnabled
    }
}

/// Configuration for logging behavior
public struct LoggingConfiguration {
    public let logLevel: LogLevel
    public let enableFileLogging: Bool
    public let enableConsoleLogging: Bool
    public let enableOSLogging: Bool
    public let maxLogFileSize: Int
    public let logRetentionDays: Int
    
    public init(
        logLevel: LogLevel = .info,
        enableFileLogging: Bool = false,
        enableConsoleLogging: Bool = true,
        enableOSLogging: Bool = true,
        maxLogFileSize: Int = 10_000_000, // 10MB
        logRetentionDays: Int = 7
    ) {
        self.logLevel = logLevel
        self.enableFileLogging = enableFileLogging
        self.enableConsoleLogging = enableConsoleLogging
        self.enableOSLogging = enableOSLogging
        self.maxLogFileSize = maxLogFileSize
        self.logRetentionDays = logRetentionDays
    }
}

/// Log levels for filtering messages
public enum LogLevel: Int, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
    public var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

/// Configuration for security settings
public struct SecurityConfiguration {
    public let enableSSLPinning: Bool
    public let allowSelfSignedCertificates: Bool
    public let tokenExpirationThreshold: TimeInterval
    public let sessionTimeoutInterval: TimeInterval
    public let enableBiometricAuth: Bool
    
    public init(
        enableSSLPinning: Bool = false,
        allowSelfSignedCertificates: Bool = false,
        tokenExpirationThreshold: TimeInterval = 300, // 5 minutes
        sessionTimeoutInterval: TimeInterval = 3600, // 1 hour
        enableBiometricAuth: Bool = false
    ) {
        self.enableSSLPinning = enableSSLPinning
        self.allowSelfSignedCertificates = allowSelfSignedCertificates
        self.tokenExpirationThreshold = tokenExpirationThreshold
        self.sessionTimeoutInterval = sessionTimeoutInterval
        self.enableBiometricAuth = enableBiometricAuth
    }
}

/// Main application configuration
public struct AppConfiguration {
    public let environment: Environment
    public let supabaseURL: String
    public let supabaseAnonKey: String
    public let bundleIdentifier: String
    public let appVersion: String
    public let buildNumber: String
    public let syncConfiguration: SyncConfiguration
    public let loggingConfiguration: LoggingConfiguration
    public let securityConfiguration: SecurityConfiguration
    
    public init(
        environment: Environment,
        supabaseURL: String,
        supabaseAnonKey: String,
        bundleIdentifier: String? = nil,
        appVersion: String? = nil,
        buildNumber: String? = nil,
        syncConfiguration: SyncConfiguration = SyncConfiguration(),
        loggingConfiguration: LoggingConfiguration = LoggingConfiguration(),
        securityConfiguration: SecurityConfiguration = SecurityConfiguration()
    ) {
        self.environment = environment
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
        self.bundleIdentifier = bundleIdentifier ?? Bundle.main.bundleIdentifier ?? "com.unknown.app"
        self.appVersion = appVersion ?? Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.buildNumber = buildNumber ?? Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        self.syncConfiguration = syncConfiguration
        self.loggingConfiguration = loggingConfiguration
        self.securityConfiguration = securityConfiguration
    }
}

// MARK: - Configuration Provider

/// Provider for managing application configuration across different environments
/// Supports configuration from multiple sources: code, environment variables, plist files
public final class ConfigurationProvider {
    
    // MARK: - Properties
    
    /// Current application configuration
    private var currentConfiguration: AppConfiguration?
    
    /// Thread safety lock
    private let lock = NSLock()
    
    /// Optional logger for debugging configuration loading
    private var logger: SyncLoggerProtocol?
    
    // MARK: - Singleton
    
    /// Shared instance of the configuration provider
    public static let shared = ConfigurationProvider()
    
    // MARK: - Initialization
    
    private init() {}
    
    /// Configure the provider with a logger
    /// - Parameter logger: Logger for debugging configuration operations
    public func configure(logger: SyncLoggerProtocol?) {
        self.logger = logger
    }
    
    // MARK: - Configuration Loading
    
    /// Load configuration from multiple sources
    /// - Parameters:
    ///   - environment: Target environment
    ///   - supabaseURL: Supabase project URL
    ///   - supabaseAnonKey: Supabase anonymous key
    ///   - overrides: Optional configuration overrides
    /// - Returns: Loaded configuration
    public func loadConfiguration(
        environment: Environment,
        supabaseURL: String,
        supabaseAnonKey: String,
        overrides: ConfigurationOverrides? = nil
    ) -> AppConfiguration {
        lock.lock()
        defer { lock.unlock() }
        
        logger?.debug("ConfigurationProvider: Loading configuration for environment: \(environment.name)")
        
        // Start with base environment configuration
        var syncConfig = defaultSyncConfiguration(for: environment)
        var loggingConfig = defaultLoggingConfiguration(for: environment)
        var securityConfig = defaultSecurityConfiguration(for: environment)
        
        // Apply environment variables overrides
        applyEnvironmentVariables(
            syncConfiguration: &syncConfig,
            loggingConfiguration: &loggingConfig,
            securityConfiguration: &securityConfig
        )
        
        // Apply plist file overrides if available
        applyPlistConfiguration(
            environment: environment,
            syncConfiguration: &syncConfig,
            loggingConfiguration: &loggingConfig,
            securityConfiguration: &securityConfig
        )
        
        // Apply programmatic overrides
        if let overrides = overrides {
            applyOverrides(
                overrides,
                syncConfiguration: &syncConfig,
                loggingConfiguration: &loggingConfig,
                securityConfiguration: &securityConfig
            )
        }
        
        let configuration = AppConfiguration(
            environment: environment,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey,
            syncConfiguration: syncConfig,
            loggingConfiguration: loggingConfig,
            securityConfiguration: securityConfig
        )
        
        currentConfiguration = configuration
        logger?.info("ConfigurationProvider: Configuration loaded successfully for \(environment.name)")
        
        return configuration
    }
    
    /// Get the current configuration
    /// - Returns: Current configuration if loaded, nil otherwise
    public func getCurrentConfiguration() -> AppConfiguration? {
        lock.lock()
        defer { lock.unlock() }
        
        return currentConfiguration
    }
    
    /// Update the current configuration
    /// - Parameter configuration: New configuration to set
    public func updateConfiguration(_ configuration: AppConfiguration) {
        lock.lock()
        defer { lock.unlock() }
        
        currentConfiguration = configuration
        logger?.info("ConfigurationProvider: Configuration updated for \(configuration.environment.name)")
    }
    
    // MARK: - Environment-Specific Defaults
    
    private func defaultSyncConfiguration(for environment: Environment) -> SyncConfiguration {
        switch environment {
        case .development:
            return SyncConfiguration(
                maxRetryAttempts: 2,
                retryBackoffMultiplier: 1.5,
                requestTimeoutInterval: 60.0,
                batchSize: 50,
                enableRealtime: true,
                enableOfflineMode: true,
                compressionEnabled: false
            )
            
        case .staging:
            return SyncConfiguration(
                maxRetryAttempts: 3,
                retryBackoffMultiplier: 2.0,
                requestTimeoutInterval: 45.0,
                batchSize: 75,
                enableRealtime: true,
                enableOfflineMode: true,
                compressionEnabled: true
            )
            
        case .production:
            return SyncConfiguration(
                maxRetryAttempts: 5,
                retryBackoffMultiplier: 2.0,
                requestTimeoutInterval: 30.0,
                batchSize: 100,
                enableRealtime: true,
                enableOfflineMode: true,
                compressionEnabled: true
            )
            
        case .testing:
            return SyncConfiguration(
                maxRetryAttempts: 1,
                retryBackoffMultiplier: 1.0,
                requestTimeoutInterval: 10.0,
                batchSize: 10,
                enableRealtime: false,
                enableOfflineMode: false,
                compressionEnabled: false
            )
        }
    }
    
    private func defaultLoggingConfiguration(for environment: Environment) -> LoggingConfiguration {
        switch environment {
        case .development:
            return LoggingConfiguration(
                logLevel: .debug,
                enableFileLogging: true,
                enableConsoleLogging: true,
                enableOSLogging: true
            )
            
        case .staging:
            return LoggingConfiguration(
                logLevel: .info,
                enableFileLogging: true,
                enableConsoleLogging: true,
                enableOSLogging: true
            )
            
        case .production:
            return LoggingConfiguration(
                logLevel: .warning,
                enableFileLogging: false,
                enableConsoleLogging: false,
                enableOSLogging: true
            )
            
        case .testing:
            return LoggingConfiguration(
                logLevel: .error,
                enableFileLogging: false,
                enableConsoleLogging: false,
                enableOSLogging: false
            )
        }
    }
    
    private func defaultSecurityConfiguration(for environment: Environment) -> SecurityConfiguration {
        switch environment {
        case .development:
            return SecurityConfiguration(
                enableSSLPinning: false,
                allowSelfSignedCertificates: true,
                tokenExpirationThreshold: 600, // 10 minutes
                sessionTimeoutInterval: 7200, // 2 hours
                enableBiometricAuth: false
            )
            
        case .staging:
            return SecurityConfiguration(
                enableSSLPinning: false,
                allowSelfSignedCertificates: false,
                tokenExpirationThreshold: 300, // 5 minutes
                sessionTimeoutInterval: 3600, // 1 hour
                enableBiometricAuth: true
            )
            
        case .production:
            return SecurityConfiguration(
                enableSSLPinning: true,
                allowSelfSignedCertificates: false,
                tokenExpirationThreshold: 300, // 5 minutes
                sessionTimeoutInterval: 3600, // 1 hour
                enableBiometricAuth: true
            )
            
        case .testing:
            return SecurityConfiguration(
                enableSSLPinning: false,
                allowSelfSignedCertificates: true,
                tokenExpirationThreshold: 60, // 1 minute
                sessionTimeoutInterval: 600, // 10 minutes
                enableBiometricAuth: false
            )
        }
    }
    
    // MARK: - Configuration Sources
    
    private func applyEnvironmentVariables(
        syncConfiguration: inout SyncConfiguration,
        loggingConfiguration: inout LoggingConfiguration,
        securityConfiguration: inout SecurityConfiguration
    ) {
        let processInfo = ProcessInfo.processInfo
        
        // Sync configuration overrides
        if let maxRetryString = processInfo.environment["SYNC_MAX_RETRY_ATTEMPTS"],
           let maxRetry = Int(maxRetryString) {
            syncConfiguration = SyncConfiguration(
                maxRetryAttempts: maxRetry,
                retryBackoffMultiplier: syncConfiguration.retryBackoffMultiplier,
                requestTimeoutInterval: syncConfiguration.requestTimeoutInterval,
                batchSize: syncConfiguration.batchSize,
                enableRealtime: syncConfiguration.enableRealtime,
                enableOfflineMode: syncConfiguration.enableOfflineMode,
                compressionEnabled: syncConfiguration.compressionEnabled
            )
        }
        
        if let timeoutString = processInfo.environment["SYNC_REQUEST_TIMEOUT"],
           let timeout = TimeInterval(timeoutString) {
            syncConfiguration = SyncConfiguration(
                maxRetryAttempts: syncConfiguration.maxRetryAttempts,
                retryBackoffMultiplier: syncConfiguration.retryBackoffMultiplier,
                requestTimeoutInterval: timeout,
                batchSize: syncConfiguration.batchSize,
                enableRealtime: syncConfiguration.enableRealtime,
                enableOfflineMode: syncConfiguration.enableOfflineMode,
                compressionEnabled: syncConfiguration.compressionEnabled
            )
        }
        
        // Logging configuration overrides
        if let logLevelString = processInfo.environment["LOG_LEVEL"] {
            let logLevel: LogLevel
            switch logLevelString.uppercased() {
            case "DEBUG": logLevel = .debug
            case "INFO": logLevel = .info
            case "WARNING": logLevel = .warning
            case "ERROR": logLevel = .error
            default: logLevel = loggingConfiguration.logLevel
            }
            
            loggingConfiguration = LoggingConfiguration(
                logLevel: logLevel,
                enableFileLogging: loggingConfiguration.enableFileLogging,
                enableConsoleLogging: loggingConfiguration.enableConsoleLogging,
                enableOSLogging: loggingConfiguration.enableOSLogging,
                maxLogFileSize: loggingConfiguration.maxLogFileSize,
                logRetentionDays: loggingConfiguration.logRetentionDays
            )
        }
    }
    
    private func applyPlistConfiguration(
        environment: Environment,
        syncConfiguration: inout SyncConfiguration,
        loggingConfiguration: inout LoggingConfiguration,
        securityConfiguration: inout SecurityConfiguration
    ) {
        // Look for environment-specific plist files
        let plistName = "SwiftSupabaseSync-\(environment.name)"
        
        guard let path = Bundle.main.path(forResource: plistName, ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            logger?.debug("ConfigurationProvider: No plist file found for \(plistName)")
            return
        }
        
        logger?.debug("ConfigurationProvider: Loading configuration from \(plistName).plist")
        
        // Parse sync configuration from plist
        if let syncDict = plist["SyncConfiguration"] as? [String: Any] {
            syncConfiguration = SyncConfiguration(
                maxRetryAttempts: syncDict["maxRetryAttempts"] as? Int ?? syncConfiguration.maxRetryAttempts,
                retryBackoffMultiplier: syncDict["retryBackoffMultiplier"] as? Double ?? syncConfiguration.retryBackoffMultiplier,
                requestTimeoutInterval: syncDict["requestTimeoutInterval"] as? TimeInterval ?? syncConfiguration.requestTimeoutInterval,
                batchSize: syncDict["batchSize"] as? Int ?? syncConfiguration.batchSize,
                enableRealtime: syncDict["enableRealtime"] as? Bool ?? syncConfiguration.enableRealtime,
                enableOfflineMode: syncDict["enableOfflineMode"] as? Bool ?? syncConfiguration.enableOfflineMode,
                compressionEnabled: syncDict["compressionEnabled"] as? Bool ?? syncConfiguration.compressionEnabled
            )
        }
        
        // Parse logging configuration from plist
        if let loggingDict = plist["LoggingConfiguration"] as? [String: Any] {
            let logLevel: LogLevel
            if let logLevelString = loggingDict["logLevel"] as? String {
                switch logLevelString.uppercased() {
                case "DEBUG": logLevel = .debug
                case "INFO": logLevel = .info
                case "WARNING": logLevel = .warning
                case "ERROR": logLevel = .error
                default: logLevel = loggingConfiguration.logLevel
                }
            } else {
                logLevel = loggingConfiguration.logLevel
            }
            
            loggingConfiguration = LoggingConfiguration(
                logLevel: logLevel,
                enableFileLogging: loggingDict["enableFileLogging"] as? Bool ?? loggingConfiguration.enableFileLogging,
                enableConsoleLogging: loggingDict["enableConsoleLogging"] as? Bool ?? loggingConfiguration.enableConsoleLogging,
                enableOSLogging: loggingDict["enableOSLogging"] as? Bool ?? loggingConfiguration.enableOSLogging,
                maxLogFileSize: loggingDict["maxLogFileSize"] as? Int ?? loggingConfiguration.maxLogFileSize,
                logRetentionDays: loggingDict["logRetentionDays"] as? Int ?? loggingConfiguration.logRetentionDays
            )
        }
    }
    
    private func applyOverrides(
        _ overrides: ConfigurationOverrides,
        syncConfiguration: inout SyncConfiguration,
        loggingConfiguration: inout LoggingConfiguration,
        securityConfiguration: inout SecurityConfiguration
    ) {
        if let syncOverrides = overrides.syncConfiguration {
            syncConfiguration = syncOverrides
        }
        
        if let loggingOverrides = overrides.loggingConfiguration {
            loggingConfiguration = loggingOverrides
        }
        
        if let securityOverrides = overrides.securityConfiguration {
            securityConfiguration = securityOverrides
        }
    }
}

// MARK: - Configuration Overrides

/// Structure for providing configuration overrides
public struct ConfigurationOverrides {
    public let syncConfiguration: SyncConfiguration?
    public let loggingConfiguration: LoggingConfiguration?
    public let securityConfiguration: SecurityConfiguration?
    
    public init(
        syncConfiguration: SyncConfiguration? = nil,
        loggingConfiguration: LoggingConfiguration? = nil,
        securityConfiguration: SecurityConfiguration? = nil
    ) {
        self.syncConfiguration = syncConfiguration
        self.loggingConfiguration = loggingConfiguration
        self.securityConfiguration = securityConfiguration
    }
}