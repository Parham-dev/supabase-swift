//
//  RealtimeDataPublisher.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Combine
import SwiftUI

/// Reactive publisher that wraps SupabaseRealtimeDataSource for seamless SwiftUI integration
/// Provides clean, observable access to real-time data changes, connection status, and subscription management
@MainActor
public final class RealtimeDataPublisher: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Last realtime change event received
    @Published public private(set) var lastChangeEvent: RealtimeChangeEvent?
    
    /// Current connection status
    @Published public private(set) var connectionStatus: RealtimeConnectionStatus
    
    /// Status of all active subscriptions
    @Published public private(set) var subscriptionStatuses: [String: RealtimeSubscriptionStatus]
    
    // MARK: - Derived Published Properties
    
    /// Whether connected to realtime server
    @Published public private(set) var isConnected: Bool = false
    
    /// Whether connection is in progress
    @Published public private(set) var isConnecting: Bool = false
    
    /// Whether there are any connection errors
    @Published public private(set) var hasConnectionError: Bool = false
    
    /// User-friendly connection status description
    @Published public private(set) var statusDescription: String = "Disconnected"
    
    /// Number of active subscriptions
    @Published public private(set) var activeSubscriptionCount: Int = 0
    
    /// Number of subscriptions with errors
    @Published public private(set) var errorSubscriptionCount: Int = 0
    
    /// Recent change events (last 50)
    @Published public private(set) var recentEvents: [RealtimeChangeEvent] = []
    
    /// Events grouped by table name
    @Published public private(set) var eventsByTable: [String: [RealtimeChangeEvent]] = [:]
    
    // MARK: - Dependencies
    
    private let realtimeDataSource: SupabaseRealtimeDataSource
    private var cancellables = Set<AnyCancellable>()
    private let maxRecentEvents = 50
    
    // MARK: - Initialization
    
    public init(realtimeDataSource: SupabaseRealtimeDataSource) {
        self.realtimeDataSource = realtimeDataSource
        
        // Initialize with current values
        self.lastChangeEvent = realtimeDataSource.lastChangeEvent
        self.connectionStatus = realtimeDataSource.connectionStatus
        self.subscriptionStatuses = realtimeDataSource.subscriptionStatuses
        
        // Calculate derived properties
        updateDerivedProperties()
        
        // Setup reactive bindings
        setupPublisherBindings()
    }
    
    // MARK: - Public Computed Properties
    
    /// Whether realtime is available for use
    public var isAvailable: Bool {
        isConnected && !hasConnectionError
    }
    
    /// Whether all subscriptions are healthy
    public var allSubscriptionsHealthy: Bool {
        errorSubscriptionCount == 0
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
        guard let lastEvent = lastChangeEvent else { return nil }
        return Date().timeIntervalSince(lastEvent.timestamp)
    }
    
    /// Formatted time since last event
    public var formattedTimeSinceLastEvent: String {
        guard let timeSince = timeSinceLastEvent else {
            return "No events"
        }
        
        if timeSince < 60 {
            return "Just now"
        } else if timeSince < 3600 {
            let minutes = Int(timeSince / 60)
            return "\(minutes)m ago"
        } else if timeSince < 86400 {
            let hours = Int(timeSince / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(timeSince / 86400)
            return "\(days)d ago"
        }
    }
    
    // MARK: - Connection Management
    
    /// Connect to realtime server
    public func connect() async {
        do {
            try await realtimeDataSource.connect()
        } catch {
            // Error handling is managed by SupabaseRealtimeDataSource's published properties
            // The UI will react to connection status changes
        }
    }
    
    /// Disconnect from realtime server
    public func disconnect() {
        realtimeDataSource.disconnect()
    }
    
    /// Reconnect to realtime server
    public func reconnect() async {
        disconnect()
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        await connect()
    }
    
    // MARK: - Subscription Management
    
    /// Subscribe to table changes
    /// - Parameters:
    ///   - tableName: Name of the table to monitor
    ///   - eventTypes: Types of events to monitor (defaults to all)
    ///   - onEvent: Event handler callback
    /// - Returns: Subscription identifier
    public func subscribe(
        to tableName: String,
        for eventTypes: [RealtimeEventType] = RealtimeEventType.allCases,
        onEvent: @escaping (RealtimeChangeEvent) -> Void = { _ in }
    ) async throws -> String {
        return try await realtimeDataSource.subscribeToTable(
            tableName,
            events: Set(eventTypes),
            onEvent: onEvent
        )
    }
    
    /// Unsubscribe from table changes
    /// - Parameter subscriptionId: Subscription identifier to remove
    public func unsubscribe(from subscriptionId: String) {
        realtimeDataSource.unsubscribe(from: subscriptionId)
    }
    
    /// Get all active subscription IDs
    public var activeSubscriptions: [String] {
        subscriptionStatuses.compactMap { key, status in
            status == .subscribed ? key : nil
        }
    }
    
    /// Get subscriptions for a specific table
    /// - Parameter tableName: Name of the table
    /// - Returns: Active subscription IDs for the table
    public func subscriptions(for tableName: String) -> [String] {
        // This would require additional tracking in the data source
        // For now, return empty array as placeholder
        return []
    }
    
    // MARK: - Event Filtering and Querying
    
    /// Get events for a specific table
    /// - Parameter tableName: Name of the table
    /// - Returns: Events for the specified table
    public func events(for tableName: String) -> [RealtimeChangeEvent] {
        return eventsByTable[tableName] ?? []
    }
    
    /// Get events of a specific type
    /// - Parameter eventType: Type of events to filter
    /// - Returns: Events of the specified type
    public func events(ofType eventType: RealtimeEventType) -> [RealtimeChangeEvent] {
        return recentEvents.filter { $0.eventType == eventType }
    }
    
    /// Get recent events for a specific record
    /// - Parameter recordId: ID of the record
    /// - Returns: Events for the specified record
    public func events(for recordId: UUID) -> [RealtimeChangeEvent] {
        return recentEvents.filter { $0.recordID == recordId }
    }
    
    /// Clear event history
    public func clearEventHistory() {
        recentEvents.removeAll()
        eventsByTable.removeAll()
    }
    
    /// Get event statistics
    public var eventStatistics: EventStatistics {
        let totalEvents = recentEvents.count
        let eventsByType = Dictionary(grouping: recentEvents) { $0.eventType }
        let eventCounts = eventsByType.mapValues { $0.count }
        
        return EventStatistics(
            totalEvents: totalEvents,
            eventsByType: eventCounts,
            eventsByTable: eventsByTable.mapValues { $0.count },
            oldestEvent: recentEvents.last?.timestamp,
            newestEvent: recentEvents.first?.timestamp
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupPublisherBindings() {
        // Bind SupabaseRealtimeDataSource's published properties to our published properties
        realtimeDataSource.$lastChangeEvent
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.lastChangeEvent = event
                
                // Add to recent events if we have a new event
                if let event = event {
                    self?.addToRecentEvents(event)
                }
            }
            .store(in: &cancellables)
        
        realtimeDataSource.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        realtimeDataSource.$subscriptionStatuses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] statuses in
                self?.subscriptionStatuses = statuses
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
    }
    
    private func updateDerivedProperties() {
        // Update connection state
        isConnected = connectionStatus == .connected
        isConnecting = connectionStatus == .connecting
        
        // Update error state
        if case .error = connectionStatus {
            hasConnectionError = true
        } else {
            hasConnectionError = false
        }
        
        // Update status description
        statusDescription = connectionStatus.description
        
        // Update subscription counts
        activeSubscriptionCount = subscriptionStatuses.values.filter { $0 == .subscribed }.count
        errorSubscriptionCount = subscriptionStatuses.values.compactMap {
            if case .error = $0 { return 1 } else { return nil }
        }.count
    }
    
    private func addToRecentEvents(_ event: RealtimeChangeEvent) {
        // Add to recent events (newest first)
        recentEvents.insert(event, at: 0)
        
        // Limit recent events
        if recentEvents.count > maxRecentEvents {
            recentEvents = Array(recentEvents.prefix(maxRecentEvents))
        }
        
        // Group by table
        if eventsByTable[event.tableName] == nil {
            eventsByTable[event.tableName] = []
        }
        eventsByTable[event.tableName]?.insert(event, at: 0)
        
        // Limit events per table (keep last 20 per table)
        if let tableEvents = eventsByTable[event.tableName], tableEvents.count > 20 {
            eventsByTable[event.tableName] = Array(tableEvents.prefix(20))
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        realtimeDataSource.disconnect()
        cancellables.removeAll()
    }
}

// MARK: - SwiftUI Convenience Extensions

public extension RealtimeDataPublisher {
    
    /// Connection status indicator view
    var statusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            
            Text(statusDescription)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
    
    /// Simple connection indicator
    var connectionIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }
    
    /// Subscription count badge
    @ViewBuilder
    var subscriptionBadge: some View {
        if activeSubscriptionCount > 0 {
            Text("\(activeSubscriptionCount)")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
    }
    
    /// Error indicator for subscription issues
    @ViewBuilder
    var errorIndicator: some View {
        if errorSubscriptionCount > 0 {
            HStack(spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("\(errorSubscriptionCount)")
            }
            .font(.caption2)
            .foregroundColor(.orange)
        }
    }
    
    /// Event type icon
    func eventTypeIcon(for eventType: RealtimeEventType) -> String {
        switch eventType {
        case .insert:
            return "plus.circle.fill"
        case .update:
            return "pencil.circle.fill"
        case .delete:
            return "minus.circle.fill"
        case .truncate:
            return "trash.circle.fill"
        }
    }
    
    /// Event type color
    func eventTypeColor(for eventType: RealtimeEventType) -> Color {
        switch eventType {
        case .insert:
            return .green
        case .update:
            return .blue
        case .delete:
            return .red
        case .truncate:
            return .orange
        }
    }
}

// MARK: - Combine Publishers

public extension RealtimeDataPublisher {
    
    /// Publisher that emits when connection status changes
    var connectionStatusPublisher: AnyPublisher<RealtimeConnectionStatus, Never> {
        $connectionStatus
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when new events are received
    var changeEventPublisher: AnyPublisher<RealtimeChangeEvent, Never> {
        $lastChangeEvent
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits events for a specific table
    func eventPublisher(for tableName: String) -> AnyPublisher<RealtimeChangeEvent, Never> {
        changeEventPublisher
            .filter { $0.tableName == tableName }
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits events of a specific type
    func eventPublisher(for eventType: RealtimeEventType) -> AnyPublisher<RealtimeChangeEvent, Never> {
        changeEventPublisher
            .filter { $0.eventType == eventType }
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when subscription statuses change
    var subscriptionStatusPublisher: AnyPublisher<[String: RealtimeSubscriptionStatus], Never> {
        $subscriptionStatuses
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when connection becomes available/unavailable
    var availabilityPublisher: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest(
            $isConnected,
            $hasConnectionError
        )
        .map { isConnected, hasError in
            isConnected && !hasError
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Types

/// Statistics about realtime events
public struct EventStatistics {
    public let totalEvents: Int
    public let eventsByType: [RealtimeEventType: Int]
    public let eventsByTable: [String: Int]
    public let oldestEvent: Date?
    public let newestEvent: Date?
    
    /// Whether there are any events
    public var hasEvents: Bool {
        totalEvents > 0
    }
    
    /// Most active table
    public var mostActiveTable: String? {
        eventsByTable.max(by: { $0.value < $1.value })?.key
    }
    
    /// Most common event type
    public var mostCommonEventType: RealtimeEventType? {
        eventsByType.max(by: { $0.value < $1.value })?.key
    }
    
    /// Time span of events
    public var eventTimeSpan: TimeInterval? {
        guard let oldest = oldestEvent, let newest = newestEvent else { return nil }
        return newest.timeIntervalSince(oldest)
    }
}

/// Connection health assessment
public enum ConnectionHealth: CaseIterable {
    case excellent
    case good
    case fair
    case poor
    case offline
    
    public var description: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .offline: return "Offline"
        }
    }
    
    public var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .offline: return .red
        }
    }
}