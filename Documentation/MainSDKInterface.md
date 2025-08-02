# SwiftSupabaseSync - Main SDK Interface

## Overview

The `SwiftSupabaseSync` class is the main entry point for the SwiftSupabaseSync framework. It provides a unified, developer-friendly interface that integrates authentication, synchronization, and schema management in a clean, reactive API.

## Key Features

- 🏗 **Single Entry Point**: One class to rule them all
- ⚙️ **Flexible Configuration**: Builder pattern with presets for common scenarios
- 🔄 **Reactive Design**: SwiftUI-ready with Combine publishers
- 🏥 **Health Monitoring**: Built-in health checks and diagnostics
- 🛡 **Type Safety**: Comprehensive error handling with recovery suggestions
- 📱 **Offline-First**: Seamless offline/online operation

## Quick Start

### Basic Initialization

```swift
import SwiftSupabaseSync

// Quick initialization for development
try await SwiftSupabaseSync.shared.initializeForDevelopment(
    supabaseURL: "https://your-project.supabase.co",
    supabaseAnonKey: "your-anon-key"
)

// Now you can use the SDK
let auth = SwiftSupabaseSync.shared.auth!
let sync = SwiftSupabaseSync.shared.sync!
let schema = SwiftSupabaseSync.shared.schema!
```

### Advanced Configuration

```swift
try await SwiftSupabaseSync.shared.initialize { builder in
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
        }
        
        // Configure logging
        .logging { loggingConfig in
            loggingConfig
                .logLevel(.debug)
                .enableConsoleLogging(true)
        }
        
        // Configure security
        .security { securityConfig in
            securityConfig
                .enableBiometricAuth(true)
                .tokenExpirationThreshold(300)
        }
        .build()
}
```

## Core APIs

Once initialized, the SDK provides access to three main APIs:

### 1. Authentication API (`auth`)

```swift
let auth = SwiftSupabaseSync.shared.auth!

// Sign up
try await auth.signUp(email: "user@example.com", password: "password")

// Sign in
try await auth.signIn(email: "user@example.com", password: "password")

// Check status
print("Authenticated: \(auth.isAuthenticated)")
print("Current user: \(auth.currentUser?.email ?? "None")")
```

### 2. Synchronization API (`sync`)

```swift
let sync = SwiftSupabaseSync.shared.sync!

// Register model for sync
try await sync.registerModel(MyModel.self)

// Start synchronization
let result = try await sync.startSync()
print("Downloaded: \(result.downloadedCount) records")

// Monitor sync status
print("Sync status: \(sync.syncStatus)")
print("Progress: \(sync.syncProgress * 100)%")
```

### 3. Schema API (`schema`)

```swift
let schema = SwiftSupabaseSync.shared.schema!

// Register model
try await schema.registerModel(MyModel.self)

// Generate schemas
try await schema.generateAllSchemas()

// Validate schemas
let results = try await schema.validateAllSchemas()
print("All schemas valid: \(schema.allSchemasValid)")
```

## Configuration Presets

The SDK provides convenient presets for common scenarios:

### Development Preset
```swift
try await SwiftSupabaseSync.shared.initialize { builder in
    return try builder
        .supabaseURL("https://your-project.supabase.co")
        .supabaseAnonKey("your-anon-key")
        .syncPreset(.offlineFirst)     // Optimized for offline development
        .loggingPreset(.debug)         // Verbose logging
        .securityPreset(.development)  // Development-friendly security
        .build()
}
```

### Production Preset
```swift
try await SwiftSupabaseSync.shared.initializeForProduction(
    supabaseURL: "https://your-production-project.supabase.co",
    supabaseAnonKey: "your-production-anon-key"
)
```

### Testing Preset
```swift
let config = try ConfigurationBuilder.testing(
    url: "https://test-project.supabase.co",
    key: "test-key"
)
try await SwiftSupabaseSync.shared.initialize(with: config)
```

## Health Monitoring

The SDK includes comprehensive health monitoring:

```swift
// Perform health check
let healthResult = await SwiftSupabaseSync.shared.performHealthCheck()

print("Overall status: \(healthResult.overallStatus)")
print("Summary: \(healthResult.healthSummary)")

// Check individual components
for (component, status) in healthResult.componentStatuses {
    print("\(component): \(status)")
}

// Check for errors
if !healthResult.errors.isEmpty {
    print("Errors detected:")
    healthResult.errors.forEach { print("- \(($0.localizedDescription)") }
}
```

## Runtime Information

Get detailed runtime information:

```swift
let runtimeInfo = SwiftSupabaseSync.shared.getRuntimeInfo()
print(runtimeInfo.summary)

// Outputs:
// SwiftSupabaseSync v1.0.0
// Build: 2025.08.02.001
// Status: Initialized
// Health: healthy
// Auth: Authenticated
// Sync: Enabled
// Models: 3 registered
// Config: Present
```

## Error Handling

The SDK provides comprehensive error handling with recovery suggestions:

```swift
do {
    try await SwiftSupabaseSync.shared.initializeForDevelopment(
        supabaseURL: "invalid-url",
        supabaseAnonKey: "short-key"
    )
} catch let error as SDKError {
    print("Error: \(error.localizedDescription)")
    print("Recovery: \(error.recoverySuggestion ?? "No suggestion")")
    
    switch error {
    case .notInitialized:
        // Handle not initialized
    case .configurationError(let message):
        // Handle configuration error
    case .initializationFailed(let underlyingError):
        // Handle initialization failure
    default:
        // Handle other errors
    }
}
```

## SwiftUI Integration

The SDK is designed for seamless SwiftUI integration:

```swift
struct ContentView: View {
    @StateObject private var sdk = SwiftSupabaseSync.shared
    
    var body: some View {
        VStack {
            if sdk.isInitialized {
                Text("SDK Ready!")
                    .foregroundColor(.green)
                
                if let auth = sdk.auth {
                    Text("Auth Status: \(auth.authStatus)")
                }
                
                if let sync = sdk.sync {
                    Text("Sync Progress: \(sync.syncProgress * 100, specifier: "%.1f")%")
                }
            } else {
                Text("Initializing SDK...")
                    .foregroundColor(.orange)
            }
        }
        .task {
            if !sdk.isInitialized {
                try? await sdk.initializeForDevelopment(
                    supabaseURL: "https://your-project.supabase.co",
                    supabaseAnonKey: "your-anon-key"
                )
            }
        }
    }
}
```

## Lifecycle Management

### Initialization States

The SDK goes through several initialization states:

- `.notInitialized` - SDK has not been initialized
- `.initializing` - SDK is currently initializing
- `.initialized` - SDK is fully initialized and ready
- `.failed` - SDK initialization failed
- `.shuttingDown` - SDK is shutting down

### Shutdown and Reset

```swift
// Graceful shutdown
await SwiftSupabaseSync.shared.shutdown()

// Reset for testing
await SwiftSupabaseSync.shared.reset()
```

## Thread Safety

The SDK is designed with thread safety in mind:

- Main SDK class is marked with `@MainActor`
- All public APIs are thread-safe
- Reactive properties work seamlessly with SwiftUI
- Internal coordination happens on dedicated queues

## Best Practices

### 1. Initialize Early
```swift
// In your App.swift or SceneDelegate
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await initializeSDK()
                }
        }
    }
    
    private func initializeSDK() async {
        do {
            try await SwiftSupabaseSync.shared.initializeForDevelopment(
                supabaseURL: "https://your-project.supabase.co",
                supabaseAnonKey: "your-anon-key"
            )
        } catch {
            print("SDK initialization failed: \(error)")
        }
    }
}
```

### 2. Use Health Monitoring
```swift
// Regular health checks in production
Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
    .autoconnect()
    .sink { _ in
        Task {
            let health = await SwiftSupabaseSync.shared.performHealthCheck()
            if health.overallStatus == .unhealthy {
                // Handle unhealthy state
                await handleUnhealthySDK(health)
            }
        }
    }
    .store(in: &cancellables)
```

