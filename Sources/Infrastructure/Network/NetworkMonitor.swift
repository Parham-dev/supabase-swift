//
//  NetworkMonitor.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Network
import Combine

/// Monitors network connectivity and quality
/// Provides real-time network status updates
@available(iOS 12.0, macOS 10.14, watchOS 5.0, tvOS 12.0, *)
public final class NetworkMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current network connection status
    @Published public private(set) var isConnected: Bool = true
    
    /// Current network connection type
    @Published public private(set) var connectionType: ConnectionType = .unknown
    
    /// Whether the connection is expensive (cellular, personal hotspot, etc.)
    @Published public private(set) var isExpensive: Bool = false
    
    /// Whether the connection is constrained (low data mode)
    @Published public private(set) var isConstrained: Bool = false
    
    // MARK: - Properties
    
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    /// Shared network monitor instance
    public static let shared = NetworkMonitor()
    
    // MARK: - Initialization
    
    /// Initialize network monitor
    /// - Parameter queue: Dispatch queue for network updates (defaults to background queue)
    public init(queue: DispatchQueue = DispatchQueue(label: "network.monitor", qos: .background)) {
        self.monitor = NWPathMonitor()
        self.queue = queue
        
        setupMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start monitoring network changes
    public func startMonitoring() {
        monitor.start(queue: queue)
    }
    
    /// Stop monitoring network changes
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Check if network is suitable for sync operations
    /// - Parameter policy: Sync policy to check against
    /// - Returns: Whether network conditions meet policy requirements
    public func isSuitableForSync(policy: NetworkPolicy) -> Bool {
        guard isConnected else { return false }
        
        switch policy {
        case .wifiOnly:
            return connectionType == .wifi
        case .wifiOrCellular:
            return connectionType == .wifi || connectionType == .cellular
        case .any:
            return true
        case .none:
            return false
        }
    }
    
    /// Get current network quality estimate
    /// - Returns: Network quality assessment
    public func networkQuality() -> NetworkQuality {
        guard isConnected else { return .offline }
        
        if isConstrained {
            return .poor
        }
        
        switch connectionType {
        case .wifi:
            return .excellent
        case .cellular:
            return isExpensive ? .good : .fair
        case .wired:
            return .excellent
        default:
            return .unknown
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(from: path)
            }
        }
        
        startMonitoring()
    }
    
    private func updateNetworkStatus(from path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        
        if #available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *) {
            isConstrained = path.isConstrained
        }
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wired
        } else if path.usesInterfaceType(.loopback) {
            connectionType = .loopback
        } else {
            connectionType = .unknown
        }
    }
}

// MARK: - Supporting Types

/// Network connection type
public enum ConnectionType: String, CaseIterable {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case wired = "Wired"
    case loopback = "Loopback"
    case unknown = "Unknown"
    
    /// Human-readable description
    public var description: String {
        return self.rawValue
    }
    
    /// SF Symbol name for the connection type
    public var symbolName: String {
        switch self {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .wired:
            return "cable.connector"
        case .loopback:
            return "arrow.triangle.2.circlepath"
        case .unknown:
            return "questionmark"
        }
    }
}

/// Network synchronization policy
public enum NetworkPolicy: String, CaseIterable {
    case wifiOnly = "wifi_only"
    case wifiOrCellular = "wifi_or_cellular"
    case any = "any"
    case none = "none"
    
    /// Human-readable description
    public var description: String {
        switch self {
        case .wifiOnly:
            return "WiFi Only"
        case .wifiOrCellular:
            return "WiFi or Cellular"
        case .any:
            return "Any Connection"
        case .none:
            return "No Sync"
        }
    }
}

/// Network quality assessment
public enum NetworkQuality: String, CaseIterable {
    case offline = "Offline"
    case poor = "Poor"
    case fair = "Fair"
    case good = "Good"
    case excellent = "Excellent"
    case unknown = "Unknown"
    
    /// Color representation for UI
    public var color: String {
        switch self {
        case .offline:
            return "red"
        case .poor:
            return "orange"
        case .fair:
            return "yellow"
        case .good:
            return "green"
        case .excellent:
            return "blue"
        case .unknown:
            return "gray"
        }
    }
    
    /// Whether sync should be allowed with this quality
    public var allowsSync: Bool {
        switch self {
        case .offline, .unknown:
            return false
        default:
            return true
        }
    }
}

// MARK: - NetworkMonitor Publisher Extensions

@available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
public extension NetworkMonitor {
    
    /// Publisher for connection status changes
    var connectionStatusPublisher: AnyPublisher<Bool, Never> {
        $isConnected
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher for connection type changes
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        $connectionType
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    /// Publisher for network quality changes
    var networkQualityPublisher: AnyPublisher<NetworkQuality, Never> {
        Publishers.CombineLatest4(
            $isConnected,
            $connectionType,
            $isExpensive,
            $isConstrained
        )
        .map { [weak self] _ in
            self?.networkQuality() ?? .unknown
        }
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}

// MARK: - Network Availability Helpers

public extension NetworkMonitor {
    
    /// Wait for network connection with timeout
    /// - Parameter timeout: Maximum time to wait for connection
    /// - Returns: Whether connection was established
    @available(iOS 13.0, macOS 10.15, watchOS 6.0, tvOS 13.0, *)
    func waitForConnection(timeout: TimeInterval = 30.0) async -> Bool {
        if isConnected { return true }
        
        return await withTaskGroup(of: Bool.self) { group in
            // Start timeout task
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return false
            }
            
            // Start connection monitoring task
            group.addTask { [weak self] in
                guard let self = self else { return false }
                
                // Monitor connection status changes
                return await withTaskCancellationHandler {
                    await withCheckedContinuation { continuation in
                        var cancellable: AnyCancellable?
                        cancellable = self.connectionStatusPublisher
                            .filter { $0 } // Only interested in connected state
                            .first()
                            .sink { _ in
                                continuation.resume(returning: true)
                                cancellable?.cancel()
                            }
                    }
                } onCancel: {
                    // Task was cancelled, return false
                }
            }
            
            // Return first result (either timeout or connection established)
            for await result in group {
                group.cancelAll()
                return result
            }
            
            return false
        }
    }
}