//
//  DependencyInjectionSetup.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Main class for setting up dependency injection container with all services
/// Provides convenient methods to configure the entire application dependency graph
public final class DependencyInjectionSetup {
    
    // MARK: - Properties
    
    private let container: DIContainer
    private let factory: RepositoryFactory
    private let configurationProvider: ConfigurationProvider
    private var isConfigured = false
    
    // MARK: - Initialization
    
    public init() {
        let logger = LoggingService() // Create logger first
        self.container = DIContainer(logger: logger)
        self.factory = RepositoryFactory(container: container, logger: logger)
        self.configurationProvider = ConfigurationProvider.shared
        
        // Register the logger as a singleton
        container.registerSingleton(SyncLoggerProtocol.self, instance: logger)
    }
    
    // MARK: - Main Setup Methods
    
    /// Configure the entire dependency injection system
    /// - Parameters:
    ///   - configuration: Application configuration
    ///   - customRegistrations: Optional custom service registrations
    /// - Throws: DIError if configuration fails
    public func configure(
        with configuration: AppConfiguration,
        customRegistrations: ((DIContainer) -> Void)? = nil
    ) throws {
        guard !isConfigured else {
            return // Already configured
        }
        
        // Update configuration provider
        configurationProvider.updateConfiguration(configuration)
        
        // Register configuration
        container.registerSingleton(AppConfiguration.self, instance: configuration)
        
        // Register core infrastructure services
        try registerInfrastructureServices(with: configuration)
        
        // Register data sources
        try factory.registerAllDataSources()
        
        // Register repositories
        try factory.registerAllRepositories()
        
        // Register use cases
        try factory.registerAllUseCases()
        
        // Apply custom registrations
        customRegistrations?(container)
        
        // Configure service locator
        ServiceLocator.shared.configure(with: container)
        
        isConfigured = true
        
        if let logger = container.resolveOptional(SyncLoggerProtocol.self) {
            logger.info("DependencyInjectionSetup: Dependency injection configured successfully")
        }
    }
    
    /// Quick setup with minimal configuration for development
    /// - Parameters:
    ///   - supabaseURL: Supabase project URL
    ///   - supabaseAnonKey: Supabase anonymous key
    ///   - environment: Target environment (default: development)
    /// - Throws: DIError if setup fails
    public func quickSetup(
        supabaseURL: String,
        supabaseAnonKey: String,
        environment: Environment = .development
    ) throws {
        let configuration = configurationProvider.loadConfiguration(
            environment: environment,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey
        )
        
        try configure(with: configuration)
    }
    
    /// Advanced setup with custom configuration overrides
    /// - Parameters:
    ///   - supabaseURL: Supabase project URL
    ///   - supabaseAnonKey: Supabase anonymous key
    ///   - environment: Target environment
    ///   - overrides: Configuration overrides
    ///   - customRegistrations: Custom service registrations
    /// - Throws: DIError if setup fails
    public func advancedSetup(
        supabaseURL: String,
        supabaseAnonKey: String,
        environment: Environment,
        overrides: ConfigurationOverrides? = nil,
        customRegistrations: ((DIContainer) -> Void)? = nil
    ) throws {
        let configuration = configurationProvider.loadConfiguration(
            environment: environment,
            supabaseURL: supabaseURL,
            supabaseAnonKey: supabaseAnonKey,
            overrides: overrides
        )
        
        try configure(with: configuration, customRegistrations: customRegistrations)
    }
    
    // MARK: - Infrastructure Service Registration
    
    private func registerInfrastructureServices(with configuration: AppConfiguration) throws {
        // Register network configuration
        guard let supabaseURL = URL(string: configuration.supabaseURL) else {
            throw DIError.instantiationFailed("NetworkConfiguration", 
                NSError(domain: "Invalid Supabase URL", code: 1, userInfo: nil))
        }
        
        let networkConfig = NetworkConfiguration(
            supabaseURL: supabaseURL,
            supabaseKey: configuration.supabaseAnonKey,
            requestTimeout: configuration.syncConfiguration.requestTimeoutInterval,
            maxRetryAttempts: configuration.syncConfiguration.maxRetryAttempts,
            enableLogging: configuration.loggingConfiguration.enableConsoleLogging
        )
        container.registerSingleton(NetworkConfiguration.self, instance: networkConfig)
        
        // Register network monitor
        container.register(NetworkMonitor.self, lifetime: .singleton) { _ in
            NetworkMonitor()
        }
        
        // Register request builder
        container.register(RequestBuilder.self, lifetime: .singleton) { container in
            let config = try container.resolve(NetworkConfiguration.self)
            return RequestBuilder(baseURL: config.supabaseURL)
        }
        
        // Note: CoordinationHub and ModelRegistryService use shared instances
        // Core managers will be created directly by the SDK to avoid Main Actor isolation issues in DI
        // These services are accessed via their shared instances where needed
    }
    
