# SwiftSupabaseSync

A Swift package that enables seamless synchronization between SwiftData models and Supabase databases, following Clean Architecture and SOLID principles.

## Features

- **Automatic Sync**: Bidirectional synchronization between local SwiftData models and remote Supabase database
- **Offline-First**: Local operations work independently, sync when connection is available
- **Conflict Resolution**: Configurable conflict resolution strategies for data synchronization
- **Pro Features**: Subscription-based feature gating for advanced sync capabilities
- **Real-time Updates**: Live data synchronization using Supabase real-time subscriptions
- **Schema Generation**: Automatic database schema creation from SwiftData models
- **Authentication**: Integrated user authentication with Supabase Auth
- **Clean Architecture**: Well-structured codebase following SOLID principles

## Requirements

- iOS 17.0+ / macOS 14.0+ / watchOS 10.0+ / tvOS 17.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add SwiftSupabaseSync to your project using Xcode:

1. In Xcode, go to **File > Add Package Dependencies**
2. Enter the repository URL: `https://github.com/yourusername/SwiftSupabaseSync`
3. Select the version and add to your target

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SwiftSupabaseSync", from: "1.0.0")
]
```

## Environment Setup

For secure credential management, see [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md) for detailed instructions on configuring your Supabase credentials using environment variables.

## Quick Start

### 1. Configure Supabase

```swift
import SwiftSupabaseSync

// Configure in your App file
@main
struct MyApp: App {
    init() {
        SwiftSupabaseSync.configure(
            supabaseURL: "YOUR_SUPABASE_URL",
            supabaseKey: "YOUR_SUPABASE_ANON_KEY"
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Make Your Models Syncable

```swift
import SwiftData
import SwiftSupabaseSync

@Model
class Todo: Syncable {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    
    init(title: String) {
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
    
    // Syncable conformance
    var syncID: UUID = UUID()
    var lastModified: Date = Date()
    var isDeleted: Bool = false
}
```

### 3. Enable Sync

```swift
import SwiftUI
import SwiftSupabaseSync

struct ContentView: View {
    @State private var syncManager = SyncManager.shared
    
    var body: some View {
        VStack {
            // Your SwiftUI content
            
            Toggle("Enable Sync", isOn: $syncManager.isSyncEnabled)
        }
        .onAppear {
            syncManager.startSync()
        }
    }
}
```

## Architecture

SwiftSupabaseSync follows Clean Architecture principles with clear separation of concerns:

```
Sources/SwiftSupabaseSync/
├── Core/                    # Core business logic
│   ├── Domain/             # Entities, protocols, use cases
│   ├── Data/               # Repositories, data sources
│   └── Presentation/       # View models, publishers
├── Features/               # Feature-specific modules
│   ├── Authentication/     # User auth and session management
│   ├── Synchronization/    # Sync engine and conflict resolution
│   ├── Schema/            # Model registration and table generation
│   └── Subscription/      # Pro feature validation
├── Infrastructure/         # Technical services
│   ├── Network/           # HTTP client and networking
│   ├── Storage/           # Local storage services
│   ├── Logging/           # Diagnostic logging
│   └── Utils/             # Common utilities
├── DI/                    # Dependency injection
└── Public/                # Public API
```

## Advanced Usage

### Custom Conflict Resolution

```swift
class MyConflictResolver: ConflictResolvable {
    func resolve<T: Syncable>(_ local: T, _ remote: T) -> T {
        // Custom conflict resolution logic
        return local.lastModified > remote.lastModified ? local : remote
    }
}

// Configure custom resolver
SwiftSupabaseSync.configure(
    conflictResolver: MyConflictResolver()
)
```

### Subscription Validation

```swift
// Enable sync only for pro users
SwiftSupabaseSync.configure(
    subscriptionValidator: MySubscriptionValidator()
)
```

### Real-time Sync Status

```swift
struct SyncStatusView: View {
    @StateObject private var syncStatus = SyncStatusPublisher()
    
    var body: some View {
        HStack {
            Image(systemName: syncStatus.isConnected ? "wifi" : "wifi.slash")
            Text(syncStatus.status.description)
        }
        .foregroundColor(syncStatus.isError ? .red : .primary)
    }
}
```

## Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `syncPolicy` | Sync frequency and behavior | `.automatic` |
| `conflictResolution` | How to handle sync conflicts | `.lastWriteWins` |
| `enableRealtime` | Real-time sync subscriptions | `true` |
| `retryAttempts` | Network retry attempts | `3` |
| `logLevel` | Logging verbosity | `.info` |

## Testing

Run tests using Xcode or Swift Package Manager:

```bash
swift test
```

The package includes comprehensive test coverage with mocks and fixtures for all major components.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the existing architecture
4. Add tests for new functionality
5. Submit a pull request

## License

SwiftSupabaseSync is available under the MIT license. See the LICENSE file for more info.

## Support

- [Documentation](https://github.com/yourusername/SwiftSupabaseSync/wiki)
- [Issues](https://github.com/yourusername/SwiftSupabaseSync/issues)
- [Discussions](https://github.com/yourusername/SwiftSupabaseSync/discussions)