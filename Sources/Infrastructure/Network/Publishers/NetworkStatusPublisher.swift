//
//  NetworkStatusPublisher.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Combine
import SwiftUI
import Network

/// Reactive publisher that wraps NetworkMonitor state for seamless SwiftUI integration
/// Provides clean, observable access to network status, connection type, and quality information
@available(iOS 12.0, macOS 10.14, watchOS 5.0, tvOS 12.0, *)
@MainActor
public final class NetworkStatusPublisher: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current network connection status
    @Published public private(set) var isConnected: Bool
    
    /// Current network connection type
    @Published public private(set) var connectionType: ConnectionType
    
    /// Whether the connection is expensive (cellular, personal hotspot, etc.)
    @Published public private(set) var isExpensive: Bool
    
    /// Whether the connection is constrained (low data mode)
    @Published public private(set) var isConstrained: Bool
    
    /// Current network quality assessment
    @Published public private(set) var networkQuality: NetworkQuality
    
    // MARK: - Derived Published Properties
    
    /// Whether network is suitable for sync operations
    @Published public private(set) var isSuitableForSync: Bool = true
    
    /// User-friendly network status description
    @Published public private(set) var statusDescription: String = "Unknown"
    
    /// Whether sync should be allowed in current network conditions
    @Published public private(set) var allowsSync: Bool = true
    
    /// Network quality color for UI indicators
    @Published public private(set) var qualityColor: Color = .gray
    
    /// Connection type icon name
    @Published public private(set) var connectionIcon: String = "questionmark"
    
    /// Whether network supports realtime operations
    @Published public private(set) var supportsRealtime: Bool = true
    
    // MARK: - Dependencies
    
    private let networkMonitor: NetworkMonitor
    private var cancellables = Set<AnyCancellable>()
    private var currentNetworkPolicy: NetworkPolicy = .wifiOrCellular
    
    // MARK: - Initialization
    
    public init(networkMonitor: NetworkMonitor = NetworkMonitor.shared) {
        self.networkMonitor = networkMonitor
        
        // Initialize with current values
        self.isConnected = networkMonitor.isConnected
        self.connectionType = networkMonitor.connectionType
        self.isExpensive = networkMonitor.isExpensive
        self.isConstrained = networkMonitor.isConstrained
        self.networkQuality = networkMonitor.networkQuality()
        
        // Calculate derived properties
        updateDerivedProperties()
        
        // Setup reactive bindings
        setupPublisherBindings()
    }
    
    // MARK: - Public Computed Properties
    
    /// Whether network is offline
    public var isOffline: Bool {
        !isConnected
    }
    
    /// Whether connection is on WiFi
    public var isOnWiFi: Bool {
        connectionType == .wifi
    }
    
    /// Whether connection is cellular
    public var isOnCellular: Bool {
        connectionType == .cellular
    }
    
    /// Whether connection is wired (ethernet)
    public var isOnWired: Bool {
        connectionType == .wired
    }
    
    /// Whether connection has good quality for data operations
    public var hasGoodQuality: Bool {
        switch networkQuality {
        case .good, .excellent:
            return true
        default:
            return false
        }
    }
    
    /// Whether connection might have limited bandwidth
    public var hasLimitedBandwidth: Bool {
        isExpensive || isConstrained || networkQuality == .poor
    }
    
    /// Network status suitable for large operations (like full sync)
    public var isSuitableForLargeOperations: Bool {
        isConnected && !isExpensive && !isConstrained && hasGoodQuality
    }
    
    /// Network status suitable for small operations (like incremental sync)
    public var isSuitableForSmallOperations: Bool {
        isConnected && networkQuality.allowsSync
    }
    
    // MARK: - Network Policy Management
    
    /// Update the network policy for sync operations
    /// - Parameter policy: New network policy to use
    public func updateNetworkPolicy(_ policy: NetworkPolicy) {
        currentNetworkPolicy = policy
        updateDerivedProperties()
    }
    
    /// Get current network policy
    public var networkPolicy: NetworkPolicy {
        currentNetworkPolicy
    }
    
    // MARK: - Network Quality Assessment
    
    /// Check if network is suitable for specific sync type
    /// - Parameter syncType: Type of sync operation
    /// - Returns: Whether network conditions are suitable
    public func isSuitableForSyncType(_ syncType: SyncType) -> Bool {
        guard isConnected else { return false }
        
        switch syncType {
        case .full:
            return isSuitableForLargeOperations && networkMonitor.isSuitableForSync(policy: currentNetworkPolicy)
        case .incremental:
            return isSuitableForSmallOperations && networkMonitor.isSuitableForSync(policy: currentNetworkPolicy)
        case .realtime:
            return supportsRealtime && networkMonitor.isSuitableForSync(policy: currentNetworkPolicy)
        case .backup:
            return isSuitableForLargeOperations && isOnWiFi // Backup only on WiFi
        }
    }
    
    /// Get recommended sync frequency based on network conditions
    /// - Returns: Recommended sync frequency
    public func recommendedSyncFrequency() -> NetworkBasedSyncFrequency {
        if !isConnected {
            return .never
        }
        
        if isExpensive || isConstrained {
            return .daily
        }
        
        switch networkQuality {
        case .excellent:
            return .realtime
        case .good:
            return .every5Minutes
        case .fair:
            return .every15Minutes
        case .poor:
            return .hourly
        case .offline, .unknown:
            return .never
        }
    }
    
    // MARK: - Network Operations
    
    /// Wait for network connection with timeout
    /// - Parameter timeout: Maximum time to wait for connection
    /// - Returns: Whether connection was established
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    public func waitForConnection(timeout: TimeInterval = 30.0) async -> Bool {
        return await networkMonitor.waitForConnection(timeout: timeout)
    }
    
    /// Start network monitoring
    public func startMonitoring() {
        networkMonitor.startMonitoring()
    }
    
    /// Stop network monitoring
    public func stopMonitoring() {
        networkMonitor.stopMonitoring()
    }
    
    // MARK: - Private Implementation
    
    private func setupPublisherBindings() {
        // Bind NetworkMonitor's published properties to our published properties
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isConnected = isConnected
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        networkMonitor.$connectionType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connectionType in
                self?.connectionType = connectionType
                self?.connectionIcon = connectionType.symbolName
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        networkMonitor.$isExpensive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isExpensive in
                self?.isExpensive = isExpensive
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        networkMonitor.$isConstrained
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConstrained in
                self?.isConstrained = isConstrained
                self?.updateDerivedProperties()
            }
            .store(in: &cancellables)
        
        // Monitor network quality changes (iOS 13+ for complex publishers)
        if #available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *) {
            networkMonitor.networkQualityPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] quality in
                    self?.networkQuality = quality
                    self?.updateDerivedProperties()
                }
                .store(in: &cancellables)
        }
    }
    
    private func updateDerivedProperties() {
        // Update network quality manually for older iOS versions
        if #unavailable(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0) {
            networkQuality = networkMonitor.networkQuality()
        }
        
        // Update status description
        if !isConnected {
            statusDescription = "Offline"
        } else {
            var description = connectionType.description
            
            if isExpensive {
                description += " (Expensive)"
            }
            
            if isConstrained {
                description += " (Limited)"
            }
            
            statusDescription = description
        }
        
        // Update sync suitability
        isSuitableForSync = networkMonitor.isSuitableForSync(policy: currentNetworkPolicy)
        allowsSync = networkQuality.allowsSync
        
        // Update quality color
        qualityColor = colorForNetworkQuality(networkQuality)
        
        // Update realtime support
        supportsRealtime = isConnected && !isConstrained && hasGoodQuality
    }
    
    private func colorForNetworkQuality(_ quality: NetworkQuality) -> Color {
        switch quality {
        case .offline:
            return .red
        case .poor:
            return .orange
        case .fair:
            return .yellow
        case .good:
            return .green
        case .excellent:
            return .blue
        case .unknown:
            return .gray
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - SwiftUI Convenience Extensions

@available(iOS 12.0, macOS 10.14, watchOS 5.0, tvOS 12.0, *)
public extension NetworkStatusPublisher {
    
    /// Network status indicator view
    var statusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: connectionIcon)
                .foregroundColor(qualityColor)
            
            Text(statusDescription)
                .font(.caption)
                .foregroundColor(qualityColor)
        }
    }
    
    /// Simple connectivity indicator
    var connectivityIndicator: some View {
        Circle()
            .fill(isConnected ? Color.green : Color.red)
            .frame(width: 8, height: 8)
    }
    
    /// Network quality badge
    var qualityBadge: some View {
        Text(networkQuality.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(qualityColor.opacity(0.2))
            .foregroundColor(qualityColor)
            .cornerRadius(4)
    }
    
    /// Warning icon for expensive/constrained connections
    @ViewBuilder
    var connectionWarning: some View {
        if isExpensive || isConstrained {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
        }
    }
}

