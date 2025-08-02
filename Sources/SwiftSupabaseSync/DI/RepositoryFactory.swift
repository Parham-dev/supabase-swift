//
//  RepositoryFactory.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Factory for creating repository instances with proper dependency injection
/// Provides convenient methods for repository instantiation while managing dependencies
public final class RepositoryFactory {
    
    // MARK: - Properties
    
    private let container: DIContainer
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Initialization
    
    public init(container: DIContainer, logger: SyncLoggerProtocol? = nil) {
        self.container = container
        self.logger = logger
    }
    
    // MARK: - Repository Creation Methods
    
    /// Create AuthRepository with all dependencies
    /// - Returns: Configured AuthRepository instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createAuthRepository() throws -> AuthRepository {
        logger?.debug("RepositoryFactory: Creating AuthRepository")
        
        let authDataSource = try container.resolve(SupabaseAuthDataSource.self)
        let keychainService = try container.resolve(KeychainService.self)
        let logger = container.resolveOptional(SyncLoggerProtocol.self)
        
        return AuthRepository(
            authDataSource: authDataSource,
            keychainService: keychainService,
            logger: logger
        )
    }
    
    /// Create SyncRepository with all dependencies
    /// - Returns: Configured SyncRepository instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createSyncRepository() throws -> SyncRepository {
        logger?.debug("RepositoryFactory: Creating SyncRepository")
        
        let localDataSource = try container.resolve(LocalDataSource.self)
        let remoteDataSource = try container.resolve(SupabaseDataDataSource.self)
        let realtimeDataSource = container.resolveOptional(SupabaseRealtimeDataSource.self)
        let logger = container.resolveOptional(SyncLoggerProtocol.self)
        
        return SyncRepository(
            localDataSource: localDataSource,
            remoteDataSource: remoteDataSource,
            realtimeDataSource: realtimeDataSource,
            logger: logger
        )
    }
    
    /// Create ConflictRepository with all dependencies
    /// - Returns: Configured ConflictRepository instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createConflictRepository() throws -> ConflictRepository {
        logger?.debug("RepositoryFactory: Creating ConflictRepository")
        
        let localDataSource = try container.resolve(LocalDataSource.self)
        let remoteDataSource = try container.resolve(SupabaseDataDataSource.self)
        let logger = container.resolveOptional(SyncLoggerProtocol.self)
        
        return ConflictRepository(
            localDataSource: localDataSource,
            remoteDataSource: remoteDataSource,
            logger: logger
        )
    }
    
    /// Create SubscriptionValidator with all dependencies
    /// - Returns: Configured SubscriptionValidator instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createSubscriptionValidator() throws -> SubscriptionValidator {
        logger?.debug("RepositoryFactory: Creating SubscriptionValidator")
        
        let logger = container.resolveOptional(SyncLoggerProtocol.self)
        
        return SubscriptionValidator(
            logger: logger
        )
    }
    
    /// Create LoggingService instance
    /// - Returns: Configured LoggingService instance
    public func createLoggingService() -> LoggingService {
        logger?.debug("RepositoryFactory: Creating LoggingService")
        
        return LoggingService()
    }
    
    // MARK: - Service Creation Methods
    
    /// Create LocalDataSource with dependencies
    /// - Returns: Configured LocalDataSource instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createLocalDataSource() throws -> LocalDataSource {
        logger?.debug("RepositoryFactory: Creating LocalDataSource")
        
        // Note: In a real implementation, we'd need to get the ModelContext from the app
        // For now, we'll throw an error instead of using fatalError to avoid build issues
        throw DIError.serviceNotRegistered("LocalDataSource requires ModelContext from the app - this needs to be registered separately")
    }
    
    /// Create SupabaseAuthDataSource with dependencies
    /// - Returns: Configured SupabaseAuthDataSource instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createSupabaseAuthDataSource() throws -> SupabaseAuthDataSource {
        logger?.debug("RepositoryFactory: Creating SupabaseAuthDataSource")
        
        let supabaseClient = try container.resolve(SupabaseClient.self)
        let config = try container.resolve(AppConfiguration.self)
        let keychainService = try container.resolve(KeychainService.self)
        
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw DIError.instantiationFailed("SupabaseAuthDataSource", 
                NSError(domain: "Invalid Supabase URL", code: 1, userInfo: nil))
        }
        
        return SupabaseAuthDataSource(
            httpClient: supabaseClient,
            baseURL: baseURL,
            keychainService: keychainService
        )
    }
    
    /// Create SupabaseDataDataSource with dependencies
    /// - Returns: Configured SupabaseDataDataSource instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createSupabaseDataDataSource() throws -> SupabaseDataDataSource {
        logger?.debug("RepositoryFactory: Creating SupabaseDataDataSource")
        
        let supabaseClient = try container.resolve(SupabaseClient.self)
        let config = try container.resolve(AppConfiguration.self)
        
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw DIError.instantiationFailed("SupabaseDataDataSource", 
                NSError(domain: "Invalid Supabase URL", code: 1, userInfo: nil))
        }
        
        return SupabaseDataDataSource(
            httpClient: supabaseClient,
            baseURL: baseURL
        )
    }
    
    /// Create SupabaseRealtimeDataSource with dependencies
    /// - Returns: Configured SupabaseRealtimeDataSource instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createSupabaseRealtimeDataSource() throws -> SupabaseRealtimeDataSource {
        logger?.debug("RepositoryFactory: Creating SupabaseRealtimeDataSource")
        
        let config = try container.resolve(AppConfiguration.self)
        
        guard let baseURL = URL(string: config.supabaseURL) else {
            throw DIError.instantiationFailed("SupabaseRealtimeDataSource", 
                NSError(domain: "Invalid Supabase URL", code: 1, userInfo: nil))
        }
        
        return SupabaseRealtimeDataSource(
            baseURL: baseURL
        )
    }
    
    /// Create KeychainService
    /// - Returns: Configured KeychainService instance
    public func createKeychainService() -> KeychainService {
        logger?.debug("RepositoryFactory: Creating KeychainService")
        
        return KeychainService()
    }
    
    /// Create SupabaseClient with dependencies
    /// - Returns: Configured SupabaseClient instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createSupabaseClient() throws -> SupabaseClient {
        logger?.debug("RepositoryFactory: Creating SupabaseClient")
        
        let configuration = try container.resolve(NetworkConfiguration.self)
        
        return SupabaseClient(
            baseURL: configuration.supabaseURL,
            apiKey: configuration.supabaseKey,
            maxRetryAttempts: configuration.maxRetryAttempts,
            retryDelay: configuration.retryDelay
        )
    }
    
    // MARK: - Use Case Creation Methods
    
    /// Create AuthenticateUserUseCase with dependencies
    /// - Returns: Configured AuthenticateUserUseCase instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createAuthenticateUserUseCase() throws -> AuthenticateUserUseCase {
        logger?.debug("RepositoryFactory: Creating AuthenticateUserUseCase")
        
        let authRepository = try container.resolve(AuthRepositoryProtocol.self)
        let subscriptionValidator = try container.resolve(SubscriptionValidating.self)
        let logger = container.resolveOptional(SyncLoggerProtocol.self)
        
        return AuthenticateUserUseCase(
            authRepository: authRepository,
            subscriptionValidator: subscriptionValidator,
            logger: logger
        )
    }
    
    /// Create StartSyncUseCase with dependencies
    /// - Returns: Configured StartSyncUseCase instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createStartSyncUseCase() throws -> StartSyncUseCase {
        logger?.debug("RepositoryFactory: Creating StartSyncUseCase")
        
        let syncRepository = try container.resolve(SyncRepositoryProtocol.self)
        let subscriptionValidator = try container.resolve(SubscriptionValidating.self)
        let authUseCase = try container.resolve(AuthenticateUserUseCaseProtocol.self)
        let logger = container.resolveOptional(SyncLoggerProtocol.self)
        
        return StartSyncUseCase(
            syncRepository: syncRepository,
            subscriptionValidator: subscriptionValidator,
            authUseCase: authUseCase,
            logger: logger
        )
    }
    
    /// Create ValidateSubscriptionUseCase with dependencies
    /// - Returns: Configured ValidateSubscriptionUseCase instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createValidateSubscriptionUseCase() throws -> ValidateSubscriptionUseCase {
        logger?.debug("RepositoryFactory: Creating ValidateSubscriptionUseCase")
        
        let subscriptionValidator = try container.resolve(SubscriptionValidating.self)
        let logger = container.resolveOptional(SyncLoggerProtocol.self)
        
        let authUseCase = try container.resolve(AuthenticateUserUseCaseProtocol.self)
        
        return ValidateSubscriptionUseCase(
            subscriptionValidator: subscriptionValidator,
            authUseCase: authUseCase,
            logger: logger
        )
    }
    
    /// Create ResolveSyncConflictUseCase with dependencies
    /// - Returns: Configured ResolveSyncConflictUseCase instance
    /// - Throws: DIError if dependencies cannot be resolved
    public func createResolveSyncConflictUseCase() throws -> ResolveSyncConflictUseCase {
        logger?.debug("RepositoryFactory: Creating ResolveSyncConflictUseCase")
        
        let syncRepository = try container.resolve(SyncRepositoryProtocol.self)
        let authUseCase = try container.resolve(AuthenticateUserUseCaseProtocol.self)
        let logger = container.resolveOptional(SyncLoggerProtocol.self)
        
        // Create a default conflict resolver
        let conflictResolver = StrategyBasedConflictResolver(strategy: .lastWriteWins)
        let subscriptionUseCase = try container.resolve(ValidateSubscriptionUseCaseProtocol.self)
        
        return ResolveSyncConflictUseCase(
            syncRepository: syncRepository,
            conflictResolver: conflictResolver,
            authUseCase: authUseCase,
            subscriptionUseCase: subscriptionUseCase,
            logger: logger
        )
    }
    
    // MARK: - Batch Creation Methods
    
    /// Create all repositories and register them in the container
    /// - Throws: DIError if any repository cannot be created
    public func registerAllRepositories() throws {
        logger?.debug("RepositoryFactory: Registering all repositories")
        
        // Register repository protocols with their implementations
        container.register(AuthRepositoryProtocol.self, lifetime: .singleton) { _ in
            try self.createAuthRepository()
        }
        
        container.register(SyncRepositoryProtocol.self, lifetime: .singleton) { _ in
            try self.createSyncRepository()
        }
        
        // Note: ConflictRepository doesn't have a protocol - register the concrete class
        container.register(ConflictRepository.self, lifetime: .singleton) { _ in
            try self.createConflictRepository()
        }
        
        container.register(SubscriptionValidating.self, lifetime: .singleton) { _ in
            try self.createSubscriptionValidator()
        }
        
        container.register(SyncLoggerProtocol.self, lifetime: .singleton) { _ in
            self.createLoggingService()
        }
        
        logger?.info("RepositoryFactory: All repositories registered successfully")
    }
    
    /// Create all use cases and register them in the container
    /// - Throws: DIError if any use case cannot be created
    public func registerAllUseCases() throws {
        logger?.debug("RepositoryFactory: Registering all use cases")
        
        // Register use case protocols with their implementations
        container.register(AuthenticateUserUseCaseProtocol.self, lifetime: .singleton) { _ in
            try self.createAuthenticateUserUseCase()
        }
        
        container.register(StartSyncUseCaseProtocol.self, lifetime: .singleton) { _ in
            try self.createStartSyncUseCase()
        }
        
        container.register(ValidateSubscriptionUseCaseProtocol.self, lifetime: .singleton) { _ in
            try self.createValidateSubscriptionUseCase()
        }
        
        container.register(ResolveSyncConflictUseCaseProtocol.self, lifetime: .singleton) { _ in
            try self.createResolveSyncConflictUseCase()
        }
        
        logger?.info("RepositoryFactory: All use cases registered successfully")
    }
    
    /// Create all data sources and register them in the container
    /// - Throws: DIError if any data source cannot be created
    public func registerAllDataSources() throws {
        logger?.debug("RepositoryFactory: Registering all data sources")
        
        // NOTE: LocalDataSource requires ModelContext from the app and should be registered separately
        // container.register(LocalDataSource.self, lifetime: .singleton) { _ in
        //     try self.createLocalDataSource()
        // }
        
        container.register(SupabaseAuthDataSource.self, lifetime: .singleton) { _ in
            try self.createSupabaseAuthDataSource()
        }
        
        container.register(SupabaseDataDataSource.self, lifetime: .singleton) { _ in
            try self.createSupabaseDataDataSource()
        }
        
        container.register(SupabaseRealtimeDataSource.self, lifetime: .singleton) { _ in
            try self.createSupabaseRealtimeDataSource()
        }
        
        container.register(KeychainService.self, lifetime: .singleton) { _ in
            self.createKeychainService()
        }
        
        container.register(SupabaseClient.self, lifetime: .singleton) { _ in
            try self.createSupabaseClient()
        }
        
        logger?.info("RepositoryFactory: All data sources registered successfully")
    }
}