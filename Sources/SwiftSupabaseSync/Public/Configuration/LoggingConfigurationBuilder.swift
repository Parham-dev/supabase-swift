//
//  LoggingConfigurationBuilder.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation

/// Builder for configuring logging behavior with fluent API
public final class LoggingConfigurationBuilder {
    
    // MARK: - Configuration Properties
    
    private var logLevel: LogLevel = .info
    private var enableFileLogging: Bool = false
    private var enableConsoleLogging: Bool = true
    private var enableOSLogging: Bool = true
    private var maxLogFileSize: Int = 10_000_000 // 10MB
    private var logRetentionDays: Int = 7
    
    // MARK: - Initialization
    
    internal init() {}
    
    // MARK: - Log Level Configuration
    
    /// Set the minimum log level for filtering messages
    /// - Parameter level: Log level (.debug, .info, .warning, .error)
    /// - Returns: Self for method chaining
    @discardableResult
    public func logLevel(_ level: LogLevel) -> LoggingConfigurationBuilder {
        self.logLevel = level
        return self
    }
    
    // MARK: - Log Destination Configuration
    
    /// Enable or disable file logging
    /// - Parameter enabled: Whether to log to files
    /// - Returns: Self for method chaining
    @discardableResult
    public func enableFileLogging(_ enabled: Bool) -> LoggingConfigurationBuilder {
        self.enableFileLogging = enabled
        return self
    }
    
    /// Enable or disable console logging
    /// - Parameter enabled: Whether to log to console
    /// - Returns: Self for method chaining
    @discardableResult
    public func enableConsoleLogging(_ enabled: Bool) -> LoggingConfigurationBuilder {
        self.enableConsoleLogging = enabled
        return self
    }
    
    /// Enable or disable OS unified logging
    /// - Parameter enabled: Whether to use OS unified logging
    /// - Returns: Self for method chaining
    @discardableResult
    public func enableOSLogging(_ enabled: Bool) -> LoggingConfigurationBuilder {
        self.enableOSLogging = enabled
        return self
    }
    
    // MARK: - File Logging Configuration
    
    /// Set maximum log file size before rotation
    /// - Parameter size: Maximum file size in bytes (1MB - 100MB)
    /// - Returns: Self for method chaining
    @discardableResult
    public func maxLogFileSize(_ size: Int) -> LoggingConfigurationBuilder {
        self.maxLogFileSize = max(1_000_000, min(100_000_000, size))
        return self
    }
    
    /// Set maximum log file size using convenience units
    /// - Parameter megabytes: Maximum file size in megabytes (1-100)
    /// - Returns: Self for method chaining
    @discardableResult
    public func maxLogFileSize(megabytes: Int) -> LoggingConfigurationBuilder {
        let sizeInBytes = max(1, min(100, megabytes)) * 1_000_000
        return maxLogFileSize(sizeInBytes)
    }
    
    /// Set log retention period
    /// - Parameter days: Number of days to keep log files (1-365)
    /// - Returns: Self for method chaining
    @discardableResult
    public func logRetentionDays(_ days: Int) -> LoggingConfigurationBuilder {
        self.logRetentionDays = max(1, min(365, days))
        return self
    }
    
    // MARK: - Convenience Configuration Methods
    
    /// Configure for debug/development use
    /// - Returns: Self for method chaining
    @discardableResult
    public func debugConfiguration() -> LoggingConfigurationBuilder {
        return self
            .logLevel(.debug)
            .enableConsoleLogging(true)
            .enableFileLogging(true)
            .enableOSLogging(true)
            .maxLogFileSize(megabytes: 5)
            .logRetentionDays(3)
    }
    
    /// Configure for production use
    /// - Returns: Self for method chaining
    @discardableResult
    public func productionConfiguration() -> LoggingConfigurationBuilder {
        return self
            .logLevel(.error)
            .enableConsoleLogging(false)
            .enableFileLogging(false)
            .enableOSLogging(true)
            .maxLogFileSize(megabytes: 2)
            .logRetentionDays(1)
    }
    
    /// Configure for testing use
    /// - Returns: Self for method chaining
    @discardableResult
    public func testingConfiguration() -> LoggingConfigurationBuilder {
        return self
            .logLevel(.info)
            .enableConsoleLogging(true)
            .enableFileLogging(false)
            .enableOSLogging(false)
            .maxLogFileSize(megabytes: 1)
            .logRetentionDays(1)
    }
    
    /// Disable all logging
    /// - Returns: Self for method chaining
    @discardableResult
    public func disableAllLogging() -> LoggingConfigurationBuilder {
        return self
            .logLevel(.error)
            .enableConsoleLogging(false)
            .enableFileLogging(false)
            .enableOSLogging(false)
    }
    
    // MARK: - Internal Access for Validation
    
    internal var currentLogLevel: LogLevel {
        return self.logLevel
    }
    
    // MARK: - Validation
    
    /// Validate the current logging configuration
    /// - Returns: Validation result with any errors found
    internal func validate() -> LoggingConfigurationValidationResult {
        var errors: [ConfigurationValidationError] = []
        
        // Validate file size limits
        if maxLogFileSize < 1_000_000 || maxLogFileSize > 100_000_000 {
            errors.append(.invalidValue("maxLogFileSize", "Must be between 1MB and 100MB"))
        }
        
        // Validate retention period
        if logRetentionDays < 1 || logRetentionDays > 365 {
            errors.append(.invalidValue("logRetentionDays", "Must be between 1 and 365 days"))
        }
        
        // Validate that at least one logging destination is enabled
        if !enableFileLogging && !enableConsoleLogging && !enableOSLogging {
            errors.append(.configurationMismatch("At least one logging destination must be enabled"))
        }
        
        // Warning for file logging in production (not an error, but worth noting)
        if enableFileLogging && logLevel == .debug {
            // This might be worth a warning but not an error
        }
        
        return LoggingConfigurationValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Build
    
    /// Build the final LoggingConfiguration
    /// - Returns: Configured LoggingConfiguration
    internal func build() -> LoggingConfiguration {
        return LoggingConfiguration(
            logLevel: logLevel,
            enableFileLogging: enableFileLogging,
            enableConsoleLogging: enableConsoleLogging,
            enableOSLogging: enableOSLogging,
            maxLogFileSize: maxLogFileSize,
            logRetentionDays: logRetentionDays
        )
    }
}

/// Validation result for logging configuration
internal struct LoggingConfigurationValidationResult {
    let isValid: Bool
    let errors: [ConfigurationValidationError]
}
