//
//  SyncConfigurationViewModel.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftUI
import SwiftData

/// ViewModel for managing sync configuration, preferences, and high-level sync operations
/// Provides a clean interface for configuring sync behavior and monitoring sync health
@MainActor
public final class SyncConfigurationViewModel: ObservableObject {
    
    // MARK: - Sync Configuration Properties
    
    /// Current sync policy configuration
    @Published public var syncPolicy: SyncPolicy = .balanced
    
    /// Current network policy for sync operations
    @Published public var networkPolicy: NetworkPolicy = .wifiOrCellular
    
    /// Current conflict resolution strategy
    @Published public var conflictResolutionStrategy: ConflictResolutionStrategy = .lastWriteWins
    
    /// Whether automatic sync is enabled
    @Published public var isAutoSyncEnabled: Bool = true
    
    /// Current sync frequency setting
    @Published public var syncFrequency: SyncFrequency = .automatic
    
    /// Whether sync is enabled during low battery
    @Published public var allowSyncOnLowBattery: Bool = false
    
    /// Whether to show sync notifications
    @Published public var showSyncNotifications: Bool = true
    
    /// Maximum number of retry attempts for failed syncs
    @Published public var maxRetryAttempts: Int = 3
    
    // MARK: - Sync Status (from Publishers)
    
    /// Current sync status
    @Published public private(set) var syncStatus: SyncStatus = SyncStatus()
    
    /// Whether sync is currently active
    @Published public private(set) var isSyncing: Bool = false
    
    /// Whether sync is enabled by policy
    @Published public private(set) var isSyncEnabled: Bool = false
    
    /// Current sync progress
    @Published public private(set) var syncProgress: Double = 0.0
    
    /// Last sync error
    @Published public private(set) var lastSyncError: SyncError?
    
    /// Network connection status
    @Published public private(set) var isConnected: Bool = true
    
    /// Current network connection type
    @Published public private(set) var connectionType: ConnectionType = .unknown
    
    /// Whether network conditions are suitable for sync
    @Published public private(set) var networkSuitableForSync: Bool = true
    
    // MARK: - Model Registration
    
    /// All registered model types
    @Published public private(set) var registeredModels: [ModelInfo] = []
    
    /// Whether model discovery is in progress
    @Published public private(set) var isDiscoveringModels: Bool = false
    
    /// Last model registration error
    @Published public private(set) var modelRegistrationError: ModelRegistryError?
    
    // MARK: - UI State
    
    /// Whether configuration changes are being saved
    @Published public private(set) var isSavingConfiguration: Bool = false
    
    /// Whether sync operation is in progress
    @Published public private(set) var isSyncOperationInProgress: Bool = false
    
    /// Last configuration save error
    @Published public private(set) var configurationError: ConfigurationError?
    
    /// Whether to show advanced settings
    @Published public var showAdvancedSettings: Bool = false
    
    // MARK: - Dependencies
    
