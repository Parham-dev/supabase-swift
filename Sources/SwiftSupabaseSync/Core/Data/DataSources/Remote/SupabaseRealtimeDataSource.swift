//
//  SupabaseRealtimeDataSource.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.  
//

import Foundation
import Combine

/// Remote data source for Supabase real-time subscriptions
/// Handles real-time change notifications and live data synchronization
public final class SupabaseRealtimeDataSource: ObservableObject {
    
    // MARK: - Properties
    
    private let baseURL: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private var subscriptions: [String: RealtimeSubscription] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Publishers
    
    /// Publisher for real-time change events
    @Published public private(set) var lastChangeEvent: RealtimeChangeEvent?
    
    /// Publisher for connection status
    @Published public private(set) var connectionStatus: RealtimeConnectionStatus = .disconnected
    
    /// Publisher for subscription status
    @Published public private(set) var subscriptionStatuses: [String: RealtimeSubscriptionStatus] = [:]
    
    // MARK: - Event Subjects
    
    private let changeEventSubject = PassthroughSubject<RealtimeChangeEvent, Never>()
    private let connectionEventSubject = PassthroughSubject<RealtimeConnectionEvent, Never>()
    private let errorEventSubject = PassthroughSubject<RealtimeError, Never>()
    
    // MARK: - Initialization
    
    /// Initialize realtime data source
    /// - Parameter baseURL: Supabase project URL
    public init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    deinit {
        disconnect()
    }
    
    // MARK: - Connection Management
    
    /// Connect to realtime server
    /// - Throws: RealtimeDataSourceError
    public func connect() async throws {
        guard connectionStatus != .connected else { return }
        
        do {
            connectionStatus = .connecting
            
            // Create WebSocket URL
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
            components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
            components.path = "/realtime/v1/websocket"
            let realtimeURL = components.url!
            
            // Create WebSocket connection
            let session = URLSession.shared
            webSocketTask = session.webSocketTask(with: URLRequest(url: realtimeURL))
            
            // Start listening for messages
            startListening()
            
            // Resume the connection
            webSocketTask?.resume()
            
            await MainActor.run {
                connectionStatus = .connected
                connectionEventSubject.send(.connected)
            }
            
        } catch {
            await MainActor.run {
                connectionStatus = .error(error.localizedDescription)
                connectionEventSubject.send(.error(error.localizedDescription))
            }
            throw RealtimeDataSourceError.connectionFailed("Failed to connect: \(error.localizedDescription)")
        }
    }
    
    /// Disconnect from realtime server
    public func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        subscriptions.removeAll()
        subscriptionStatuses.removeAll()
        
