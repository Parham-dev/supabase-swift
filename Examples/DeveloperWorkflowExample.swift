//
//  DeveloperWorkflowExample.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import SwiftData
import SwiftSupabaseSync

/// Example showing how simple it is for developers to use SwiftSupabaseSync
/// This demonstrates the complete real-world workflow using only public APIs
@MainActor
class DeveloperWorkflowExample {
    
    // MARK: - Step 1: Developer's SwiftData Models
    
    /// Developer creates their SwiftData models and makes them conform to Syncable
    @Model
    final class Todo: Syncable {
        var id: String = UUID().uuidString
        var title: String
        var isCompleted: Bool = false
        var createdAt: Date = Date()
        var updatedAt: Date = Date()
        
        // MARK: - Syncable Requirements (boilerplate)
        var syncID: UUID = UUID()
        var lastModified: Date = Date()
        var lastSynced: Date?
        var isDeleted: Bool = false
        var version: Int = 1
        
        var contentHash: String {
            "\(title)-\(isCompleted)-\(updatedAt.timeIntervalSince1970)".data(using: .utf8)?.base64EncodedString() ?? ""
        }
        
        var needsSync: Bool {
            guard let lastSynced = lastSynced else { return true }
            return lastModified > lastSynced
        }
        
        static var tableName: String { "todos" }
        static var syncableProperties: [String] {
            ["id", "title", "isCompleted", "createdAt", "updatedAt"]
        }
        
        init(title: String) {
            self.title = title
        }
    }
    
    @Model
    final class User: Syncable {
        var id: String = UUID().uuidString
        var name: String
        var email: String
        var createdAt: Date = Date()
        
        // MARK: - Syncable Requirements (boilerplate)
        var syncID: UUID = UUID()
        var lastModified: Date = Date()
        var lastSynced: Date?
        var isDeleted: Bool = false
        var version: Int = 1
        
        var contentHash: String {
            "\(name)-\(email)-\(createdAt.timeIntervalSince1970)".data(using: .utf8)?.base64EncodedString() ?? ""
        }
        
        var needsSync: Bool {
            guard let lastSynced = lastSynced else { return true }
            return lastModified > lastSynced
        }
        
        static var tableName: String { "users" }
        static var syncableProperties: [String] {
            ["id", "name", "email", "createdAt"]
        }
        
        init(name: String, email: String) {
            self.name = name
            self.email = email
        }
    }
    
    // MARK: - Step 2: Simple SDK Setup
    
    /// Complete setup method that developers would call in their app
    func setupSupabaseSync() async throws {
        let sdk = SwiftSupabaseSync.shared
        
        // Initialize with Supabase credentials
        try await sdk.initializeForDevelopment(
            supabaseURL: "https://your-project.supabase.co",
            supabaseAnonKey: "your-anon-key"
        )
        
        // Register all models at once - super simple!
        sdk.sync?.registerModels(Todo.self, User.self)
        
        print("✅ SwiftSupabaseSync ready!")
        print("   - SDK initialized")
        print("   - Models registered: Todo, User")
        print("   - Ready for authentication and sync")
    }
    
    // MARK: - Step 3: Authentication & Sync
    
    /// Example of how developers would authenticate and start syncing
    func authenticateAndSync() async throws {
        let sdk = SwiftSupabaseSync.shared
        
        guard let auth = sdk.auth, let sync = sdk.sync else {
            throw SwiftSupabaseSyncError.initializationRequired
        }
        
        // Authenticate user
        try await auth.signIn(email: "user@example.com", password: "password")
        
        // Start automatic bidirectional sync
        let result = try await sync.startSync()
        
        if result.success {
            print("🔄 Sync started successfully!")
            print("   - Uploaded: \(result.uploadedCount) records")
            print("   - Downloaded: \(result.downloadedCount) records")
            print("   - All changes are now synced bidirectionally")
        }
    }
    
    // MARK: - Step 4: Using the Models
    
    /// Example of how developers would use their synced models
    func useModels(context: ModelContext) async throws {
        // Create new models - they automatically sync!
        let todo = Todo(title: "Buy groceries")
        let user = User(name: "John Doe", email: "john@example.com")
        
        context.insert(todo)
        context.insert(user)
        try context.save()
        
        print("📦 Models created and saved")
        print("   - They will automatically sync to Supabase")
        print("   - Changes from other devices will sync back")
        print("   - Conflicts are automatically resolved")
        
        // Update models - changes sync automatically
        todo.isCompleted = true
        todo.lastModified = Date()  // Triggers sync
        
        try context.save()
        
        print("🔄 Model updated - change will sync automatically")
    }
}

// MARK: - Summary: Developer Experience

/*
 
 ## 🚀 SwiftSupabaseSync - Developer Experience

 ### What developers need to do:
 
 1. **Create SwiftData models** conforming to `Syncable` (one-time setup)
 2. **Initialize SDK** with Supabase credentials
 3. **Register models** using simple API
 4. **Authenticate** and **start sync**
 5. **Use models normally** - sync happens automatically!

 ### The complete setup (5 lines of code):
 
 ```swift
 let sdk = SwiftSupabaseSync.shared
 try await sdk.initializeForDevelopment(url: "...", key: "...")
 sdk.sync?.registerModels(Todo.self, User.self, Note.self)
 try await sdk.auth?.signIn(email: "...", password: "...")
 try await sdk.sync?.startSync()
 ```

 ### What happens automatically:
 
 - ✅ **Bidirectional sync**: Local changes → Supabase, Supabase changes → Local
 - ✅ **Conflict resolution**: Smart merging when same data is modified
 - ✅ **Offline support**: Works offline, syncs when online
 - ✅ **Real-time updates**: Changes from other devices appear instantly
 - ✅ **Error handling**: Network issues, authentication problems handled gracefully

 ### What developers don't need to worry about:
 
 - ❌ Manual API calls to Supabase
 - ❌ Conflict detection and resolution logic
 - ❌ Network state management
 - ❌ Sync scheduling and batching
 - ❌ Error recovery and retry logic
 - ❌ Real-time subscription management

 ## 🎯 Result: Extremely simple for developers!
 
 They just create models, register them, and everything works automatically.
 The public API is clean, type-safe, and follows Swift/SwiftUI conventions.
 
 */
