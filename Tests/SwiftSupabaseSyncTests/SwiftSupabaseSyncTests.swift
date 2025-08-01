//
//  SwiftSupabaseSyncTests.swift
//  SwiftSupabaseSyncTests
//
//  Created by Testing Framework on 01/08/2025.
//

import XCTest
@testable import SwiftSupabaseSync

final class SwiftSupabaseSyncTests: XCTestCase {
    
    func testHelloMethod() {
        // Given
        let sync = SwiftSupabaseSync()
        
        // When
        let result = sync.hello()
        
        // Then
        XCTAssertEqual(result, "Hello from SwiftSupabaseSync!")
    }
    
    func testVersion() {
        // Then
        XCTAssertEqual(SwiftSupabaseSync.version, "1.0.0")
    }
    
    func testInitialization() {
        // When
        let sync = SwiftSupabaseSync()
        
        // Then
        // Just check it creates an instance (this is a struct, so it can't be nil)
        let _ = sync // Use the sync variable to avoid unused variable warning
    }
}