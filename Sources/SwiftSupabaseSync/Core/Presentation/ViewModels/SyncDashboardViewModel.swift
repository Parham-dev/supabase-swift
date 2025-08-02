//
//  SyncDashboardViewModel.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftUI

/// Comprehensive dashboard ViewModel that provides unified sync monitoring and health overview
/// Combines data from all publishers and managers to present a complete sync status picture
@MainActor
public final class SyncDashboardViewModel: ObservableObject {
    
    // MARK: - Dashboard State
    
    /// Overall sync dashboard status
    @Published public private(set) var dashboardStatus: DashboardStatus = .loading
    
    /// Unified sync overview information
    @Published public private(set) var syncOverview: SyncOverview = SyncOverview.empty
    
    /// Current sync health assessment
    @Published public private(set) var syncHealth: SyncHealthAssessment = SyncHealthAssessment.unknown
    
    /// Active sync operations summary
    @Published public private(set) var activeSyncOperations: [SyncOperationSummary] = []
    
    /// Recent sync events and changes
    @Published public private(set) var recentEvents: [DashboardEvent] = []
    
    /// System recommendations for optimization
    @Published public private(set) var recommendations: [SystemRecommendation] = []
    
    // MARK: - Status Indicators
    
    /// Authentication status indicator
    @Published public private(set) var authenticationStatus: ServiceStatus = .unknown
    
    /// Sync service status indicator
    @Published public private(set) var syncServiceStatus: ServiceStatus = .unknown
    
    /// Network connectivity status indicator
    @Published public private(set) var networkStatus: ServiceStatus = .unknown
    
    /// Real-time connection status indicator
    @Published public private(set) var realtimeStatus: ServiceStatus = .unknown
    
    /// Subscription service status indicator
    @Published public private(set) var subscriptionStatus: ServiceStatus = .unknown
    
    // MARK: - Metrics and Analytics
    
    /// Sync performance metrics
    @Published public private(set) var performanceMetrics: SyncPerformanceMetrics = SyncPerformanceMetrics.empty
    
    /// Data usage statistics
    @Published public private(set) var dataUsageStats: DataUsageStatistics = DataUsageStatistics.empty
    
    /// Error statistics and trends
    @Published public private(set) var errorStatistics: ErrorStatistics = ErrorStatistics.empty
    
    /// Model sync statistics
    @Published public private(set) var modelStatistics: [ModelSyncStatistics] = []
    
    // MARK: - UI State
    
    /// Whether dashboard is refreshing data
    @Published public private(set) var isRefreshing: Bool = false
    
    /// Time when dashboard was last updated
    @Published public private(set) var lastUpdated: Date = Date()
    
    /// Whether to show detailed metrics
    @Published public var showDetailedMetrics: Bool = false
    
    /// Selected time period for analytics
    @Published public var selectedTimePeriod: TimePeriod = .last24Hours
    
    /// Whether dashboard should auto-refresh
    @Published public var autoRefreshEnabled: Bool = true
    
    // MARK: - Dependencies
    
    private let syncStatusPublisher: SyncStatusPublisher
    private let authStatePublisher: AuthStatePublisher
    private let networkStatusPublisher: NetworkStatusPublisher
    private let realtimeDataPublisher: RealtimeDataPublisher
    private let coordinationHub: CoordinationHub
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Auto-refresh Timer
    
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 30.0 // 30 seconds
    
    // MARK: - Initialization
    
    public init(
        syncStatusPublisher: SyncStatusPublisher,
        authStatePublisher: AuthStatePublisher,
        networkStatusPublisher: NetworkStatusPublisher,
        realtimeDataPublisher: RealtimeDataPublisher,
        coordinationHub: CoordinationHub? = nil
    ) {
        self.syncStatusPublisher = syncStatusPublisher
        self.authStatePublisher = authStatePublisher
        self.networkStatusPublisher = networkStatusPublisher
        self.realtimeDataPublisher = realtimeDataPublisher
        self.coordinationHub = coordinationHub ?? CoordinationHub.shared
        
        setupBindings()
        setupAutoRefresh()
        
        Task {
            await refreshDashboard()
        }
    }
    
    // MARK: - Dashboard Operations
    
