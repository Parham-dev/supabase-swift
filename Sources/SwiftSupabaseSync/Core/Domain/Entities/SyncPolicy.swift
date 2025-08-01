import Foundation

/// Domain entity representing synchronization policy and configuration
/// Defines how and when synchronization should occur
public struct SyncPolicy {
    
    // MARK: - Core Properties
    
    /// Unique identifier for this sync policy
    public let id: UUID
    
    /// Name or description of this policy
    public let name: String
    
    /// Whether this policy is currently active
    public let isEnabled: Bool
    
    /// Timestamp when the policy was created
    public let createdAt: Date
    
    /// Timestamp when the policy was last updated
    public let updatedAt: Date
    
    // MARK: - Sync Behavior
    
    /// How frequently sync should occur
    public let frequency: SyncFrequency
    
    /// Whether to sync only on Wi-Fi
    public let wifiOnly: Bool
    
    /// Whether to sync when app is in background
    public let allowBackgroundSync: Bool
    
    /// Whether to enable real-time synchronization
    public let enableRealtimeSync: Bool
    
    /// Conflict resolution strategy for this policy
    public let conflictResolution: ConflictResolutionStrategy
    
    // MARK: - Retry Configuration
    
    /// Maximum number of retry attempts
    public let maxRetries: Int
    
    /// Base delay between retries in seconds
    public let retryDelay: TimeInterval
    
    /// Whether to use exponential backoff for retries
    public let useExponentialBackoff: Bool
    
    // MARK: - Data Filtering
    
    /// Entity types to include in sync (empty means all)
    public let includedEntities: Set<String>
    
    /// Entity types to exclude from sync
    public let excludedEntities: Set<String>
    
    /// Whether to sync deleted items
    public let syncDeleted: Bool
    
    /// Maximum age of items to sync (nil means no limit)
    public let maxItemAge: TimeInterval?
    
    // MARK: - Performance Limits
    
    /// Maximum number of items to sync in one batch
    public let batchSize: Int
    
    /// Maximum total sync duration in seconds
    public let maxSyncDuration: TimeInterval
    
    /// Whether to pause sync on low battery
    public let pauseOnLowBattery: Bool
    
    /// Minimum battery level required for sync (0.0 to 1.0)
    public let minimumBatteryLevel: Double
    
    // MARK: - Initializer
    
    public init(
        id: UUID = UUID(),
        name: String = "Default Policy",
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        frequency: SyncFrequency = .automatic,
        wifiOnly: Bool = false,
        allowBackgroundSync: Bool = true,
        enableRealtimeSync: Bool = true,
        conflictResolution: ConflictResolutionStrategy = .lastWriteWins,
        maxRetries: Int = 3,
        retryDelay: TimeInterval = 5.0,
        useExponentialBackoff: Bool = true,
        includedEntities: Set<String> = [],
        excludedEntities: Set<String> = [],
        syncDeleted: Bool = true,
        maxItemAge: TimeInterval? = nil,
        batchSize: Int = 100,
        maxSyncDuration: TimeInterval = 300.0,
        pauseOnLowBattery: Bool = true,
        minimumBatteryLevel: Double = 0.20
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.frequency = frequency
        self.wifiOnly = wifiOnly
        self.allowBackgroundSync = allowBackgroundSync
        self.enableRealtimeSync = enableRealtimeSync
        self.conflictResolution = conflictResolution
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
        self.useExponentialBackoff = useExponentialBackoff
        self.includedEntities = includedEntities
        self.excludedEntities = excludedEntities
        self.syncDeleted = syncDeleted
        self.maxItemAge = maxItemAge
        self.batchSize = max(1, batchSize)
        self.maxSyncDuration = max(0, maxSyncDuration)
        self.pauseOnLowBattery = pauseOnLowBattery
        self.minimumBatteryLevel = max(0.0, min(1.0, minimumBatteryLevel))
    }
}

// MARK: - Supporting Types

// MARK: - Predefined Policies

extension SyncPolicy {
    /// Conservative sync policy - Wi-Fi only, infrequent sync
    public static var conservative: SyncPolicy {
        SyncPolicy(
            name: "Conservative",
            frequency: .interval(3600), // 1 hour
            wifiOnly: true,
            allowBackgroundSync: false,
            enableRealtimeSync: false,
            maxRetries: 2,
            batchSize: 50,
            pauseOnLowBattery: true,
            minimumBatteryLevel: 0.30
        )
    }
    
    /// Balanced sync policy - default settings
    public static var balanced: SyncPolicy {
        SyncPolicy(
            name: "Balanced",
            frequency: .automatic,
            wifiOnly: false,
            allowBackgroundSync: true,
            enableRealtimeSync: true,
            maxRetries: 3,
            batchSize: 100
        )
    }
    
    /// Aggressive sync policy - frequent sync, all conditions
    public static var aggressive: SyncPolicy {
        SyncPolicy(
            name: "Aggressive",
            frequency: .onChange,
            wifiOnly: false,
            allowBackgroundSync: true,
            enableRealtimeSync: true,
            maxRetries: 5,
            retryDelay: 2.0,
            batchSize: 200,
            pauseOnLowBattery: false,
            minimumBatteryLevel: 0.10
        )
    }
    