// MARK: - Combine Publishers

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public extension NetworkStatusPublisher {
    
    /// Publisher that emits when connection status changes
    var connectionStatusPublisher: AnyPublisher<Bool, Never> {
        $isConnected
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when connection type changes
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        $connectionType
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when network quality changes
    var networkQualityPublisher: AnyPublisher<NetworkQuality, Never> {
        $networkQuality
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when sync suitability changes
    var syncSuitabilityPublisher: AnyPublisher<Bool, Never> {
        $isSuitableForSync
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher that emits when network conditions change significantly
    var networkConditionsPublisher: AnyPublisher<NetworkConditions, Never> {
        Publishers.CombineLatest4(
            $isConnected,
            $connectionType,
            $isExpensive,
            $isConstrained
        )
        .map { isConnected, type, expensive, constrained in
            NetworkConditions(
                isConnected: isConnected,
                connectionType: type,
                isExpensive: expensive,
                isConstrained: constrained
            )
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}

// MARK: - Supporting Types

/// Type of sync operation for network suitability checking
public enum SyncType {
    case full
    case incremental
    case realtime
    case backup
}

/// Network conditions snapshot
public struct NetworkConditions: Equatable {
    public let isConnected: Bool
    public let connectionType: ConnectionType
    public let isExpensive: Bool
    public let isConstrained: Bool
    
    /// Whether conditions are suitable for sync
    public var isSuitableForSync: Bool {
        isConnected && !isExpensive && !isConstrained
    }
}

/// Network-based sync frequency recommendations
public enum NetworkBasedSyncFrequency: CaseIterable {
    case never
    case daily
    case hourly
    case every15Minutes
    case every5Minutes
    case realtime
    
    public var description: String {
        switch self {
        case .never: return "Never"
        case .daily: return "Daily"
        case .hourly: return "Hourly"
        case .every15Minutes: return "Every 15 minutes"
        case .every5Minutes: return "Every 5 minutes"
        case .realtime: return "Real-time"
        }
    }
    
    public var interval: TimeInterval? {
        switch self {
        case .never: return nil
        case .daily: return 86400
        case .hourly: return 3600
        case .every15Minutes: return 900
        case .every5Minutes: return 300
        case .realtime: return 0
        }
    }
}