import XCTest
@testable import SwiftSupabaseSync

final class SwiftSupabaseSyncTests: XCTestCase {
    func testHello() throws {
        let sync = SwiftSupabaseSync()
        XCTAssertEqual(sync.hello(), "Hello from SwiftSupabaseSync!")
    }
    
    func testVersion() throws {
        XCTAssertEqual(SwiftSupabaseSync.version, "1.0.0")
    }
}