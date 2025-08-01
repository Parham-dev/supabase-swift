//
//  SharedTypesTests.swift
//  SwiftSupabaseSyncTests
//
//  Created by Testing Framework on 01/08/2025.
//

import XCTest
@testable import SwiftSupabaseSync

final class SharedTypesTests: XCTestCase {
    
    // MARK: - SyncFrequency Tests
    
    func testSyncFrequencyIsAutomatic() {
        XCTAssertFalse(SyncFrequency.manual.isAutomatic)
        XCTAssertTrue(SyncFrequency.automatic.isAutomatic)
        XCTAssertTrue(SyncFrequency.interval(300).isAutomatic)
        XCTAssertTrue(SyncFrequency.onChange.isAutomatic)
    }
    
    func testSyncFrequencyIntervalSeconds() {
        XCTAssertNil(SyncFrequency.manual.intervalSeconds)
        XCTAssertNil(SyncFrequency.automatic.intervalSeconds)
        XCTAssertNil(SyncFrequency.onChange.intervalSeconds)
        XCTAssertEqual(SyncFrequency.interval(300).intervalSeconds, 300)
        XCTAssertEqual(SyncFrequency.interval(60).intervalSeconds, 60)
    }
    
    func testSyncFrequencyEquality() {
        XCTAssertEqual(SyncFrequency.manual, SyncFrequency.manual)
        XCTAssertEqual(SyncFrequency.automatic, SyncFrequency.automatic)
        XCTAssertEqual(SyncFrequency.onChange, SyncFrequency.onChange)
        XCTAssertEqual(SyncFrequency.interval(300), SyncFrequency.interval(300))
        
        XCTAssertNotEqual(SyncFrequency.manual, SyncFrequency.automatic)
        XCTAssertNotEqual(SyncFrequency.interval(300), SyncFrequency.interval(600))
    }
    
    func testSyncFrequencyCodable() throws {
        // Test encoding and decoding for manual
        let manual = SyncFrequency.manual
        let manualData = try JSONEncoder().encode(manual)
        let decodedManual = try JSONDecoder().decode(SyncFrequency.self, from: manualData)
        XCTAssertEqual(manual, decodedManual)
        
        // Test encoding and decoding for automatic
        let automatic = SyncFrequency.automatic
        let automaticData = try JSONEncoder().encode(automatic)
        let decodedAutomatic = try JSONDecoder().decode(SyncFrequency.self, from: automaticData)
        XCTAssertEqual(automatic, decodedAutomatic)
        
        // Test encoding and decoding for onChange
        let onChange = SyncFrequency.onChange
        let onChangeData = try JSONEncoder().encode(onChange)
        let decodedOnChange = try JSONDecoder().decode(SyncFrequency.self, from: onChangeData)
        XCTAssertEqual(onChange, decodedOnChange)
        
        // Test encoding and decoding for interval
        let interval = SyncFrequency.interval(300)
        let intervalData = try JSONEncoder().encode(interval)
        let decodedInterval = try JSONDecoder().decode(SyncFrequency.self, from: intervalData)
        XCTAssertEqual(interval, decodedInterval)
    }
    