    /// Refresh all dashboard data
    public func refreshDashboard() async {
        isRefreshing = true
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.updateSyncOverview() }
            group.addTask { await self.updateSyncHealth() }
            group.addTask { await self.updateServiceStatuses() }
            group.addTask { await self.updateMetrics() }
            group.addTask { await self.updateRecommendations() }
            group.addTask { await self.updateRecentEvents() }
        }
        
        await MainActor.run {
            self.lastUpdated = Date()
            self.isRefreshing = false
            self.dashboardStatus = .ready
        }
    }
    
    /// Force refresh of specific dashboard section
    public func refreshSection(_ section: DashboardSection) async {
        switch section {
        case .overview:
            await updateSyncOverview()
        case .health:
            await updateSyncHealth()
        case .services:
            await updateServiceStatuses()
        case .metrics:
            await updateMetrics()
        case .recommendations:
            await updateRecommendations()
        case .events:
            await updateRecentEvents()
        }
        
        lastUpdated = Date()
    }
    
    /// Export dashboard data for analysis
    public func exportDashboardData() async throws -> URL {
        let dashboardData = DashboardExportData(
            overview: syncOverview,
            health: syncHealth,
            serviceStatuses: [
                "authentication": authenticationStatus,
                "sync": syncServiceStatus,
                "network": networkStatus,
                "realtime": realtimeStatus,
                "subscription": subscriptionStatus
            ],
            metrics: performanceMetrics,
            dataUsage: dataUsageStats,
            errors: errorStatistics,
            modelStats: modelStatistics,
            recommendations: recommendations,
            recentEvents: recentEvents,
            exportedAt: Date()
        )
        
        return try await saveDashboardData(dashboardData)
    }
    
    // MARK: - Quick Actions
    
    /// Perform quick sync health check
    public func performHealthCheck() async -> SyncHealthCheckResult {
        let checks = await withTaskGroup(of: (String, Bool, String).self, returning: [(String, Bool, String)].self) { group in
            group.addTask { await ("Authentication", self.authStatePublisher.isAuthenticated, self.authStatePublisher.isAuthenticated ? "OK" : "Not signed in") }
            group.addTask { await ("Network", self.networkStatusPublisher.isConnected, self.networkStatusPublisher.isConnected ? "Connected" : "Offline") }
            group.addTask { await ("Sync Service", self.syncStatusPublisher.isSyncEnabled, self.syncStatusPublisher.isSyncEnabled ? "Active" : "Disabled") }
            group.addTask { await ("Realtime", self.realtimeDataPublisher.isConnected, self.realtimeDataPublisher.isConnected ? "Connected" : "Disconnected") }
            
            var results: [(String, Bool, String)] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        let passedChecks = checks.filter { $0.1 }.count
        let totalChecks = checks.count
        let healthScore = Double(passedChecks) / Double(totalChecks) * 100
        
        return SyncHealthCheckResult(
            overallHealth: healthScore >= 75 ? .healthy : healthScore >= 50 ? .warning : .critical,
            score: Int(healthScore),
            checks: checks.map { HealthCheck(name: $0.0, passed: $0.1, message: $0.2) },
            checkedAt: Date()
        )
    }
    
    /// Start emergency sync if conditions allow
    public func startEmergencySync() async {
        guard authStatePublisher.isAuthenticated && networkStatusPublisher.isConnected else {
            return
        }
        
        await syncStatusPublisher.startSync()
    }
    
    /// Clear all cached data and reset
    public func clearAllData() async {
        // Clear cached data
        recentEvents.removeAll()
        recommendations.removeAll()
        
        // Reset metrics
        performanceMetrics = SyncPerformanceMetrics.empty
        dataUsageStats = DataUsageStatistics.empty
        errorStatistics = ErrorStatistics.empty
        modelStatistics.removeAll()
        
        // Refresh dashboard
        await refreshDashboard()
    }
    
    // MARK: - Computed Properties
    
    /// Overall system health color
    public var overallHealthColor: Color {
        switch syncHealth.level {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .critical: return .red
        case .unknown: return .gray
        }
    }
    
    /// Dashboard status icon
    public var statusIcon: String {
        switch dashboardStatus {
        case .loading: return "hourglass"
        case .ready: return syncHealth.level == .excellent ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .offline: return "wifi.slash"
        }
    }
    
    /// Quick status summary
    public var quickStatusSummary: String {
        if !networkStatusPublisher.isConnected {
            return "Offline"
        } else if !authStatePublisher.isAuthenticated {
            return "Not signed in"
        } else if syncStatusPublisher.isSyncing {
            return "Syncing (\(Int(syncStatusPublisher.syncProgress * 100))%)"
        } else if syncHealth.criticalIssues > 0 {
            return "\(syncHealth.criticalIssues) critical issue(s)"
        } else {
            return "All systems operational"
        }
    }
    
    /// Time since last successful sync
    public var timeSinceLastSync: String {
        // This would calculate time since last successful sync
        return "2 minutes ago" // Placeholder
    }
    
    // MARK: - Private Implementation
    
    private func setupBindings() {
        // Monitor all publishers for changes and update dashboard accordingly
        Publishers.CombineLatest4(
            syncStatusPublisher.$syncStatus,
            authStatePublisher.$authStatus,
            networkStatusPublisher.$isConnected,
            realtimeDataPublisher.$isConnected
        )
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] _, _, _, _ in
            Task { [weak self] in
                await self?.updateServiceStatuses()
                await self?.updateSyncHealth()
            }
        }
        .store(in: &cancellables)
        
        // Listen for coordination events
        coordinationHub.eventPublisher
            .sink { [weak self] event in
                Task { [weak self] in
                    await self?.handleCoordinationEvent(event)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.autoRefreshEnabled else { return }
            
            Task { [weak self] in
                await self?.refreshDashboard()
            }
        }
    }
    
    private func updateSyncOverview() async {
        let registeredModels = syncStatusPublisher.registeredModelTypes
        let activeSyncOps = syncStatusPublisher.activeSyncOperations
        
        await MainActor.run {
            self.syncOverview = SyncOverview(
                totalModels: registeredModels.count,
                activeOperations: activeSyncOps.count,
                lastSyncAt: self.syncStatusPublisher.syncStatus.lastFullSyncAt,
                nextScheduledSync: nil, // Would calculate from scheduler
                syncProgress: self.syncStatusPublisher.syncProgress,
                unresolved: self.syncStatusPublisher.unresolvedConflictsCount
            )
        }
    }
    
    private func updateSyncHealth() async {
        var issues: [String] = []
        var criticalIssues = 0
        
        // Check critical systems
        if !authStatePublisher.isAuthenticated {
            issues.append("Authentication required")
            criticalIssues += 1
        }
        
        if !networkStatusPublisher.isConnected {
            issues.append("Network connectivity lost")
            criticalIssues += 1
        }
        
        if let syncError = syncStatusPublisher.lastSyncError {
            issues.append("Sync error: \(syncError.localizedDescription)")
            criticalIssues += 1
        }
        
        if syncStatusPublisher.registeredModelTypes.isEmpty {
            issues.append("No models registered for sync")
        }
        
        let healthLevel: DashboardSyncHealthLevel = {
            if criticalIssues > 0 { return .critical }
            if issues.count > 2 { return .poor }
            if issues.count > 1 { return .fair }
            if issues.count > 0 { return .good }
            return .excellent
        }()
        
        let healthScore = max(0, 100 - (criticalIssues * 30) - ((issues.count - criticalIssues) * 10))
        let assessment = SyncHealthAssessment(
            level: healthLevel,
            score: healthScore,
            issues: issues,
            criticalIssues: criticalIssues,
            lastAssessed: Date()
        )
        
        await MainActor.run {
            self.syncHealth = assessment
        }
    }
    
    private func updateServiceStatuses() async {
        await MainActor.run {
            self.authenticationStatus = self.authStatePublisher.isAuthenticated ? .operational : .degraded
            self.syncServiceStatus = self.syncStatusPublisher.isSyncEnabled ? .operational : .offline
            self.networkStatus = self.networkStatusPublisher.isConnected ? .operational : .offline
            self.realtimeStatus = self.realtimeDataPublisher.isConnected ? .operational : .degraded
            self.subscriptionStatus = .operational // Would check subscription status
        }
    }
    
    private func updateMetrics() async {
        // Calculate performance metrics
        let metrics = SyncPerformanceMetrics(
            averageSyncTime: 2.5, // Would calculate from historical data
            successRate: 0.95,
            throughput: 1024, // KB/s
            latency: 150, // ms
            errorRate: 0.05,
            lastCalculated: Date()
        )
        
        await MainActor.run {
            self.performanceMetrics = metrics
        }
    }
    
    private func updateRecommendations() async {
        var newRecommendations: [SystemRecommendation] = []
        
        // Network-based recommendations
        if networkStatusPublisher.connectionType == .cellular && networkStatusPublisher.isExpensive {
            newRecommendations.append(
                SystemRecommendation(
                    type: .optimization,
                    title: "Optimize for Cellular",
                    description: "Consider reducing sync frequency on expensive cellular connections",
                    priority: .medium,
                    actionable: true
                )
            )
        }
        
        // Performance recommendations
        if performanceMetrics.successRate < 0.9 {
            newRecommendations.append(
                SystemRecommendation(
                    type: .performance,
                    title: "Improve Sync Reliability",
                    description: "Sync success rate is below optimal. Consider reviewing error logs.",
                    priority: .high,
                    actionable: true
                )
            )
        }
        
        await MainActor.run {
            self.recommendations = newRecommendations
        }
    }
    
    private func updateRecentEvents() async {
        var events: [DashboardEvent] = []
        
        // Add sync events
        if let lastEvent = realtimeDataPublisher.lastChangeEvent {
            events.append(
                DashboardEvent(
                    type: .dataChange,
                    title: "Data Updated",
                    description: "Table \(lastEvent.tableName) was updated",
                    timestamp: lastEvent.timestamp,
                    severity: .info
                )
            )
        }
        
        // Add error events
        if let syncError = syncStatusPublisher.lastSyncError {
            events.append(
                DashboardEvent(
                    type: .error,
                    title: "Sync Error",
                    description: syncError.localizedDescription,
                    timestamp: Date(),
                    severity: .error
                )
            )
        }
        
        await MainActor.run {
            self.recentEvents = events.sorted { $0.timestamp > $1.timestamp }
        }
    }
    
    private func handleCoordinationEvent(_ event: CoordinationEvent) async {
        // Add coordination events to recent events
        let dashboardEvent = DashboardEvent(
            type: .systemEvent,
            title: event.type.rawValue.capitalized,
            description: "System coordination event",
            timestamp: Date(),
            severity: .info
        )
        
        await MainActor.run {
            self.recentEvents.insert(dashboardEvent, at: 0)
            if self.recentEvents.count > 50 {
                self.recentEvents = Array(self.recentEvents.prefix(50))
            }
        }
    }
    
    private func saveDashboardData(_ data: DashboardExportData) async throws -> URL {
        // This would save the dashboard data to a file for export
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "sync_dashboard_\(Date().timeIntervalSince1970).json"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        let jsonData = try JSONEncoder().encode(data)
        try jsonData.write(to: fileURL)
        
        return fileURL
    }
    
    // MARK: - Cleanup
    
    deinit {
        refreshTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

/// Dashboard overall status
public enum DashboardStatus {
    case loading
    case ready
    case error
    case offline
}

/// Dashboard sections for targeted refresh
public enum DashboardSection: CaseIterable {
    case overview
    case health
    case services
    case metrics
    case recommendations
    case events
}

/// Service status indicator
public enum ServiceStatus {
    case operational
    case degraded
    case offline
    case unknown
    
    public var color: Color {
        switch self {
        case .operational: return .green
        case .degraded: return .orange
        case .offline: return .red
        case .unknown: return .gray
        }
    }
    
    public var icon: String {
        switch self {
        case .operational: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .offline: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

/// Sync overview summary
public struct SyncOverview {
    public let totalModels: Int
    public let activeOperations: Int
    public let lastSyncAt: Date?
    public let nextScheduledSync: Date?
    public let syncProgress: Double
    public let unresolved: Int
    
    public static let empty = SyncOverview(
        totalModels: 0,
        activeOperations: 0,
        lastSyncAt: nil,
        nextScheduledSync: nil,
        syncProgress: 0.0,
        unresolved: 0
    )
}

/// Sync health assessment
public struct SyncHealthAssessment {
    public let level: DashboardSyncHealthLevel
    public let score: Int // 0-100
    public let issues: [String]
    public let criticalIssues: Int
    public let lastAssessed: Date
    
    public static let unknown = SyncHealthAssessment(
        level: .unknown,
        score: 0,
        issues: [],
        criticalIssues: 0,
        lastAssessed: Date()
    )
}

/// Dashboard sync health levels
public enum DashboardSyncHealthLevel: CaseIterable, Codable {
    case excellent
    case good
    case fair
    case poor
    case critical
    case unknown
}

/// Sync operation summary for dashboard
public struct SyncOperationSummary: Identifiable {
    public let id = UUID()
    public let modelType: String
    public let operationType: String
    public let progress: Double
    public let startedAt: Date
    public let estimatedCompletion: Date?
}

/// Dashboard events
public struct DashboardEvent: Identifiable {
    public let id = UUID()
    public let type: EventType
    public let title: String
    public let description: String
    public let timestamp: Date
    public let severity: EventSeverity
    
    public enum EventType {
        case dataChange
        case error
        case systemEvent
        case userAction
    }
    
    public enum EventSeverity {
        case info
        case warning
        case error
        case critical
        
        public var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .critical: return .red
            }
        }
    }
}

/// System recommendations
public struct SystemRecommendation: Identifiable {
    public let id = UUID()
    public let type: RecommendationType
    public let title: String
    public let description: String
    public let priority: Priority
    public let actionable: Bool
    
    public enum RecommendationType {
        case performance
        case optimization
        case security
        case maintenance
    }
    
    public enum Priority {
        case low
        case medium
        case high
        case critical
        
        public var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .orange
            case .high: return .red
            case .critical: return .red
            }
        }
    }
}