    /// Manual sync policy - only sync when explicitly triggered
    public static var manual: SyncPolicy {
        SyncPolicy(
            name: "Manual",
            frequency: .manual,
            allowBackgroundSync: false,
            enableRealtimeSync: false
        )
    }
    
    /// Real-time sync policy - optimized for live updates
    public static var realtime: SyncPolicy {
        SyncPolicy(
            name: "Real-time",
            frequency: .onChange,
            enableRealtimeSync: true,
            conflictResolution: .lastWriteWins,
            maxRetries: 5,
            retryDelay: 1.0,
            batchSize: 50
        )
    }
}

// MARK: - SyncPolicy Extensions

extension SyncPolicy {
    /// Check if sync is allowed given current conditions
    public func isSyncAllowed(
        isWifi: Bool,
        batteryLevel: Double,
        isBackground: Bool
    ) -> Bool {
        // Check if policy is enabled
        guard isEnabled else { return false }
        
        // Check Wi-Fi requirement
        if wifiOnly && !isWifi {
            return false
        }
        
        // Check background sync allowance
        if isBackground && !allowBackgroundSync {
            return false
        }
        
        // Check battery level
        if pauseOnLowBattery && batteryLevel < minimumBatteryLevel {
            return false
        }
        
        return true
    }
    
    /// Check if an entity should be included in sync
    public func shouldSyncEntity(_ entityType: String) -> Bool {
        // If there are included entities, only sync those
        if !includedEntities.isEmpty {
            return includedEntities.contains(entityType)
        }
        
        // Otherwise, sync everything except excluded entities
        return !excludedEntities.contains(entityType)
    }
    
    /// Calculate retry delay for given attempt number
    public func retryDelayFor(attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        
        if useExponentialBackoff {
            return retryDelay * pow(2.0, Double(attempt - 1))
        } else {
            return retryDelay
        }
    }
    
    /// Check if an item is within the age limit for sync
    public func isWithinAgeLimit(_ date: Date) -> Bool {
        guard let maxAge = maxItemAge else { return true }
        return Date().timeIntervalSince(date) <= maxAge
    }
    
    /// Create a copy with updated enabled state
    public func withEnabled(_ enabled: Bool) -> SyncPolicy {
        SyncPolicy(
            id: id,
            name: name,
            isEnabled: enabled,
            createdAt: createdAt,
            updatedAt: Date(),
            frequency: frequency,
            wifiOnly: wifiOnly,
            allowBackgroundSync: allowBackgroundSync,
            enableRealtimeSync: enableRealtimeSync,
            conflictResolution: conflictResolution,
            maxRetries: maxRetries,
            retryDelay: retryDelay,
            useExponentialBackoff: useExponentialBackoff,
            includedEntities: includedEntities,
            excludedEntities: excludedEntities,
            syncDeleted: syncDeleted,
            maxItemAge: maxItemAge,
            batchSize: batchSize,
            maxSyncDuration: maxSyncDuration,
            pauseOnLowBattery: pauseOnLowBattery,
            minimumBatteryLevel: minimumBatteryLevel
        )
    }
    
    /// Create a copy with updated frequency
    public func withFrequency(_ newFrequency: SyncFrequency) -> SyncPolicy {
        SyncPolicy(
            id: id,
            name: name,
            isEnabled: isEnabled,
            createdAt: createdAt,
            updatedAt: Date(),
            frequency: newFrequency,
            wifiOnly: wifiOnly,
            allowBackgroundSync: allowBackgroundSync,
            enableRealtimeSync: enableRealtimeSync,
            conflictResolution: conflictResolution,
            maxRetries: maxRetries,
            retryDelay: retryDelay,
            useExponentialBackoff: useExponentialBackoff,
            includedEntities: includedEntities,
            excludedEntities: excludedEntities,
            syncDeleted: syncDeleted,
            maxItemAge: maxItemAge,
            batchSize: batchSize,
            maxSyncDuration: maxSyncDuration,
            pauseOnLowBattery: pauseOnLowBattery,
            minimumBatteryLevel: minimumBatteryLevel
        )
    }
}

// MARK: - Equatable & Hashable

extension SyncPolicy: Equatable {
    public static func == (lhs: SyncPolicy, rhs: SyncPolicy) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.isEnabled == rhs.isEnabled &&
               lhs.frequency == rhs.frequency
    }
}

extension SyncPolicy: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(isEnabled)
        hasher.combine(frequency)
    }
}

// MARK: - Codable Support

extension SyncPolicy: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name
        case isEnabled = "is_enabled"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case frequency
        case wifiOnly = "wifi_only"
        case allowBackgroundSync = "allow_background_sync"
        case enableRealtimeSync = "enable_realtime_sync"
        case conflictResolution = "conflict_resolution"
        case maxRetries = "max_retries"
        case retryDelay = "retry_delay"
        case useExponentialBackoff = "use_exponential_backoff"
        case includedEntities = "included_entities"
        case excludedEntities = "excluded_entities"
        case syncDeleted = "sync_deleted"
        case maxItemAge = "max_item_age"
        case batchSize = "batch_size"
        case maxSyncDuration = "max_sync_duration"
        case pauseOnLowBattery = "pause_on_low_battery"
        case minimumBatteryLevel = "minimum_battery_level"
    }
}

