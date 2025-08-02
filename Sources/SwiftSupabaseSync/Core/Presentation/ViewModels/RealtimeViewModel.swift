//
//  RealtimeViewModel.swift
//  SupabaseSwift
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel for managing real-time data subscriptions, connection state, and event handling
/// Provides comprehensive real-time functionality for SwiftUI views with automatic reconnection and error recovery
@MainActor
public final class RealtimeViewModel: ObservableObject {
    
    // MARK: - Connection State Properties
    
    /// Current connection status
    @Published public private(set) var connectionStatus: RealtimeConnectionStatus = .disconnected
    
    /// Whether connected to realtime server
    @Published public private(set) var isConnected: Bool = false
    
    /// Whether connection is in progress
    @Published public private(set) var isConnecting: Bool = false
    
    /// Whether there are any connection errors
    @Published public private(set) var hasConnectionError: Bool = false
    
    /// User-friendly connection status description
    @Published public private(set) var statusDescription: String = "Disconnected"
    
    /// Connection quality indicator
    @Published public private(set) var connectionQuality: ConnectionQuality = .unknown
    
    /// Connection latency in milliseconds
    @Published public private(set) var connectionLatency: Double = 0
    
    // MARK: - Subscription Management Properties
    
    /// Status of all active subscriptions
    @Published public private(set) var subscriptionStatuses: [String: RealtimeSubscriptionStatus] = [:]
    
    /// Number of active subscriptions
    @Published public private(set) var activeSubscriptionCount: Int = 0
    
    /// Number of subscriptions with errors
    @Published public private(set) var errorSubscriptionCount: Int = 0
    
    /// Subscription details for management
    @Published public private(set) var subscriptionDetails: [SubscriptionDetail] = []
    
    /// Tables currently being monitored
    @Published public private(set) var monitoredTables: Set<String> = []
    
    // MARK: - Event Management Properties
    
    /// Last realtime change event received
    @Published public private(set) var lastChangeEvent: RealtimeChangeEvent?
    
    /// Recent change events (configurable limit)
    @Published public private(set) var recentEvents: [RealtimeChangeEvent] = []
    
    /// Events grouped by table name
    @Published public private(set) var eventsByTable: [String: [RealtimeChangeEvent]] = [:]
    
    /// Events grouped by type
    @Published public private(set) var eventsByType: [RealtimeEventType: [RealtimeChangeEvent]] = [:]
    
    /// Event statistics
    @Published public private(set) var eventStatistics: RealtimeEventStatistics = RealtimeEventStatistics.empty
    
    // MARK: - UI State Properties
    
    /// Whether to show detailed connection info
    @Published public var showConnectionDetails: Bool = false
    
    /// Whether to show real-time event feed
    @Published public var showEventFeed: Bool = false
    
    /// Selected table for filtering events
    @Published public var selectedTable: String?
    
    /// Selected event type for filtering
    @Published public var selectedEventType: RealtimeEventType?
    
    /// Maximum number of recent events to keep
    @Published public var maxRecentEvents: Int = 100
    
    /// Whether auto-reconnection is enabled
    @Published public var autoReconnectEnabled: Bool = true
    
    /// Current reconnection attempt count
    @Published public private(set) var reconnectionAttempts: Int = 0
    
    // MARK: - Performance Metrics
    
    /// Connection uptime
    @Published public private(set) var connectionUptime: TimeInterval = 0
    
    /// Events per minute rate
    @Published public private(set) var eventsPerMinute: Double = 0
    
    /// Data transfer statistics
    @Published public private(set) var dataTransferStats: DataTransferStats = DataTransferStats.empty
    
    /// Connection stability score (0.0 to 1.0)
    @Published public private(set) var stabilityScore: Double = 0.0
    
    // MARK: - Dependencies
    
    private let realtimeDataPublisher: RealtimeDataPublisher
    private let networkStatusPublisher: NetworkStatusPublisher
    private let authStatePublisher: AuthStatePublisher
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Internal State
    
    private var connectionStartTime: Date?
    private var eventTimestamps: [Date] = []
    private var reconnectionTimer: Timer?
    private var connectionAttempts: Int = 0
    private let maxReconnectionAttempts = 10
    private let reconnectionDelay: TimeInterval = 5.0
    
    // MARK: - Event Handlers
    