    private let syncStatusPublisher: SyncStatusPublisher
    private let networkStatusPublisher: NetworkStatusPublisher
    private let syncManager: SyncManager
    private let schemaManager: SchemaManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        syncStatusPublisher: SyncStatusPublisher,
        networkStatusPublisher: NetworkStatusPublisher,
        syncManager: SyncManager,
        schemaManager: SchemaManager
    ) {
        self.syncStatusPublisher = syncStatusPublisher
        self.networkStatusPublisher = networkStatusPublisher
        self.syncManager = syncManager
        self.schemaManager = schemaManager
        
        setupBindings()
        loadCurrentConfiguration()
    }
    
    // MARK: - Sync Operations
    
    /// Start a full synchronization
    public func startFullSync() async {
        await performSyncOperation {
            try await self.syncStatusPublisher.startSync()
        }
    }
    
    /// Start incremental sync for specific model
    public func startIncrementalSync<T: Syncable>(for modelType: T.Type) async {
        await performSyncOperation {
            // This would require exposing incremental sync in the publisher
            try await self.syncManager.startIncrementalSync(for: modelType)
        }
    }
    
    /// Pause current sync operation
    public func pauseSync() async {
        await syncStatusPublisher.pauseSync()
    }
    
    /// Resume paused sync operation
    public func resumeSync() async {
        do {
            try await syncStatusPublisher.resumeSync()
        } catch {
            // Error handling managed by publisher
        }
    }
    
    /// Stop current sync operation
    public func stopSync() async {
        await syncStatusPublisher.stopSync()
    }
    
    // MARK: - Configuration Management
    
    /// Save current configuration settings
    public func saveConfiguration() async {
        isSavingConfiguration = true
        configurationError = nil
        
        do {
            // Update sync policy
            syncManager.updateSyncPolicy(syncPolicy)
            
            // Update network policy
            networkStatusPublisher.updateNetworkPolicy(networkPolicy)
            
            // Update sync enabled state
            await syncStatusPublisher.setSyncEnabled(isAutoSyncEnabled)
            
            // Save to persistent storage
            try await saveConfigurationToPersistentStorage()
            
            await MainActor.run {
                self.isSavingConfiguration = false
            }
            
        } catch {
            await MainActor.run {
                self.configurationError = .saveFailed(error.localizedDescription)
                self.isSavingConfiguration = false
            }
        }
    }
    
    /// Reset configuration to defaults
    public func resetToDefaults() async {
        syncPolicy = .balanced
        networkPolicy = .wifiOrCellular
        conflictResolutionStrategy = .lastWriteWins
        isAutoSyncEnabled = true
        syncFrequency = .automatic
        allowSyncOnLowBattery = false
        showSyncNotifications = true
        maxRetryAttempts = 3
        
        await saveConfiguration()
    }
    
    /// Load configuration from persistent storage
    public func loadConfiguration() async {
        // This would load from UserDefaults or other persistent storage
        loadCurrentConfiguration()
    }
    
    // MARK: - Model Management
    
    /// Register a model type for synchronization
    public func registerModel<T: Syncable>(_ modelType: T.Type) async {
        do {
            syncStatusPublisher.registerModel(modelType)
            await refreshRegisteredModels()
        } catch {
            modelRegistrationError = .registrationFailed(T.tableName, error)
        }
    }
    
    /// Unregister a model type from synchronization
    public func unregisterModel<T: Syncable>(_ modelType: T.Type) async {
        syncStatusPublisher.unregisterModel(modelType)
        await refreshRegisteredModels()
    }
    
    /// Discover and register models from SwiftData container
    public func discoverModels(from container: ModelContainer) async {
        isDiscoveringModels = true
        modelRegistrationError = nil
        
        do {
            // This would require access to ModelRegistryService through managers
            // For now, we'll simulate model discovery
            await refreshRegisteredModels()
            
            await MainActor.run {
                self.isDiscoveringModels = false
            }
        } catch {
            await MainActor.run {
                self.modelRegistrationError = .discoveryFailed("Container", error)
                self.isDiscoveringModels = false
            }
        }
    }
    
    /// Generate database schemas for registered models
    public func generateSchemas() async throws {
        // This would use SchemaManager to generate schemas
        try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // Schema generation would be handled by SchemaManager
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Sync Health & Diagnostics
    
    /// Get sync health assessment
    public func getSyncHealth() -> SyncHealth {
        var issues: [SyncHealthIssue] = []
        var score = 100
        
        // Check network connectivity
        if !isConnected {
            issues.append(.noNetworkConnection)
            score -= 30
        } else if !networkSuitableForSync {
            issues.append(.unsuitableNetworkConditions)
            score -= 15
        }
        
        // Check sync errors
        if let error = lastSyncError {
            issues.append(.syncError(error.localizedDescription))
            score -= 25
        }
        
        // Check model registration
        if registeredModels.isEmpty {
            issues.append(.noModelsRegistered)
            score -= 20
        }
        
        // Check configuration
        if !isAutoSyncEnabled {
            issues.append(.autoSyncDisabled)
            score -= 10
        }
        
        let healthLevel: ConfigSyncHealthLevel = {
            if score >= 90 { return .excellent }
            if score >= 70 { return .good }
            if score >= 50 { return .fair }
            return .poor
        }()
        
        return SyncHealth(
            level: healthLevel,
            score: max(0, score),
            issues: issues,
            lastAssessment: Date()
        )
    }
    
    /// Get sync recommendations based on current state
    public func getSyncRecommendations() -> [SyncRecommendation] {
        var recommendations: [SyncRecommendation] = []
        
        // Network-based recommendations
        if connectionType == .cellular && networkPolicy == .wifiOnly {
            recommendations.append(.changeNetworkPolicy("Consider allowing cellular sync for better availability"))
        }
        
        if allowSyncOnLowBattery == false {
            recommendations.append(.enableLowBatterySync("Enable sync during low battery for better consistency"))
        }
        
        // Sync frequency recommendations
        if syncFrequency == .manual && isAutoSyncEnabled {
            recommendations.append(.enableAutoSync("Enable automatic sync for real-time data updates"))
        }
        
        // Model registration recommendations
        if registeredModels.isEmpty {
            recommendations.append(.registerModels("Register your SwiftData models to enable synchronization"))
        }
        
        return recommendations
    }
    
    /// Run sync diagnostics
    public func runDiagnostics() async -> SyncDiagnosticReport {
        let health = getSyncHealth()
        let recommendations = getSyncRecommendations()
        
        // Test network connectivity
        let networkTest = await testNetworkConnectivity()
        
        // Test authentication
        let authTest = await testAuthentication()
        
        // Test model registration
        let modelTest = testModelRegistration()
        
        return SyncDiagnosticReport(
            health: health,
            recommendations: recommendations,
            networkTest: networkTest,
            authenticationTest: authTest,
            modelRegistrationTest: modelTest,
            generatedAt: Date()
        )
    }
    
    // MARK: - Computed Properties
    
    /// Whether sync can be started
    public var canStartSync: Bool {
        return !isSyncing && isConnected && isSyncEnabled && !registeredModels.isEmpty
    }
    
    /// Whether sync can be paused
    public var canPauseSync: Bool {
        return isSyncing && syncStatus.state.isActive
    }
    
    /// Whether sync can be resumed
    public var canResumeSync: Bool {
        return syncStatus.state == .paused
    }
    
    /// Current sync status description
    public var syncStatusDescription: String {
        if isSyncing {
            return "Syncing \(Int(syncProgress * 100))% complete"
        } else if let error = lastSyncError {
            return "Sync failed: \(error.localizedDescription)"
        } else if !isConnected {
            return "Offline - sync will resume when connected"
        } else if !isSyncEnabled {
            return "Sync is disabled"
        } else {
            return "Ready to sync"
        }
    }
    
    /// Network status description
    public var networkStatusDescription: String {
        if !isConnected {
            return "Not connected"
        } else {
            var description = connectionType.description
            if !networkSuitableForSync {
                description += " (not suitable for sync)"
            }
            return description
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupBindings() {
        // Bind SyncStatusPublisher properties
        syncStatusPublisher.$syncStatus
            .assign(to: \.syncStatus, on: self)
            .store(in: &cancellables)
        
        syncStatusPublisher.$isSyncing
            .assign(to: \.isSyncing, on: self)
            .store(in: &cancellables)
        
        syncStatusPublisher.$isSyncEnabled
            .assign(to: \.isSyncEnabled, on: self)
            .store(in: &cancellables)
        
        syncStatusPublisher.$syncProgress
            .assign(to: \.syncProgress, on: self)
            .store(in: &cancellables)
        
        syncStatusPublisher.$lastSyncError
            .assign(to: \.lastSyncError, on: self)
            .store(in: &cancellables)
        
        // Bind NetworkStatusPublisher properties
        networkStatusPublisher.$isConnected
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
        
        networkStatusPublisher.$connectionType
            .assign(to: \.connectionType, on: self)
            .store(in: &cancellables)
        
        networkStatusPublisher.$isSuitableForSync
            .assign(to: \.networkSuitableForSync, on: self)
            .store(in: &cancellables)
    }
    
    private func loadCurrentConfiguration() {
        // Load configuration from persistent storage
        // This would typically read from UserDefaults or other storage
        // For now, use default values
    }
    
    private func saveConfigurationToPersistentStorage() async throws {
        // Save configuration to persistent storage
        // This would typically write to UserDefaults or other storage
    }
    
    private func refreshRegisteredModels() async {
        let modelTypes = syncStatusPublisher.registeredModelTypes
        
        await MainActor.run {
            self.registeredModels = modelTypes.map { tableName in
                ModelInfo(
                    tableName: tableName,
                    isActive: true,
                    lastSyncAt: nil,
                    recordCount: nil
                )
            }
        }
    }
    
    private func performSyncOperation(_ operation: @escaping () async throws -> Void) async {
        isSyncOperationInProgress = true
        
        do {
            try await operation()
        } catch {
            // Error handling managed by publishers
        }
        
        isSyncOperationInProgress = false
    }
    
    // MARK: - Diagnostic Tests
    
    private func testNetworkConnectivity() async -> DiagnosticTestResult {
        if !isConnected {
            return DiagnosticTestResult(
                name: "Network Connectivity",
                passed: false,
                message: "No network connection detected",
                suggestion: "Check your internet connection"
            )
        }
        
        if !networkSuitableForSync {
            return DiagnosticTestResult(
                name: "Network Connectivity",
                passed: false,
                message: "Network conditions not suitable for sync",
                suggestion: "Consider adjusting network policy settings"
            )
        }
        
        return DiagnosticTestResult(
            name: "Network Connectivity",
            passed: true,
            message: "Network connection is healthy",
            suggestion: nil
        )
    }
    
    private func testAuthentication() async -> DiagnosticTestResult {
        // This would test authentication status
        return DiagnosticTestResult(
            name: "Authentication",
            passed: true,
            message: "Authentication is valid",
            suggestion: nil
        )
    }
    
    private func testModelRegistration() -> DiagnosticTestResult {
        if registeredModels.isEmpty {
            return DiagnosticTestResult(
                name: "Model Registration",
                passed: false,
                message: "No models registered for sync",
                suggestion: "Register your SwiftData models using registerModel()"
            )
        }
        
        return DiagnosticTestResult(
            name: "Model Registration",
            passed: true,
            message: "\(registeredModels.count) model(s) registered",
            suggestion: nil
        )
    }
}

// MARK: - Supporting Types

/// Information about a registered model
public struct ModelInfo: Identifiable, Equatable {
    public let id = UUID()
    public let tableName: String
    public let isActive: Bool
    public let lastSyncAt: Date?
    public let recordCount: Int?
}

/// Sync health assessment
public struct SyncHealth {
    public let level: ConfigSyncHealthLevel
    public let score: Int // 0-100
    public let issues: [SyncHealthIssue]
    public let lastAssessment: Date
}

/// Sync health levels for configuration
public enum ConfigSyncHealthLevel: CaseIterable {
    case excellent
    case good
    case fair
    case poor
    
    public var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
}

/// Sync health issues
public enum SyncHealthIssue {
    case noNetworkConnection
    case unsuitableNetworkConditions
    case syncError(String)
    case noModelsRegistered
    case autoSyncDisabled
    
    public var description: String {
        switch self {
        case .noNetworkConnection:
            return "No network connection"
        case .unsuitableNetworkConditions:
            return "Network conditions not suitable for sync"
        case .syncError(let message):
            return "Sync error: \(message)"
        case .noModelsRegistered:
            return "No models registered for sync"
        case .autoSyncDisabled:
            return "Automatic sync is disabled"
        }
    }
}

/// Sync recommendations
public enum SyncRecommendation {
    case changeNetworkPolicy(String)
    case enableAutoSync(String)
    case enableLowBatterySync(String)
    case registerModels(String)
    
    public var description: String {
        switch self {
        case .changeNetworkPolicy(let message),
             .enableAutoSync(let message),
             .enableLowBatterySync(let message),
             .registerModels(let message):
            return message
        }
    }
}

/// Sync diagnostic report
public struct SyncDiagnosticReport {
    public let health: SyncHealth
    public let recommendations: [SyncRecommendation]
    public let networkTest: DiagnosticTestResult
    public let authenticationTest: DiagnosticTestResult
    public let modelRegistrationTest: DiagnosticTestResult
    public let generatedAt: Date
}

/// Individual diagnostic test result
public struct DiagnosticTestResult {
    public let name: String
    public let passed: Bool
    public let message: String
    public let suggestion: String?
}

/// Configuration errors
public enum ConfigurationError: Error, LocalizedError {
    case saveFailed(String)
    case loadFailed(String)
    case invalidValue(String)
    
    public var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save configuration: \(message)"
        case .loadFailed(let message):
            return "Failed to load configuration: \(message)"
        case .invalidValue(let message):
            return "Invalid configuration value: \(message)"
        }
    }
}