/// Sync performance metrics
public struct SyncPerformanceMetrics {
    public let averageSyncTime: TimeInterval // seconds
    public let successRate: Double // 0.0 - 1.0
    public let throughput: Double // KB/s
    public let latency: Double // milliseconds
    public let errorRate: Double // 0.0 - 1.0
    public let lastCalculated: Date
    
    public static let empty = SyncPerformanceMetrics(
        averageSyncTime: 0,
        successRate: 0,
        throughput: 0,
        latency: 0,
        errorRate: 0,
        lastCalculated: Date()
    )
}

/// Data usage statistics
public struct DataUsageStatistics {
    public let totalDataTransferred: Int64 // bytes
    public let uploadedData: Int64 // bytes
    public let downloadedData: Int64 // bytes
    public let compressionRatio: Double
    public let period: TimePeriod
    public let lastCalculated: Date
    
    public static let empty = DataUsageStatistics(
        totalDataTransferred: 0,
        uploadedData: 0,
        downloadedData: 0,
        compressionRatio: 0,
        period: .last24Hours,
        lastCalculated: Date()
    )
}

/// Error statistics and trends
public struct ErrorStatistics {
    public let totalErrors: Int
    public let errorsByType: [String: Int]
    public let errorTrend: TrendDirection
    public let mostCommonError: String?
    public let period: TimePeriod
    public let lastCalculated: Date
    
