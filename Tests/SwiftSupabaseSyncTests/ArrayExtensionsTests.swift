//
//  ArrayExtensionsTests.swift
//  SwiftSupabaseSyncTests
//
//  Created by Testing Framework on 01/08/2025.
//

import XCTest
@testable import SwiftSupabaseSync

final class ArrayExtensionsTests: XCTestCase {
    
    func testChunkedExactDivision() {
        // Given
        let array = [1, 2, 3, 4, 5, 6]
        let chunkSize = 2
        
        // When
        let chunks = array.chunked(into: chunkSize)
        
        // Then
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2])
        XCTAssertEqual(chunks[1], [3, 4])
        XCTAssertEqual(chunks[2], [5, 6])
    }
    
    func testChunkedWithRemainder() {
        // Given
        let array = [1, 2, 3, 4, 5]
        let chunkSize = 2
        
        // When
        let chunks = array.chunked(into: chunkSize)
        
        // Then
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2])
        XCTAssertEqual(chunks[1], [3, 4])
        XCTAssertEqual(chunks[2], [5])
    }
    
    func testChunkedEmptyArray() {
        // Given
        let array: [Int] = []
        let chunkSize = 3
        
        // When
        let chunks = array.chunked(into: chunkSize)
        
        // Then
        XCTAssertTrue(chunks.isEmpty)
    }
    
    func testChunkedArraySmallerThanChunkSize() {
        // Given
        let array = [1, 2]
        let chunkSize = 5
        
        // When
        let chunks = array.chunked(into: chunkSize)
        
        // Then
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], [1, 2])
    }
    
    func testChunkedArrayWithChunkSizeOne() {
        // Given
        let array = [1, 2, 3]
        let chunkSize = 1
        
        // When
        let chunks = array.chunked(into: chunkSize)
        
        // Then
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1])
        XCTAssertEqual(chunks[1], [2])
        XCTAssertEqual(chunks[2], [3])
    }
    
    func testChunkedArrayWithLargeChunkSize() {
        // Given
        let array = [1, 2, 3]
        let chunkSize = 100
        
        // When
        let chunks = array.chunked(into: chunkSize)
        
        // Then
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], [1, 2, 3])
    }
    
    func testChunkedStringArray() {
        // Given
        let array = ["a", "b", "c", "d", "e", "f", "g"]
        let chunkSize = 3
        
        // When
        let chunks = array.chunked(into: chunkSize)
        
        // Then
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], ["a", "b", "c"])
        XCTAssertEqual(chunks[1], ["d", "e", "f"])
        XCTAssertEqual(chunks[2], ["g"])
    }
    
    func testChunkedPerformanceWithLargeArray() {
        // Given
        let array = Array(1...10000)
        let chunkSize = 100
        
        // When
        let chunks = array.chunked(into: chunkSize)
        
        // Then
        XCTAssertEqual(chunks.count, 100)
        XCTAssertEqual(chunks.first?.count, 100)
        XCTAssertEqual(chunks.last?.count, 100)
        
        // Verify first and last chunks
        XCTAssertEqual(chunks.first, Array(1...100))
        XCTAssertEqual(chunks.last, Array(9901...10000))
    }
}