    private var eventHandlers: [String: (RealtimeChangeEvent) -> Void] = [:]
    private var globalEventHandlers: [(RealtimeChangeEvent) -> Void] = []
    
    // MARK: - Initialization
    
    public init(
        realtimeDataPublisher: RealtimeDataPublisher,
        networkStatusPublisher: NetworkStatusPublisher,
        authStatePublisher: AuthStatePublisher
    ) {
        self.realtimeDataPublisher = realtimeDataPublisher
        self.networkStatusPublisher = networkStatusPublisher
        self.authStatePublisher = authStatePublisher
        
        setupBindings()
        setupAutoReconnection()
        updateInitialState()
    }
    
    // MARK: - Connection Management
    
    /// Connect to realtime server
    public func connect() async {
        guard !isConnecting && !isConnected else { return }
        
        connectionAttempts += 1
        connectionStartTime = Date()
        
        await realtimeDataPublisher.connect()
    }
    
    /// Disconnect from realtime server
    public func disconnect() {
        realtimeDataPublisher.disconnect()
        connectionStartTime = nil
        connectionUptime = 0
        connectionAttempts = 0
        reconnectionAttempts = 0
        stopReconnectionTimer()
    }
    
    /// Reconnect to realtime server
    public func reconnect() async {
        disconnect()
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        await connect()
    }
    
    /// Force reconnection (for manual retry)
    public func forceReconnect() async {
        stopReconnectionTimer()
        reconnectionAttempts = 0
        await reconnect()
    }
    
    // MARK: - Subscription Management
    
    /// Subscribe to table changes
    public func subscribeToTable(
        _ tableName: String,
        eventTypes: [RealtimeEventType] = RealtimeEventType.allCases,
        onEvent: @escaping (RealtimeChangeEvent) -> Void = { _ in }
    ) async throws -> String {
        let subscriptionId = try await realtimeDataPublisher.subscribe(
            to: tableName,
            for: eventTypes,
            onEvent: { [weak self] event in
                onEvent(event)
                Task { [weak self] in
                    await self?.handleRealtimeEvent(event)
                }
            }
        )
        
        // Store event handler for management
        eventHandlers[subscriptionId] = onEvent
        
        // Update monitored tables
        monitoredTables.insert(tableName)
        
        // Create subscription detail
        let detail = SubscriptionDetail(
            id: subscriptionId,
            tableName: tableName,
            eventTypes: eventTypes,
            subscribedAt: Date(),
            eventCount: 0
        )
        subscriptionDetails.append(detail)
        
        return subscriptionId
    }
    
    /// Unsubscribe from table changes
    public func unsubscribe(from subscriptionId: String) {
        realtimeDataPublisher.unsubscribe(from: subscriptionId)
        
        // Remove event handler
        eventHandlers.removeValue(forKey: subscriptionId)
        
        // Remove subscription detail and update monitored tables
        if let index = subscriptionDetails.firstIndex(where: { $0.id == subscriptionId }) {
            let detail = subscriptionDetails[index]
            subscriptionDetails.remove(at: index)
            
            // Check if table is still monitored by other subscriptions
            let stillMonitored = subscriptionDetails.contains { $0.tableName == detail.tableName }
            if !stillMonitored {
                monitoredTables.remove(detail.tableName)
            }
        }
    }
    
    /// Unsubscribe from all subscriptions
    public func unsubscribeAll() {
        for subscriptionId in Array(eventHandlers.keys) {
            unsubscribe(from: subscriptionId)
        }
    }
    
    /// Subscribe to all registered sync models
    public func subscribeToSyncModels() async {
        // This would integrate with ModelRegistry to get registered models
        // For now, we'll demonstrate with common table patterns
        let commonTables = ["users", "documents", "settings", "logs"]
        
        for tableName in commonTables {
            do {
                _ = try await subscribeToTable(tableName) { [weak self] event in
                    Task { [weak self] in
                        await self?.handleSyncModelEvent(event)
                    }
                }
            } catch {
                // Handle subscription error
                continue
            }
        }
    }
    
    // MARK: - Event Handling
    
    /// Add a global event handler that receives all events
    public func addGlobalEventHandler(_ handler: @escaping (RealtimeChangeEvent) -> Void) {
        globalEventHandlers.append(handler)
    }
    