    // MARK: - Utility Methods
    
    /// Get the configured container
    /// - Returns: DIContainer instance
    public func getContainer() -> DIContainer {
        return container
    }
    
    /// Get the repository factory
    /// - Returns: RepositoryFactory instance
    public func getFactory() -> RepositoryFactory {
        return factory
    }
    
    /// Check if dependency injection is configured
    /// - Returns: True if configured, false otherwise
    public func isSetupComplete() -> Bool {
        return isConfigured
    }
    
    /// Reset the dependency injection system
    public func reset() {
        container.clear()
        ServiceLocator.shared.clear()
        isConfigured = false
        
        if let logger = container.resolveOptional(SyncLoggerProtocol.self) {
            logger.info("DependencyInjectionSetup: Dependency injection system reset")
        }
    }
    
    // MARK: - Testing Support
    
    /// Configure for testing with mock services
    /// - Parameter mockRegistrations: Mock service registrations
    /// - Throws: DIError if configuration fails
    public func configureForTesting(
        mockRegistrations: @escaping (DIContainer) -> Void
    ) throws {
        // Create test configuration
        let testConfig = configurationProvider.loadConfiguration(
            environment: .testing,
            supabaseURL: "https://test.supabase.co",
            supabaseAnonKey: "test-key"
        )
        
        // Register test configuration
        container.registerSingleton(AppConfiguration.self, instance: testConfig)
        
        // Apply mock registrations
        mockRegistrations(container)
        
        // Configure service locator
        ServiceLocator.shared.configure(with: container)
        
        isConfigured = true
        
        if let logger = container.resolveOptional(SyncLoggerProtocol.self) {
            logger.info("DependencyInjectionSetup: Configured for testing")
        }
    }
}

// MARK: - Global Setup Functions

/// Global setup function for quick configuration
/// - Parameters:
///   - supabaseURL: Supabase project URL
///   - supabaseAnonKey: Supabase anonymous key
///   - environment: Target environment
/// - Throws: DIError if setup fails
public func setupDependencyInjection(
    supabaseURL: String,
    supabaseAnonKey: String,
    environment: Environment = .development
) throws {
    let setup = DependencyInjectionSetup()
    try setup.quickSetup(
        supabaseURL: supabaseURL,
        supabaseAnonKey: supabaseAnonKey,
        environment: environment
    )
}

/// Global setup function with custom configuration
/// - Parameters:
///   - configuration: Complete application configuration
///   - customRegistrations: Optional custom service registrations
/// - Throws: DIError if setup fails
public func setupDependencyInjection(
    with configuration: AppConfiguration,
    customRegistrations: ((DIContainer) -> Void)? = nil
) throws {
    let setup = DependencyInjectionSetup()
    try setup.configure(with: configuration, customRegistrations: customRegistrations)
}

// MARK: - Extensions for SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

/// View modifier for dependency injection setup
@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public struct DependencyInjectionModifier: ViewModifier {
    let configuration: AppConfiguration
    let customRegistrations: ((DIContainer) -> Void)?
    
    @State private var isSetup = false
    @State private var setupError: Error?
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                if !isSetup {
                    do {
                        try setupDependencyInjection(
                            with: configuration,
                            customRegistrations: customRegistrations
                        )
                        isSetup = true
                    } catch {
                        setupError = error
                    }
                }
            }
    }
}

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public extension View {
    /// Setup dependency injection for this view hierarchy
    /// - Parameters:
    ///   - configuration: Application configuration
    ///   - customRegistrations: Optional custom service registrations
    /// - Returns: Modified view with dependency injection setup
    func setupDependencyInjection(
        with configuration: AppConfiguration,
        customRegistrations: ((DIContainer) -> Void)? = nil
    ) -> some View {
        modifier(DependencyInjectionModifier(
            configuration: configuration,
            customRegistrations: customRegistrations
        ))
    }
}
#endif