### 3. Handle Network Changes
```swift
// The SDK automatically handles network changes, but you can monitor them
SwiftSupabaseSync.shared.sync?.syncStatusPublisher
    .sink { status in
        switch status.status {
        case .failed:
            // Handle sync failure
        case .completed:
            // Handle sync completion
        default:
            break
        }
    }
    .store(in: &cancellables)
```

### 4. Secure Configuration in Production
```swift
// Use environment variables or secure storage for production
let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""

try await SwiftSupabaseSync.shared.initializeForProduction(
    supabaseURL: supabaseURL,
    supabaseAnonKey: supabaseKey
)
```

## Troubleshooting

### Common Issues

1. **SDK Not Initialized**
   ```swift
   // Check initialization state
   print("SDK State: \(SwiftSupabaseSync.shared.initializationState)")
   
   // Check for initialization errors
   if let error = SwiftSupabaseSync.shared.initializationError {
       print("Init Error: \(error)")
   }
   ```

2. **Configuration Validation Errors**
   ```swift
   // Use safe build method for better error reporting
   let result = ConfigurationBuilder()
       .supabaseURL("your-url")
       .supabaseAnonKey("your-key")
       .buildSafely()
   
   switch result {
   case .success(let config):
       try await SwiftSupabaseSync.shared.initialize(with: config)
   case .failure(let error):
       print("Configuration error: \(error)")
   }
   ```

3. **Health Check Failures**
   ```swift
   let health = await SwiftSupabaseSync.shared.performHealthCheck()
   if !health.isHealthy {
       print("Component statuses:")
       health.componentStatuses.forEach { component, status in
           print("  \(component): \(status)")
       }
   }
   ```

## API Reference

### SwiftSupabaseSync Class

| Property | Type | Description |
|----------|------|-------------|
| `shared` | `SwiftSupabaseSync` | Singleton instance |
| `version` | `String` | Framework version |
| `buildNumber` | `String` | Framework build number |
| `isInitialized` | `Bool` | Whether SDK is initialized |
| `initializationState` | `SDKInitializationState` | Current initialization state |
| `healthStatus` | `SDKHealthStatus` | Current health status |
| `auth` | `AuthAPI?` | Authentication API |
| `sync` | `SyncAPI?` | Synchronization API |
| `schema` | `SchemaAPI?` | Schema management API |

### Key Methods

| Method | Description |
|--------|-------------|
| `initialize(with:)` | Initialize with configuration |
| `initialize(_:)` | Initialize with builder closure |
| `initializeForDevelopment(supabaseURL:supabaseAnonKey:)` | Quick development setup |
| `initializeForProduction(supabaseURL:supabaseAnonKey:)` | Quick production setup |
| `performHealthCheck()` | Perform comprehensive health check |
| `getRuntimeInfo()` | Get detailed runtime information |
| `shutdown()` | Graceful shutdown |
| `reset()` | Reset for testing |

### Error Types

| Error | Description |
|-------|-------------|
| `SDKError.notInitialized` | SDK not initialized |
| `SDKError.alreadyInitialized` | SDK already initialized |
| `SDKError.configurationError(_)` | Configuration error |
| `SDKError.initializationFailed(_)` | Initialization failed |
| `SDKError.healthCheckFailed(_)` | Health check failed |

## What's Next?

After initializing the main SDK interface, you can:

1. **Explore Authentication**: Learn about user management, session handling, and biometric authentication
2. **Master Synchronization**: Dive into conflict resolution, real-time sync, and offline capabilities  
3. **Understand Schema Management**: Explore automatic schema generation, validation, and migrations
4. **Build Your App**: Start building your offline-first app with real-time capabilities

## Support

For questions, issues, or contributions:

- 📚 Documentation: Check the individual API documentation
- 🐛 Issues: Report issues on GitHub
- 💬 Discussions: Join the community discussions
- 📧 Contact: Reach out to the maintainers

---

**SwiftSupabaseSync v1.0.0** - Built with ❤️ for the Swift community