    /// Remove all global event handlers
    public func clearGlobalEventHandlers() {
        globalEventHandlers.removeAll()
    }
    
    /// Get events for a specific table
    public func getEvents(for tableName: String) -> [RealtimeChangeEvent] {
        return eventsByTable[tableName] ?? []
    }
    
    /// Get events of a specific type
    public func getEvents(of type: RealtimeEventType) -> [RealtimeChangeEvent] {
        return eventsByType[type] ?? []
    }
    
    /// Clear all stored events
    public func clearEvents() {
        recentEvents.removeAll()
        eventsByTable.removeAll()
        eventsByType.removeAll()
        eventTimestamps.removeAll()
        updateEventStatistics()
    }
    
    /// Get filtered events based on current selection
    public var filteredEvents: [RealtimeChangeEvent] {
        var events = recentEvents
        
        if let selectedTable = selectedTable {
            events = events.filter { $0.tableName == selectedTable }
        }
        
        if let selectedEventType = selectedEventType {
            events = events.filter { $0.eventType == selectedEventType }
        }
        
        return events
    }
    
    // MARK: - Computed Properties
    
    /// Whether realtime is available for use
    public var isAvailable: Bool {
        return isConnected && !hasConnectionError && authStatePublisher.isAuthenticated
    }
    
    /// Whether all subscriptions are healthy
    public var allSubscriptionsHealthy: Bool {
        return errorSubscriptionCount == 0
    }
    
