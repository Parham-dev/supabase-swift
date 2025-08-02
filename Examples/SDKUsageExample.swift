//
//  SDKUsageExample.swift
//  SwiftSupabaseSync Examples
//
//  Created by Parham on 02/08/2025.
//

import Foundation
import SwiftData
import SwiftSupabaseSync

/// Example demonstrating how to use the SwiftSupabaseSync main SDK interface
/// This shows the complete developer experience from initialization to usage
@MainActor
class SDKUsageExample: ObservableObject {
    
    // MARK: - SDK Instance
    
    /// Access to the main SDK instance
    private let sdk = SwiftSupabaseSync.shared
    
    // MARK: - Example Model
    
    /// Example SwiftData model for demonstration
    @Model
    final class Task {
        var id: String
        var title: String
        var isCompleted: Bool
        var createdAt: Date
        
        init(id: String = UUID().uuidString, title: String, isCompleted: Bool = false) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
            self.createdAt = Date()
        }
    }
    
    // MARK: - Usage Examples
    
    /// Example 1: Basic SDK initialization for development
    func example1_basicInitialization() async {
        do {
            // Quick initialization for development
            try await sdk.initializeForDevelopment(
                supabaseURL: "https://your-project.supabase.co",
                supabaseAnonKey: "your-anon-key"
            )
            
            print("✅ SDK initialized successfully!")
            print("Status: \(sdk.isInitialized)")
            
        } catch {
            print("❌ SDK initialization failed: \(error)")
        }
    }
    
    /// Example 2: Advanced SDK initialization with custom configuration
    func example2_advancedInitialization() async {
        do {
            // Advanced configuration using builder pattern
            try await sdk.initialize { builder in
                return try builder
                    .supabaseURL("https://your-project.supabase.co")
                    .supabaseAnonKey("your-anon-key")
                    .environment(.development)
                    
                    // Configure sync behavior
                    .sync { syncConfig in
                        syncConfig
                            .enableOfflineMode(true)
                            .enableRealtime(true)
                            .syncPolicy(.balanced)
                            .batchSize(100)
                            .maxRetryAttempts(3)
                    }
                    
                    // Configure logging
                    .logging { loggingConfig in
                        loggingConfig
                            .logLevel(.debug)
                            .enableConsoleLogging(true)
                            .enableFileLogging(true)
                    }
                    
                    // Configure security
                    .security { securityConfig in
                        securityConfig
                            .enableBiometricAuth(true)
                            .tokenExpirationThreshold(300) // 5 minutes
                    }
                    .build()
            }
            
            print("✅ Advanced SDK initialization completed!")
            
        } catch {
            print("❌ Advanced initialization failed: \(error)")
        }
    }
    
    /// Example 3: Using preset configurations
    func example3_presetConfiguration() async {
        do {
            // Using preset configurations for common scenarios
            try await sdk.initialize { builder in
                return try builder
                    .supabaseURL("https://your-project.supabase.co")
                    .supabaseAnonKey("your-anon-key")
                    .environment(.development)
                    .syncPreset(.offlineFirst)        // Optimized for offline-first apps
                    .loggingPreset(.debug)            // Verbose logging for development
                    .securityPreset(.development)     // Development-friendly security
                    .build()
            }
            
            print("✅ Preset configuration applied successfully!")
            
        } catch {
            print("❌ Preset configuration failed: \(error)")
        }
    }
    
    /// Example 4: Working with Authentication API
    func example4_authenticationUsage() async {
        guard sdk.isInitialized else {
            print("❌ SDK not initialized")
            return
        }
        
        do {
            // Access the Auth API
            let auth = sdk.auth!
            
            // Sign up a new user
            try await auth.signUp(
                email: "user@example.com",
                password: "securePassword123"
            )
            print("✅ User signed up successfully")
            
            // Sign in
            try await auth.signIn(
                email: "user@example.com",
                password: "securePassword123"
            )
            print("✅ User signed in successfully")
            print("Current user: \(auth.currentUser?.email ?? "Unknown")")
            
            // Check authentication state
            print("Is authenticated: \(auth.isAuthenticated)")
            print("Auth status: \(auth.authStatus)")
            
        } catch {
            print("❌ Authentication error: \(error)")
        }
    }
    
    /// Example 5: Working with Schema API
    func example5_schemaManagement() async {
        guard sdk.isInitialized else {
            print("❌ SDK not initialized")
            return
        }
        
        do {
            // Access the Schema API
            let schema = sdk.schema!
            
            // Register a model for sync
            try await schema.registerModel(Task.self)
            print("✅ Task model registered successfully")
            
            // Generate schemas for all registered models
            try await schema.generateAllSchemas()
            print("✅ Schemas generated successfully")
            
            // Validate schemas
            let validationResults = try await schema.validateAllSchemas()
            print("Schema validation completed. All valid: \(schema.allSchemasValid)")
            
            // Check registered schemas
            print("Registered schemas: \(schema.registeredSchemas.keys.joined(separator: ", "))")
            
        } catch {
            print("❌ Schema management error: \(error)")
        }
    }
    
    /// Example 6: Working with Sync API
    func example6_synchronizationUsage() async {
        guard sdk.isInitialized else {
            print("❌ SDK not initialized")
            return
        }
        
        do {
            // Access the Sync API
            let sync = sdk.sync!
            
            // Register a model for synchronization
            try await sync.registerModel(Task.self)
            print("✅ Task model registered for sync")
            
            // Start full synchronization
            let syncResult = try await sync.startSync()
            print("✅ Sync completed successfully")
            print("Downloaded: \(syncResult.downloadedCount) records")
            print("Uploaded: \(syncResult.uploadedCount) records")
            
            // Monitor sync status
            print("Sync status: \(sync.syncStatus)")
            print("Is syncing: \(sync.isSyncing)")
            print("Sync progress: \(sync.syncProgress * 100)%")
            
            // Enable real-time sync
            try await sync.enableSync(true)
            print("✅ Real-time sync enabled")
            
        } catch {
            print("❌ Synchronization error: \(error)")
        }
    }
    
    /// Example 7: Monitoring SDK health
    func example7_healthMonitoring() async {
        guard sdk.isInitialized else {
            print("❌ SDK not initialized")
            return
        }
        
        // Perform health check
        let healthResult = await sdk.performHealthCheck()
        print("🏥 Health Check Results:")
        print("Overall status: \(healthResult.overallStatus)")
        print("Summary: \(healthResult.healthSummary)")
        
        // Check individual component health
        for (component, status) in healthResult.componentStatuses {
            print("  \(component): \(status)")
        }
        
        // Check for errors
        if !healthResult.errors.isEmpty {
            print("⚠️ Health check errors:")
            for error in healthResult.errors {
                print("  - \(error.localizedDescription)")
            }
        }
        
        // Get runtime information
        let runtimeInfo = sdk.getRuntimeInfo()
        print("\n📊 Runtime Information:")
        print(runtimeInfo.summary)
    }
    
    /// Example 8: Production initialization
    func example8_productionInitialization() async {
        do {
            // Production-ready initialization
            try await sdk.initializeForProduction(
                supabaseURL: "https://your-production-project.supabase.co",
                supabaseAnonKey: "your-production-anon-key"
            )
            
            print("🚀 Production SDK initialized successfully!")
            
            // Verify production settings
            let runtimeInfo = sdk.getRuntimeInfo()
            print("Environment: Production")
            print("Health: \(runtimeInfo.healthStatus)")
            
        } catch {
            print("❌ Production initialization failed: \(error)")
        }
    }
    
    /// Example 9: Error handling best practices
    func example9_errorHandling() async {
        do {
            // Attempt to initialize with invalid configuration
            try await sdk.initialize { builder in
                return try builder
                    .supabaseURL("invalid-url")  // This will cause validation error
                    .supabaseAnonKey("short")    // This will cause validation error
                    .build()
            }
            
        } catch let error as SDKError {
            print("🔧 SDK Error Handling:")
            print("Error: \(error.localizedDescription)")
            print("Recovery: \(error.recoverySuggestion ?? "No recovery suggestion")")
            
            // Handle specific error types
            switch error {
            case .notInitialized:
                print("SDK needs initialization")
            case .alreadyInitialized:
                print("SDK already initialized, use existing instance")
            case .configurationError(let message):
                print("Configuration issue: \(message)")
            case .initializationFailed(let underlyingError):
                print("Initialization failed due to: \(underlyingError)")
            default:
                print("Other SDK error occurred")
            }
            
        } catch {
            print("❌ Other error: \(error)")
        }
    }
    
    /// Example 10: Complete workflow demonstration
    func example10_completeWorkflow() async {
        print("🚀 Starting complete SwiftSupabaseSync workflow...")
        
        // Step 1: Initialize SDK
        do {
            try await sdk.initializeForDevelopment(
                supabaseURL: "https://your-project.supabase.co",
                supabaseAnonKey: "your-anon-key"
            )
            print("✅ Step 1: SDK initialized")
        } catch {
            print("❌ Step 1 failed: \(error)")
            return
        }
        
        // Step 2: Register models
        do {
            try await sdk.schema!.registerModel(Task.self)
            try await sdk.sync!.registerModel(Task.self)
            print("✅ Step 2: Models registered")
        } catch {
            print("❌ Step 2 failed: \(error)")
            return
        }
        
        // Step 3: Authenticate user
        do {
            try await sdk.auth!.signIn(
                email: "user@example.com",
                password: "password123"
            )
            print("✅ Step 3: User authenticated")
        } catch {
            print("❌ Step 3 failed: \(error)")
            return
        }
        
        // Step 4: Start synchronization
        do {
            let result = try await sdk.sync!.startSync()
            print("✅ Step 4: Sync completed (\(result.downloadedCount) downloaded)")
        } catch {
            print("❌ Step 4 failed: \(error)")
            return
        }
        
        // Step 5: Health check
        let health = await sdk.performHealthCheck()
        print("✅ Step 5: Health check completed (\(health.overallStatus))")
        
        print("🎉 Complete workflow finished successfully!")
    }
}