    public static let empty = ErrorStatistics(
        totalErrors: 0,
        errorsByType: [:],
        errorTrend: .stable,
        mostCommonError: nil,
        period: .last24Hours,
        lastCalculated: Date()
    )
}

/// Model-specific sync statistics
public struct ModelSyncStatistics: Identifiable {
    public let id = UUID()
    public let modelName: String
    public let recordCount: Int
    public let lastSyncAt: Date?
    public let syncFrequency: TimeInterval
    public let errorCount: Int
    public let averageSyncTime: TimeInterval
}

/// Time periods for analytics
public enum TimePeriod: CaseIterable {
    case lastHour
    case last24Hours
    case lastWeek
    case lastMonth
    
    public var description: String {
        switch self {
        case .lastHour: return "Last Hour"
        case .last24Hours: return "Last 24 Hours"
        case .lastWeek: return "Last Week"
        case .lastMonth: return "Last Month"
        }
    }
}

/// Trend directions
public enum TrendDirection {
    case increasing
    case decreasing
    case stable
    
    public var icon: String {
        switch self {
        case .increasing: return "arrow.up"
        case .decreasing: return "arrow.down"
        case .stable: return "arrow.right"
        }
    }
    
    public var color: Color {
        switch self {
        case .increasing: return .red
        case .decreasing: return .green
        case .stable: return .gray
        }
    }
}

