//
//  RealtimeTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Connection Status

/// Status of the realtime connection
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

/// Status of a realtime subscription
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

// MARK: - Event Types

/// Types of database events that can be monitored
public enum RealtimeEventType: String, CaseIterable, Codable {
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
    case truncate = "TRUNCATE"
}

/// Represents a real-time change event from the database
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

/// Connection events for the realtime system
public enum RealtimeConnectionEvent {
    case connected
    case disconnected
    case error(String)
}

// MARK: - Error Types

/// Errors that can occur in the realtime system
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

/// Errors specific to the realtime data source
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