        connectionStatus = .disconnected
        connectionEventSubject.send(.disconnected)
    }
    
    /// Check if connected to realtime server
    /// - Returns: Connection status
    public var isConnected: Bool {
        return connectionStatus == .connected
    }
    
    // MARK: - Table Subscriptions
    
    /// Subscribe to changes on a specific table
    /// - Parameters:
    ///   - tableName: Database table name to monitor
    ///   - events: Specific events to listen for (default: all)
    ///   - onEvent: Event handler
    /// - Returns: Subscription identifier
    /// - Throws: RealtimeDataSourceError
    @discardableResult
    public func subscribeToTable(
        _ tableName: String,
        events: Set<RealtimeEventType> = [.insert, .update, .delete],
        onEvent: @escaping (RealtimeChangeEvent) -> Void = { _ in }
    ) async throws -> String {
        let subscriptionId = "table_\(tableName)"
        
        guard isConnected else {
            throw RealtimeDataSourceError.subscriptionFailed("Not connected to realtime server")
        }
        
        do {
            // Create subscription message
            let subscriptionMessage = RealtimeMessage(
                event: "phx_join",
                topic: "realtime:\(tableName)",
                payload: [
                    "config": [
                        "postgres_changes": [
                            [
                                "event": "*",
                                "schema": "public",
                                "table": tableName
                            ]
                        ]
                    ]
                ],
                ref: subscriptionId
            )
            
            // Send subscription message
            try await sendMessage(subscriptionMessage)
            
            // Store subscription
            let subscription = RealtimeSubscription(
                id: subscriptionId,
                tableName: tableName,
                events: events,
                onEvent: onEvent
            )
            
            subscriptions[subscriptionId] = subscription
            subscriptionStatuses[subscriptionId] = .subscribed
            
            return subscriptionId
            
        } catch {
            subscriptionStatuses[subscriptionId] = .error(error.localizedDescription)
            throw RealtimeDataSourceError.subscriptionFailed("Failed to subscribe to table \(tableName): \(error.localizedDescription)")
        }
    }
    
    /// Unsubscribe from a specific subscription
    /// - Parameter subscriptionId: Subscription identifier to remove
    public func unsubscribe(from subscriptionId: String) {
        guard let subscription = subscriptions[subscriptionId] else {
            return
        }
        
        // Send unsubscribe message
        let unsubscribeMessage = RealtimeMessage(
            event: "phx_leave",
            topic: "realtime:\(subscription.tableName)",
            payload: [:],
            ref: subscriptionId
        )
        
        Task {
            try? await sendMessage(unsubscribeMessage)
        }
        
        subscriptions.removeValue(forKey: subscriptionId)
        subscriptionStatuses.removeValue(forKey: subscriptionId)
    }
    
    /// Unsubscribe from all table subscriptions
    public func unsubscribeFromAll() {
        for subscriptionId in subscriptions.keys {
            unsubscribe(from: subscriptionId)
        }
    }
    
    // MARK: - Publishers & Streams
    
    /// Publisher for real-time change events
    public var changeEventPublisher: AnyPublisher<RealtimeChangeEvent, Never> {
        changeEventSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for connection events
    public var connectionEventPublisher: AnyPublisher<RealtimeConnectionEvent, Never> {
        connectionEventSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for error events
    public var errorEventPublisher: AnyPublisher<RealtimeError, Never> {
        errorEventSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for changes on a specific table
    /// - Parameter tableName: Table to monitor
    /// - Returns: Publisher emitting changes for the table
    public func changesPublisher(for tableName: String) -> AnyPublisher<RealtimeChangeEvent, Never> {
        changeEventPublisher
            .filter { $0.tableName == tableName }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func startListening() {
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                Task { @MainActor in
                    self?.handleWebSocketMessage(message)
                }
                self?.receiveMessage() // Continue listening
                
            case .failure(let error):
                Task { @MainActor in
                    self?.connectionStatus = .error(error.localizedDescription)
                    self?.connectionEventSubject.send(.error(error.localizedDescription))
                    self?.errorEventSubject.send(.connectionError(error.localizedDescription))
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let realtimeMessage = try? JSONDecoder().decode(RealtimeMessage.self, from: data) else {
                return
            }
            
            processRealtimeMessage(realtimeMessage)
            
        case .data(let data):
            guard let realtimeMessage = try? JSONDecoder().decode(RealtimeMessage.self, from: data) else {
                return
            }
            
            processRealtimeMessage(realtimeMessage)
            
        @unknown default:
            break
        }
    }
    
    private func processRealtimeMessage(_ message: RealtimeMessage) {
        // Handle different message types
        switch message.event {
        case "postgres_changes":
            if let changeEvent = convertToChangeEvent(message) {
                lastChangeEvent = changeEvent
                changeEventSubject.send(changeEvent)
                
                // Notify specific subscription handlers
                for subscription in subscriptions.values {
                    if changeEvent.tableName == subscription.tableName {
                        subscription.onEvent(changeEvent)
                    }
                }
            }
            
        case "phx_reply":
            // Handle subscription confirmations
            if let ref = message.ref,
               subscriptions[ref] != nil {
                subscriptionStatuses[ref] = .subscribed
            }
            
        default:
            break
        }
    }
    
    private func convertToChangeEvent(_ message: RealtimeMessage) -> RealtimeChangeEvent? {
        guard let payload = message.payload["postgres_changes"] as? [String: Any],
              let eventTypeString = payload["eventType"] as? String,
              let eventType = RealtimeEventType(rawValue: eventTypeString.uppercased()),
              let tableName = payload["table"] as? String else {
            return nil
        }
        
        // Extract record ID
        let recordID: UUID?
        if let record = payload["new"] as? [String: Any],
           let syncIDString = record["sync_id"] as? String {
            recordID = UUID(uuidString: syncIDString)
        } else if let record = payload["old"] as? [String: Any],
                  let syncIDString = record["sync_id"] as? String {
            recordID = UUID(uuidString: syncIDString)
        } else {
            recordID = nil
        }
        
        return RealtimeChangeEvent(
            eventType: eventType,
            tableName: tableName,
            recordID: recordID,
            oldRecord: payload["old"] as? [String: Any],
            newRecord: payload["new"] as? [String: Any],
            timestamp: Date(),
            metadata: message.payload
        )
    }
    
    private func sendMessage(_ message: RealtimeMessage) async throws {
        guard let webSocketTask = webSocketTask else {
            throw RealtimeDataSourceError.connectionFailed("WebSocket not connected")
        }
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let messageString = String(data: data, encoding: .utf8) ?? ""
        
        try await webSocketTask.send(.string(messageString))
    }
}

// MARK: - Supporting Types

public enum RealtimeConnectionStatus: Equatable, CustomStringConvertible {
    case disconnected
    case connecting
    case connected
    case error(String)
    
    public var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

public enum RealtimeSubscriptionStatus: Equatable, CustomStringConvertible {
    case subscribed
    case unsubscribed
    case error(String)
    
    public var description: String {
        switch self {
        case .subscribed:
            return "Subscribed"
        case .unsubscribed:
            return "Unsubscribed"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

public enum RealtimeEventType: String, CaseIterable, Codable {
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
    case truncate = "TRUNCATE"
}

public struct RealtimeChangeEvent: Identifiable, Equatable {
    public let id = UUID()
    public let eventType: RealtimeEventType
    public let tableName: String
    public let recordID: UUID?
    public let oldRecord: [String: Any]?
    public let newRecord: [String: Any]?
    public let timestamp: Date
    public let metadata: [String: Any]
    
    public init(
        eventType: RealtimeEventType,
        tableName: String,
        recordID: UUID? = nil,
        oldRecord: [String: Any]? = nil,
        newRecord: [String: Any]? = nil,
        timestamp: Date = Date(),
        metadata: [String: Any] = [:]
    ) {
        self.eventType = eventType
        self.tableName = tableName
        self.recordID = recordID
        self.oldRecord = oldRecord
        self.newRecord = newRecord
        self.timestamp = timestamp
        self.metadata = metadata
    }
    
    public static func == (lhs: RealtimeChangeEvent, rhs: RealtimeChangeEvent) -> Bool {
        return lhs.id == rhs.id
    }
    
    /// Get the primary record data based on event type
    public var primaryRecord: [String: Any]? {
        switch eventType {
        case .insert, .update:
            return newRecord
        case .delete:
            return oldRecord
        case .truncate:
            return nil
        }
    }
    
    /// Check if this event represents a sync-relevant change
    public var isSyncRelevant: Bool {
        guard let record = primaryRecord else { return false }
        
        // Check if record has sync metadata
        return record["sync_id"] != nil && record["last_modified"] != nil
    }
}

public enum RealtimeConnectionEvent {
    case connected
    case disconnected
    case error(String)
}

public enum RealtimeError: Error, LocalizedError, Equatable {
    case connectionError(String)
    case subscriptionError(String)
    case messageError(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .connectionError(let message):
            return "Connection error: \(message)"
        case .subscriptionError(let message):
            return "Subscription error: \(message)"
        case .messageError(let message):
            return "Message error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

public enum RealtimeDataSourceError: Error, LocalizedError, Equatable {
    case connectionFailed(String)
    case subscriptionFailed(String)
    case messageSendFailed(String)
    case invalidConfiguration(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .subscriptionFailed(let message):
            return "Subscription failed: \(message)"
        case .messageSendFailed(let message):
            return "Message send failed: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Internal Types

private struct RealtimeSubscription {
    let id: String
    let tableName: String
    let events: Set<RealtimeEventType>
    let onEvent: (RealtimeChangeEvent) -> Void
}

private struct RealtimeMessage: Codable {
    let event: String
    let topic: String
    let payload: [String: Any]
    let ref: String?
    
    init(event: String, topic: String, payload: [String: Any], ref: String? = nil) {
        self.event = event
        self.topic = topic
        self.payload = payload
        self.ref = ref
    }
    
    enum CodingKeys: String, CodingKey {
        case event, topic, payload, ref
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        event = try container.decode(String.self, forKey: .event)
        topic = try container.decode(String.self, forKey: .topic)
        ref = try container.decodeIfPresent(String.self, forKey: .ref)
        
        // Decode payload as JSON
        if let payloadData = try container.decodeIfPresent(Data.self, forKey: .payload) {
            payload = (try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]) ?? [:]
        } else {
            payload = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        try container.encode(topic, forKey: .topic)
        try container.encodeIfPresent(ref, forKey: .ref)
        
        // Encode payload as JSON
        if !payload.isEmpty {
            let payloadData = try JSONSerialization.data(withJSONObject: payload)
            try container.encode(payloadData, forKey: .payload)
        }
    }
}

// MARK: - Convenience Extensions

public extension SupabaseRealtimeDataSource {
    
    /// Subscribe to sync changes for multiple tables
    /// - Parameters:
    ///   - tableNames: Array of table names to monitor
    ///   - onEvent: Event handler
    /// - Returns: Array of subscription identifiers
    func subscribeToTables(
        _ tableNames: [String],
        onEvent: @escaping (RealtimeChangeEvent) -> Void = { _ in }
    ) async throws -> [String] {
        var subscriptionIds: [String] = []
        
        for tableName in tableNames {
            do {
                let subscriptionId = try await subscribeToTable(tableName, onEvent: onEvent)
                subscriptionIds.append(subscriptionId)
            } catch {
                // Log error but continue with other tables
                continue
            }
        }
        
        return subscriptionIds
    }
    
    /// Get all active subscriptions
    /// - Returns: Dictionary of subscription IDs and their status
    var activeSubscriptions: [String: RealtimeSubscriptionStatus] {
        return subscriptionStatuses
    }
    
    /// Check if subscribed to a specific table
    /// - Parameter tableName: Table name to check
    /// - Returns: Whether subscribed to the table
    func isSubscribed(to tableName: String) -> Bool {
        let subscriptionId = "table_\(tableName)"
        return subscriptionStatuses[subscriptionId] == .subscribed
    }
}