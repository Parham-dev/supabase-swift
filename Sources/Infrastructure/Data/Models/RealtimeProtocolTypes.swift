//
//  RealtimeProtocolTypes.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Internal Subscription Management

/// Internal representation of a realtime subscription
internal struct RealtimeSubscription {
    let id: String
    let tableName: String
    let events: Set<RealtimeEventType>
    let onEvent: (RealtimeChangeEvent) -> Void
}

// MARK: - Protocol Message Types

/// Internal message structure for realtime protocol communication
internal struct RealtimeMessage: Codable {
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