// MARK: - Usage in SwiftUI View

import SwiftUI

/// Example SwiftUI view demonstrating SDK integration
struct SDKDashboardView: View {
    @StateObject private var example = SDKUsageExample()
    @StateObject private var sdk = SwiftSupabaseSync.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // SDK Status
                statusSection
                
                // Quick Actions
                actionSection
                
                // Runtime Info
                infoSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("SwiftSupabaseSync")
        }
    }
    
    @ViewBuilder
    private var statusSection: some View {
        GroupBox("SDK Status") {
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(title: "Initialized", value: sdk.isInitialized ? "Yes" : "No")
                StatusRow(title: "State", value: "\(sdk.initializationState)")
                StatusRow(title: "Health", value: "\(sdk.healthStatus)")
                
                if let auth = sdk.auth {
                    StatusRow(title: "Authenticated", value: auth.isAuthenticated ? "Yes" : "No")
                }
                
                if let sync = sdk.sync {
                    StatusRow(title: "Sync Enabled", value: sync.isSyncEnabled ? "Yes" : "No")
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionSection: some View {
        GroupBox("Quick Actions") {
            VStack(spacing: 12) {
                Button("Initialize SDK") {
                    Task {
                        await example.example1_basicInitialization()
                    }
                }
                .disabled(sdk.isInitialized)
                
                Button("Health Check") {
                    Task {
                        await example.example7_healthMonitoring()
                    }
                }
                .disabled(!sdk.isInitialized)
                
                Button("Complete Workflow") {
                    Task {
                        await example.example10_completeWorkflow()
                    }
                }
                .disabled(!sdk.isInitialized)
            }
        }
    }
    
    @ViewBuilder
    private var infoSection: some View {
        GroupBox("Runtime Info") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Version: \(SwiftSupabaseSync.version)")
                Text("Build: \(SwiftSupabaseSync.buildNumber)")
                Text("Identifier: \(SwiftSupabaseSync.identifier)")
            }
            .font(.caption)
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SDKDashboardView()
}