    /// Connection status color for UI indicators
    public var statusColor: Color {
        switch connectionStatus {
        case .connected:
            return allSubscriptionsHealthy ? .green : .orange
        case .connecting:
            return .blue
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    /// Connection status icon
    public var statusIcon: String {
        switch connectionStatus {
        case .connected:
            return allSubscriptionsHealthy ? "wifi" : "wifi.exclamationmark"
        case .connecting:
            return "wifi.circle"
        case .disconnected:
            return "wifi.slash"
        case .error:
            return "wifi.exclamationmark"
        }
    }
    
    /// Time since last event
    public var timeSinceLastEvent: TimeInterval? {
        return realtimeDataPublisher.timeSinceLastEvent
    }
    
    /// Formatted time since last event
    public var formattedTimeSinceLastEvent: String {
        return realtimeDataPublisher.formattedTimeSinceLastEvent
    }
    
    /// Connection health status
    public var connectionHealth: ConnectionHealth {
        if !isConnected {
            return .poor
        } else if hasConnectionError || errorSubscriptionCount > 0 {
            return .fair
        } else if stabilityScore > 0.9 {
            return .excellent
        } else if stabilityScore > 0.7 {
            return .good
        } else {
            return .fair
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupBindings() {
        // Bind to RealtimeDataPublisher properties
        realtimeDataPublisher.$connectionStatus
            .sink { [weak self] status in
                self?.handleConnectionStatusChange(status)
            }
            .store(in: &cancellables)
        
        realtimeDataPublisher.$isConnected
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
        
        realtimeDataPublisher.$isConnecting
            .assign(to: \.isConnecting, on: self)
            .store(in: &cancellables)
        
        realtimeDataPublisher.$hasConnectionError
            .assign(to: \.hasConnectionError, on: self)
            .store(in: &cancellables)
        
        realtimeDataPublisher.$statusDescription
            .assign(to: \.statusDescription, on: self)
            .store(in: &cancellables)
        
        realtimeDataPublisher.$subscriptionStatuses
            .sink { [weak self] statuses in
                self?.handleSubscriptionStatusesChange(statuses)
            }
            .store(in: &cancellables)
        
        realtimeDataPublisher.$lastChangeEvent
            .sink { [weak self] event in
                if let event = event {
                    Task { [weak self] in
                        await self?.handleRealtimeEvent(event)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor network status for auto-reconnection
        networkStatusPublisher.$isConnected
            .sink { [weak self] isConnected in
                if isConnected && self?.autoReconnectEnabled == true && !(self?.isConnected ?? false) {
                    Task { [weak self] in
                        await self?.handleNetworkReconnection()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Monitor authentication status
        authStatePublisher.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if !isAuthenticated {
                    self?.disconnect()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAutoReconnection() {
        // Monitor connection status for auto-reconnection
        $connectionStatus
            .sink { [weak self] status in
                self?.handleAutoReconnection(for: status)
            }
            .store(in: &cancellables)
    }
    
    private func updateInitialState() {
        connectionStatus = realtimeDataPublisher.connectionStatus
        isConnected = realtimeDataPublisher.isConnected
        isConnecting = realtimeDataPublisher.isConnecting
        hasConnectionError = realtimeDataPublisher.hasConnectionError
        statusDescription = realtimeDataPublisher.statusDescription
        subscriptionStatuses = realtimeDataPublisher.subscriptionStatuses
        activeSubscriptionCount = realtimeDataPublisher.activeSubscriptionCount
        errorSubscriptionCount = realtimeDataPublisher.errorSubscriptionCount
        lastChangeEvent = realtimeDataPublisher.lastChangeEvent
        recentEvents = realtimeDataPublisher.recentEvents
        eventsByTable = realtimeDataPublisher.eventsByTable
    }
    
    private func handleConnectionStatusChange(_ status: RealtimeConnectionStatus) {
        connectionStatus = status
        
        switch status {
        case .connected:
            connectionStartTime = Date()
            connectionAttempts = 0
            reconnectionAttempts = 0
            stopReconnectionTimer()
            updateConnectionQuality()
            
        case .connecting:
            break
            
        case .disconnected:
            connectionUptime = 0
            updateConnectionQuality()
            
        case .error:
            updateConnectionQuality()
        }
    }
    
    private func handleSubscriptionStatusesChange(_ statuses: [String: RealtimeSubscriptionStatus]) {
        subscriptionStatuses = statuses
        
        activeSubscriptionCount = statuses.values.filter { status in
            if case .subscribed = status { return true }
            return false
        }.count
        
        errorSubscriptionCount = statuses.values.filter { status in
            if case .error = status { return true }
            return false
        }.count
        
        // Update subscription details
        for (subscriptionId, status) in statuses {
            if let index = subscriptionDetails.firstIndex(where: { $0.id == subscriptionId }) {
                subscriptionDetails[index].status = status
            }
        }
    }
    
    private func handleRealtimeEvent(_ event: RealtimeChangeEvent) async {
        await MainActor.run {
            // Update last event
            self.lastChangeEvent = event
            
            // Add to recent events (with limit)
            self.recentEvents.insert(event, at: 0)
            if self.recentEvents.count > self.maxRecentEvents {
                self.recentEvents = Array(self.recentEvents.prefix(self.maxRecentEvents))
            }
            
            // Group by table
            var tableEvents = self.eventsByTable[event.tableName] ?? []
            tableEvents.insert(event, at: 0)
            if tableEvents.count > 50 { // Limit per table
                tableEvents = Array(tableEvents.prefix(50))
            }
            self.eventsByTable[event.tableName] = tableEvents
            
            // Group by type
            var typeEvents = self.eventsByType[event.eventType] ?? []
            typeEvents.insert(event, at: 0)
            if typeEvents.count > 50 { // Limit per type
                typeEvents = Array(typeEvents.prefix(50))
            }
            self.eventsByType[event.eventType] = typeEvents
            
            // Update event timestamps for rate calculation
            self.eventTimestamps.append(event.timestamp)
            
            // Keep only last hour of timestamps
            let oneHourAgo = Date().addingTimeInterval(-3600)
            self.eventTimestamps = self.eventTimestamps.filter { $0 > oneHourAgo }
            
            // Update statistics
            self.updateEventStatistics()
            
            // Update subscription event counts
            if let subscriptionIndex = self.subscriptionDetails.firstIndex(where: { $0.tableName == event.tableName }) {
                self.subscriptionDetails[subscriptionIndex].eventCount += 1
            }
            
            // Call global event handlers
            for handler in self.globalEventHandlers {
                handler(event)
            }
        }
    }
    
    private func handleSyncModelEvent(_ event: RealtimeChangeEvent) async {
        // Handle events from sync models - could trigger sync operations
        // This would integrate with the sync system
        await handleRealtimeEvent(event)
    }
    
    private func handleAutoReconnection(for status: RealtimeConnectionStatus) {
        guard autoReconnectEnabled else { return }
        
        switch status {
        case .error, .disconnected:
            if reconnectionAttempts < maxReconnectionAttempts {
                startReconnectionTimer()
            }
        default:
            break
        }
    }
    
    private func handleNetworkReconnection() async {
        guard !isConnected && autoReconnectEnabled else { return }
        
        // Wait a bit for network to stabilize
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        if networkStatusPublisher.isConnected && authStatePublisher.isAuthenticated {
            await connect()
        }
    }
    
    private func startReconnectionTimer() {
        stopReconnectionTimer()
        
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: reconnectionDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task { [weak self] in
                guard let self = self else { return }
                
                await MainActor.run {
                    self.reconnectionAttempts += 1
                }
                
                if self.networkStatusPublisher.isConnected {
                    let isAuth = await self.authStatePublisher.isAuthenticated
                    if isAuth {
                        await self.connect()
                    }
                }
            }
        }
    }
    
    private func stopReconnectionTimer() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
    }
    
    private func updateConnectionQuality() {
        // Simple connection quality assessment
        if isConnected && !hasConnectionError {
            if errorSubscriptionCount == 0 {
                connectionQuality = .excellent
            } else if errorSubscriptionCount < activeSubscriptionCount / 2 {
                connectionQuality = .good
            } else {
                connectionQuality = .fair
            }
        } else if isConnecting {
            connectionQuality = .unknown
        } else {
            connectionQuality = .poor
        }
        
        // Update stability score
        if isConnected {
            let errorRatio = Double(errorSubscriptionCount) / max(Double(activeSubscriptionCount), 1.0)
            stabilityScore = max(0.0, 1.0 - errorRatio)
        } else {
            stabilityScore = 0.0
        }
    }
    
    private func updateEventStatistics() {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        let recentEventCount = eventTimestamps.filter { $0 > oneMinuteAgo }.count
        eventsPerMinute = Double(recentEventCount)
        
        // Update connection uptime
        if let startTime = connectionStartTime, isConnected {
            connectionUptime = now.timeIntervalSince(startTime)
        }
        
        // Create event statistics
        let totalEvents = recentEvents.count
        let eventTypesCounts = Dictionary(grouping: recentEvents) { $0.eventType }
            .mapValues { $0.count }
        let tablesCounts = Dictionary(grouping: recentEvents) { $0.tableName }
            .mapValues { $0.count }
        
        eventStatistics = RealtimeEventStatistics(
            totalEvents: totalEvents,
            eventsPerMinute: eventsPerMinute,
            eventsByType: eventTypesCounts,
            eventsByTable: tablesCounts,
            lastEventAt: lastChangeEvent?.timestamp
        )
    }
    
    // MARK: - Cleanup
    
    deinit {
        Task { @MainActor in
            self.disconnect()
        }
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

/// Connection quality levels
public enum ConnectionQuality: CaseIterable {
    case excellent
    case good
    case fair
    case poor
    case unknown
    
    public var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .unknown: return "Unknown"
        }
    }
    
    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
}

/// Subscription detail information
public struct SubscriptionDetail: Identifiable {
    public let id: String
    public let tableName: String
    public let eventTypes: [RealtimeEventType]
    public let subscribedAt: Date
    public var eventCount: Int
    public var status: RealtimeSubscriptionStatus = .subscribed
}

/// Event statistics for realtime events
public struct RealtimeEventStatistics {
    public let totalEvents: Int
    public let eventsPerMinute: Double
    public let eventsByType: [RealtimeEventType: Int]
    public let eventsByTable: [String: Int]
    public let lastEventAt: Date?
    
    public static let empty = RealtimeEventStatistics(
        totalEvents: 0,
        eventsPerMinute: 0,
        eventsByType: [:],
        eventsByTable: [:],
        lastEventAt: nil
    )
}

/// Data transfer statistics
public struct DataTransferStats {
    public let bytesReceived: Int64
    public let bytesSent: Int64
    public let messagesReceived: Int
    public let messagesSent: Int
    public let averageMessageSize: Double
    
    public static let empty = DataTransferStats(
        bytesReceived: 0,
        bytesSent: 0,
        messagesReceived: 0,
        messagesSent: 0,
        averageMessageSize: 0
    )
}

// MARK: - Extensions

extension RealtimeConnectionStatus {
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    public var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

extension RealtimeSubscriptionStatus {
    public var isActive: Bool {
        if case .subscribed = self { return true }
        return false
    }
    
    public var isError: Bool {
        if case .error = self { return true }
        return false
    }
}