/// Health check result
public struct SyncHealthCheckResult {
    public let overallHealth: OverallHealth
    public let score: Int
    public let checks: [HealthCheck]
    public let checkedAt: Date
    
    public enum OverallHealth {
        case healthy
        case warning
        case critical
        
        public var color: Color {
            switch self {
            case .healthy: return .green
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
}

/// Individual health check
public struct HealthCheck {
    public let name: String
    public let passed: Bool
    public let message: String
}

/// Dashboard export data structure
private struct DashboardExportData: Codable {
    let overview: SyncOverview
    let health: SyncHealthAssessment
    let serviceStatuses: [String: ServiceStatus]
    let metrics: SyncPerformanceMetrics
    let dataUsage: DataUsageStatistics
    let errors: ErrorStatistics
    let modelStats: [ModelSyncStatistics]
    let recommendations: [SystemRecommendation]
    let recentEvents: [DashboardEvent]
    let exportedAt: Date
}

// MARK: - Codable Extensions

extension SyncOverview: Codable {}
extension SyncHealthAssessment: Codable {}
extension ServiceStatus: Codable {}
extension SyncPerformanceMetrics: Codable {}
extension DataUsageStatistics: Codable {}
extension ErrorStatistics: Codable {}
extension ModelSyncStatistics: Codable {}
extension SystemRecommendation: Codable {}
extension SystemRecommendation.RecommendationType: Codable {}
extension SystemRecommendation.Priority: Codable {}
extension DashboardEvent: Codable {}
extension DashboardEvent.EventType: Codable {}
extension DashboardEvent.EventSeverity: Codable {}
extension TimePeriod: Codable {}
extension TrendDirection: Codable {}