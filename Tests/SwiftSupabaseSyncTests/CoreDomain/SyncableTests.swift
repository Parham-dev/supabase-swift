import Testing
@testable import SwiftSupabaseSync

/// Tests for the Syncable protocol and its default implementations
/// This covers the core synchronization interface that all models must implement
struct SyncableTests {
    
    // MARK: - Test Implementation
    
    /// Mock implementation of Syncable for testing
    struct MockSyncableEntity: Syncable {
        var syncID: UUID
        var lastModified: Date
        var lastSynced: Date?
        var isDeleted: Bool
        var version: Int
        
        init(syncID: UUID = UUID()) {
            self.syncID = syncID
            self.lastModified = Date()
            self.lastSynced = nil
            self.isDeleted = false
            self.version = 0
        }
    }
    
    // MARK: - Basic Protocol Implementation Tests
    
    @Test("Syncable entity should initialize with correct defaults")
    func testBasicInitialization() async throws {
        let entity = MockSyncableEntity()
        
        #expect(!entity.isDeleted)
        #expect(entity.version == 0)
        #expect(entity.lastSynced == nil)
        #expect(entity.needsSync == true) // Should need sync when never synced
    }
    
    @Test("Table name should default to lowercased type name")
    func testDefaultTableName() async throws {
        #expect(MockSyncableEntity.tableName == "mocksyncableentity")
    }
    
    @Test("Content hash should be consistent for same content")
    func testContentHashConsistency() async throws {
        let entity1 = MockSyncableEntity()
        let entity2 = MockSyncableEntity()
        
        // Same initial state should have same hash
        #expect(entity1.contentHash == entity2.contentHash)
        
        // Modify one entity
        var mutableEntity1 = entity1
        mutableEntity1.version = 1
        
        // Hash should be different after modification
        #expect(mutableEntity1.contentHash != entity2.contentHash)
    }
    
    @Test("needsSync should work correctly based on sync state")
    func testNeedsSyncLogic() async throws {
        var entity = MockSyncableEntity()
        
        // Never synced should need sync
        #expect(entity.needsSync == true)
        
        // After sync, should not need sync
        entity.lastSynced = Date()
        #expect(entity.needsSync == false)
        
        // After modification, should need sync again
        entity.lastModified = Date().addingTimeInterval(1)
        #expect(entity.needsSync == true)
        
        // Deleted entity should need sync if not synced since deletion
        entity.isDeleted = true
        entity.lastModified = Date().addingTimeInterval(2)
        #expect(entity.needsSync == true)
    }
    
    // MARK: - Sync Operations Tests
    
    @Test("Sync snapshots should be created correctly")
    func testSyncSnapshotCreation() async throws {
        let entity = MockSyncableEntity()
        let snapshot = SyncSnapshot(
            syncID: entity.syncID,
            tableName: MockSyncableEntity.tableName,
            version: entity.version,
            lastModified: entity.lastModified,
            lastSynced: entity.lastSynced,
            isDeleted: entity.isDeleted,
            contentHash: entity.contentHash
        )
        
        #expect(snapshot.syncID == entity.syncID)
        #expect(snapshot.tableName == "mocksyncableentity")
        #expect(snapshot.version == entity.version)
        #expect(snapshot.isDeleted == entity.isDeleted)
        #expect(snapshot.contentHash == entity.contentHash)
    }
    
    @Test("Snapshot equality should work correctly")
    func testSyncSnapshotEquality() async throws {
        let entity1 = MockSyncableEntity()
        let entity2 = MockSyncableEntity()
        
        let snapshot1 = SyncSnapshot(
            syncID: entity1.syncID,
            tableName: MockSyncableEntity.tableName,
            version: entity1.version,
            lastModified: entity1.lastModified,
            lastSynced: entity1.lastSynced,
            isDeleted: entity1.isDeleted,
            contentHash: entity1.contentHash
        )
        
        let snapshot2 = SyncSnapshot(
            syncID: entity1.syncID, // Same ID
            tableName: MockSyncableEntity.tableName,
            version: entity1.version, // Same version
            lastModified: entity1.lastModified,
            lastSynced: entity1.lastSynced,
            isDeleted: entity1.isDeleted,
            contentHash: entity1.contentHash // Same hash
        )
        
        let snapshot3 = SyncSnapshot(
            syncID: entity2.syncID, // Different ID
            tableName: MockSyncableEntity.tableName,
            version: entity2.version,
            lastModified: entity2.lastModified,
            lastSynced: entity2.lastSynced,
            isDeleted: entity2.isDeleted,
            contentHash: entity2.contentHash
        )
        
        #expect(snapshot1 == snapshot2) // Same ID, version, hash
        #expect(snapshot1 != snapshot3) // Different ID
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Conflict resolution types should be defined")
    func testConflictResolutionTypes() async throws {
        let localWins = SyncableConflictResolutionResult.localWins
        let remoteWins = SyncableConflictResolutionResult.remoteWins([:])
        let merged = SyncableConflictResolutionResult.merged([:])
        
        // Just verify the types exist and can be created
        switch localWins {
        case .localWins:
            #expect(true)
        default:
            #expect(false, "Should be localWins")
        }
        
        switch remoteWins {
        case .remoteWins:
            #expect(true)
        default:
            #expect(false, "Should be remoteWins")
        }
        
        switch merged {
        case .merged:
            #expect(true)
        default:
            #expect(false, "Should be merged")
        }
    }
}