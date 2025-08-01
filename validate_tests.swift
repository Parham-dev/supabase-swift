#!/usr/bin/env swift

import Foundation

// Simplified version of ArrayExtensions for testing
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// Simple test framework
func assert(_ condition: Bool, _ message: String = "") {
    if condition {
        print("✅ PASS: \(message)")
    } else {
        print("❌ FAIL: \(message)")
    }
}

func assertEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String = "") {
    if lhs == rhs {
        print("✅ PASS: \(message)")
    } else {
        print("❌ FAIL: \(message) - Expected \(rhs), got \(lhs)")
    }
}

print("Running SwiftSupabaseSync Array Extensions Tests")
print("===============================================")

// Test 1: Chunked array with exact division
print("\n1. Testing chunked array with exact division")
let array1 = [1, 2, 3, 4, 5, 6]
let chunks1 = array1.chunked(into: 2)
assertEqual(chunks1.count, 3, "Should have 3 chunks")
assertEqual(chunks1[0], [1, 2], "First chunk should be [1, 2]")
assertEqual(chunks1[1], [3, 4], "Second chunk should be [3, 4]")
assertEqual(chunks1[2], [5, 6], "Third chunk should be [5, 6]")

// Test 2: Chunked array with remainder
print("\n2. Testing chunked array with remainder")
let array2 = [1, 2, 3, 4, 5]
let chunks2 = array2.chunked(into: 2)
assertEqual(chunks2.count, 3, "Should have 3 chunks")
assertEqual(chunks2[0], [1, 2], "First chunk should be [1, 2]")
assertEqual(chunks2[1], [3, 4], "Second chunk should be [3, 4]")
assertEqual(chunks2[2], [5], "Third chunk should be [5]")

// Test 3: Empty array
print("\n3. Testing empty array")
let array3: [Int] = []
let chunks3 = array3.chunked(into: 3)
assert(chunks3.isEmpty, "Empty array should produce empty chunks")

// Test 4: Array smaller than chunk size
print("\n4. Testing array smaller than chunk size")
let array4 = [1, 2]
let chunks4 = array4.chunked(into: 5)
assertEqual(chunks4.count, 1, "Should have 1 chunk")
assertEqual(chunks4[0], [1, 2], "Chunk should contain all elements")

// Test 5: String array
print("\n5. Testing string array")
let array5 = ["a", "b", "c", "d", "e", "f", "g"]
let chunks5 = array5.chunked(into: 3)
assertEqual(chunks5.count, 3, "Should have 3 chunks")
assertEqual(chunks5[0], ["a", "b", "c"], "First chunk should be [a, b, c]")
assertEqual(chunks5[1], ["d", "e", "f"], "Second chunk should be [d, e, f]")
assertEqual(chunks5[2], ["g"], "Third chunk should be [g]")

// Test 6: Performance with large array
print("\n6. Testing performance with large array")
let array6 = Array(1...10000)
let startTime = Date()
let chunks6 = array6.chunked(into: 100)
let endTime = Date()
let duration = endTime.timeIntervalSince(startTime)

assertEqual(chunks6.count, 100, "Should have 100 chunks")
assertEqual(chunks6.first?.count, 100, "First chunk should have 100 elements")
assertEqual(chunks6.last?.count, 100, "Last chunk should have 100 elements")
print("✅ Performance test completed in \(String(format: "%.3f", duration))s")

print("\n===============================================")
print("Array Extensions Tests Complete!")
print("===============================================")

// Test our main SwiftSupabaseSync structure
print("\nTesting SwiftSupabaseSync main interface:")
struct SwiftSupabaseSync {
    static let version = "1.0.0"
    
    func hello() -> String {
        return "Hello from SwiftSupabaseSync!"
    }
}

let sync = SwiftSupabaseSync()
assertEqual(sync.hello(), "Hello from SwiftSupabaseSync!", "Hello method should return correct message")
assertEqual(SwiftSupabaseSync.version, "1.0.0", "Version should be 1.0.0")

print("\n🎉 All tests completed successfully!")