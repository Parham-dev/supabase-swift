import Testing
@testable import SwiftSupabaseSync

struct SwiftSupabaseSyncTests {
    @Test("Basic initialization test")
    func testBasicInitialization() throws {
        let sync = SwiftSupabaseSync()
        #expect(sync.hello() == "Hello from SwiftSupabaseSync!")
    }
    
    @Test("Version test")
    func testVersion() throws {
        #expect(SwiftSupabaseSync.version == "1.0.0")
    }
}