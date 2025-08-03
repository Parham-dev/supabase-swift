//
//  SyncConfigurationBuilder.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation

/// Builder for configuring sync behavior with fluent API
public final class SyncConfigurationBuilder {
    
    // MARK: - Configuration Properties
    
    private var maxRetryAttempts: Int = 3
    private var retryBackoffMultiplier: Double = 2.0
    private var requestTimeoutInterval: TimeInterval = 30.0
    private var batchSize: Int = 100
    private var enableRealtime: Bool = true
    private var enableOfflineMode: Bool = true
    private var compressionEnabled: Bool = false
    
    // MARK: - Initialization
    
    internal init() {}
    
    // MARK: - Retry Configuration
    
    /// Set maximum number of retry attempts for failed sync operations
    /// - Parameter attempts: Number of retry attempts (1-10)
    /// - Returns: Self for method chaining
    @discardableResult
    public func maxRetryAttempts(_ attempts: Int) -> SyncConfigurationBuilder {
        self.maxRetryAttempts = max(1, min(10, attempts))
        return self
    }
    
    /// Set the backoff multiplier for retry delays
    /// - Parameter multiplier: Backoff multiplier (1.0-5.0)
    /// - Returns: Self for method chaining
    @discardableResult
    public func retryBackoffMultiplier(_ multiplier: Double) -> SyncConfigurationBuilder {
        self.retryBackoffMultiplier = max(1.0, min(5.0, multiplier))
        return self
    }
    
    /// Set request timeout interval
    /// - Parameter interval: Timeout interval in seconds (5-300)
    /// - Returns: Self for method chaining
    @discardableResult
    public func requestTimeoutInterval(_ interval: TimeInterval) -> SyncConfigurationBuilder {
        self.requestTimeoutInterval = max(5.0, min(300.0, interval))
        return self
    }
    
    // MARK: - Batch Configuration
    
    /// Set batch size for sync operations
    /// - Parameter size: Number of items per batch (1-1000)
    /// - Returns: Self for method chaining
    @discardableResult
    public func batchSize(_ size: Int) -> SyncConfigurationBuilder {
        self.batchSize = max(1, min(1000, size))
        return self
    }
    
    // MARK: - Feature Configuration
    
    /// Enable or disable real-time synchronization
    /// - Parameter enabled: Whether real-time sync is enabled
    /// - Returns: Self for method chaining
    @discardableResult
    public func enableRealtime(_ enabled: Bool) -> SyncConfigurationBuilder {
        self.enableRealtime = enabled
        return self
    }
    
    /// Enable or disable offline mode
    /// - Parameter enabled: Whether offline mode is enabled
    /// - Returns: Self for method chaining
    @discardableResult
    public func enableOfflineMode(_ enabled: Bool) -> SyncConfigurationBuilder {
        self.enableOfflineMode = enabled
        return self
    }
    
    /// Enable or disable compression for sync data
    /// - Parameter enabled: Whether compression is enabled
    /// - Returns: Self for method chaining
    @discardableResult
    public func compressionEnabled(_ enabled: Bool) -> SyncConfigurationBuilder {
        self.compressionEnabled = enabled
        return self
    }
    
    // MARK: - Policy Application
    
    /// Apply settings from a predefined sync policy
    /// - Parameter policy: Sync policy to apply
    /// - Returns: Self for method chaining
    @discardableResult
    internal func applyPolicy(_ policy: SyncPolicy) -> SyncConfigurationBuilder {
        self.maxRetryAttempts = policy.maxRetries
        self.batchSize = policy.batchSize
        self.enableRealtime = policy.enableRealtimeSync
        // Note: SyncPolicy has more settings that don't map directly to SyncConfiguration
        // This is intentional - SyncConfiguration is more basic, SyncPolicy is domain-rich
        return self
    }
    
    // MARK: - Internal Access for Validation
    
    internal var currentMaxRetryAttempts: Int {
        return self.maxRetryAttempts
    }
    
    // MARK: - Validation
    
    /// Validate the current sync configuration
    /// - Returns: Validation result with any errors found
    internal func validate() -> SyncConfigurationValidationResult {
        var errors: [ConfigurationValidationError] = []
        
        // Validate retry configuration
        if maxRetryAttempts < 1 || maxRetryAttempts > 10 {
            errors.append(.invalidValue("maxRetryAttempts", "Must be between 1 and 10"))
        }
        
        if retryBackoffMultiplier < 1.0 || retryBackoffMultiplier > 5.0 {
            errors.append(.invalidValue("retryBackoffMultiplier", "Must be between 1.0 and 5.0"))
        }
        
        if requestTimeoutInterval < 5.0 || requestTimeoutInterval > 300.0 {
            errors.append(.invalidValue("requestTimeoutInterval", "Must be between 5 and 300 seconds"))
        }
        
        // Validate batch configuration
        if batchSize < 1 || batchSize > 1000 {
            errors.append(.invalidValue("batchSize", "Must be between 1 and 1000"))
        }
        
        // Validate feature combinations
        if !enableOfflineMode && !enableRealtime {
            errors.append(.configurationMismatch("Either offline mode or real-time sync must be enabled"))
        }
        
        return SyncConfigurationValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Build
    
    /// Build the final SyncConfiguration
    /// - Returns: Configured SyncConfiguration
    internal func build() -> SyncConfiguration {
        return SyncConfiguration(
            maxRetryAttempts: maxRetryAttempts,
            retryBackoffMultiplier: retryBackoffMultiplier,
            requestTimeoutInterval: requestTimeoutInterval,
            batchSize: batchSize,
            enableRealtime: enableRealtime,
            enableOfflineMode: enableOfflineMode,
            compressionEnabled: compressionEnabled
        )
    }
}

/// Validation result for sync configuration
internal struct SyncConfigurationValidationResult {
    let isValid: Bool
    let errors: [ConfigurationValidationError]
}
