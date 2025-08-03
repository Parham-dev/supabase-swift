//
//  SharedTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Sync Types

public enum SyncFrequency: Codable, Equatable, Hashable {
    case manual
    case automatic
    case interval(TimeInterval)
    case onChange
    
    /// Whether sync should occur automatically
    public var isAutomatic: Bool {
        switch self {
        case .manual:
            return false
        case .automatic, .interval, .onChange:
            return true
        }
    }
    
    /// Get the sync interval in seconds (nil for non-interval types)
    public var intervalSeconds: TimeInterval? {
        switch self {
        case .interval(let seconds):
            return seconds
        case .manual, .automatic, .onChange:
            return nil
        }
    }
}

public enum ConflictResolutionStrategy: String, Codable, Equatable, Hashable {
    case lastWriteWins = "last_write_wins"
    case firstWriteWins = "first_write_wins"
    case manual = "manual"
    case localWins = "local_wins"
    case remoteWins = "remote_wins"
    
    /// Whether this strategy requires user intervention
    public var requiresUserIntervention: Bool {
        return self == .manual
    }
    
    /// Description of the strategy
    public var description: String {
        switch self {
        case .lastWriteWins:
            return "Most recently modified version wins"
        case .firstWriteWins:
            return "First created version wins"
        case .manual:
            return "User decides conflict resolution"
        case .localWins:
            return "Local version always wins"
        case .remoteWins:
            return "Remote version always wins"
        }
    }
}

// MARK: - Codable Extensions

extension SyncFrequency {
    enum CodingKeys: String, CodingKey {
        case type, interval
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "manual":
            self = .manual
        case "automatic":
            self = .automatic
        case "onChange":
            self = .onChange
        case "interval":
            let interval = try container.decode(TimeInterval.self, forKey: .interval)
            self = .interval(interval)
        default:
            self = .automatic
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .manual:
            try container.encode("manual", forKey: .type)
        case .automatic:
            try container.encode("automatic", forKey: .type)
        case .onChange:
            try container.encode("onChange", forKey: .type)
        case .interval(let seconds):
            try container.encode("interval", forKey: .type)
            try container.encode(seconds, forKey: .interval)
        }
    }
}