    func testSyncFrequencyInvalidDecodingFallback() throws {
        // Test that invalid types fall back to automatic
        let invalidJSON = """
        {"type": "invalid_type"}
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(SyncFrequency.self, from: invalidJSON)
        XCTAssertEqual(decoded, .automatic)
    }
    
    // MARK: - ConflictResolutionStrategy Tests
    
    func testConflictResolutionStrategyRequiresUserIntervention() {
        XCTAssertFalse(ConflictResolutionStrategy.lastWriteWins.requiresUserIntervention)
        XCTAssertFalse(ConflictResolutionStrategy.firstWriteWins.requiresUserIntervention)
        XCTAssertTrue(ConflictResolutionStrategy.manual.requiresUserIntervention)
        XCTAssertFalse(ConflictResolutionStrategy.localWins.requiresUserIntervention)
        XCTAssertFalse(ConflictResolutionStrategy.remoteWins.requiresUserIntervention)
    }
    
    func testConflictResolutionStrategyDescription() {
        XCTAssertEqual(
            ConflictResolutionStrategy.lastWriteWins.description,
            "Most recently modified version wins"
        )
        XCTAssertEqual(
            ConflictResolutionStrategy.firstWriteWins.description,
            "First created version wins"
        )
        XCTAssertEqual(
            ConflictResolutionStrategy.manual.description,
            "User decides conflict resolution"
        )
        XCTAssertEqual(
            ConflictResolutionStrategy.localWins.description,
            "Local version always wins"
        )
        XCTAssertEqual(
            ConflictResolutionStrategy.remoteWins.description,
            "Remote version always wins"
        )
    }
    
    func testConflictResolutionStrategyRawValues() {
        XCTAssertEqual(ConflictResolutionStrategy.lastWriteWins.rawValue, "last_write_wins")
        XCTAssertEqual(ConflictResolutionStrategy.firstWriteWins.rawValue, "first_write_wins")
        XCTAssertEqual(ConflictResolutionStrategy.manual.rawValue, "manual")
        XCTAssertEqual(ConflictResolutionStrategy.localWins.rawValue, "local_wins")
        XCTAssertEqual(ConflictResolutionStrategy.remoteWins.rawValue, "remote_wins")
    }
    
    func testConflictResolutionStrategyInitFromRawValue() {
        XCTAssertEqual(
            ConflictResolutionStrategy(rawValue: "last_write_wins"),
            .lastWriteWins
        )
        XCTAssertEqual(
            ConflictResolutionStrategy(rawValue: "first_write_wins"),
            .firstWriteWins
        )
        XCTAssertEqual(
            ConflictResolutionStrategy(rawValue: "manual"),
            .manual
        )
        XCTAssertEqual(
            ConflictResolutionStrategy(rawValue: "local_wins"),
            .localWins
        )
        XCTAssertEqual(
            ConflictResolutionStrategy(rawValue: "remote_wins"),
            .remoteWins
        )
        
        // Test invalid raw value
        XCTAssertNil(ConflictResolutionStrategy(rawValue: "invalid_strategy"))
    }
    
    func testConflictResolutionStrategyCodable() throws {
        let strategies: [ConflictResolutionStrategy] = [
            .lastWriteWins,
            .firstWriteWins,
            .manual,
            .localWins,
            .remoteWins
        ]
        
        for strategy in strategies {
            let encoded = try JSONEncoder().encode(strategy)
            let decoded = try JSONDecoder().decode(ConflictResolutionStrategy.self, from: encoded)
            XCTAssertEqual(strategy, decoded)
        }
    }
    
    func testConflictResolutionStrategyEquality() {
        XCTAssertEqual(ConflictResolutionStrategy.lastWriteWins, ConflictResolutionStrategy.lastWriteWins)
        XCTAssertEqual(ConflictResolutionStrategy.manual, ConflictResolutionStrategy.manual)
        
        XCTAssertNotEqual(ConflictResolutionStrategy.lastWriteWins, ConflictResolutionStrategy.firstWriteWins)
        XCTAssertNotEqual(ConflictResolutionStrategy.localWins, ConflictResolutionStrategy.remoteWins)
    }
    
    func testConflictResolutionStrategyHashable() {
        let set: Set<ConflictResolutionStrategy> = [
            .lastWriteWins,
            .firstWriteWins,
            .manual,
            .localWins,
            .remoteWins,
            .lastWriteWins // Duplicate
        ]
        
        // Set should contain only 5 unique values
        XCTAssertEqual(set.count, 5)
        XCTAssertTrue(set.contains(.lastWriteWins))
        XCTAssertTrue(set.contains(.manual))
        XCTAssertTrue(set.contains(.remoteWins))
    }
}