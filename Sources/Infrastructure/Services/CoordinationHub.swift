//
//  CoordinationHub.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import Combine

/// Central coordination hub for managing inter-manager communication and state coordination
/// Provides event-driven coordination between AuthManager, SyncManager, SchemaManager, and SubscriptionManager
@MainActor
internal final class CoordinationHub: ObservableObject {
    
    // MARK: - Singleton
    
    /// Shared coordination hub instance
    internal static let shared = CoordinationHub()
    
    // MARK: - Published Properties
    
    /// Current coordination state
    @Published internal private(set) var coordinationState: CoordinationState = .idle
    
    /// Active coordination events being processed
    @Published internal private(set) var activeEvents: [CoordinationEvent] = []
    
    /// Last coordination error
    @Published internal private(set) var lastError: CoordinationError?
    
    // MARK: - Private Properties
    
    /// Event handling state
    private var eventHandlingSetup: Bool = false
    
    private let eventSubject = PassthroughSubject<CoordinationEvent, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var eventHandlers: [CoordinationEventType: [(CoordinationEvent) async -> Void]] = [:]
    private let coordinationQueue = DispatchQueue(label: "coordination.hub", qos: .userInitiated)
    
    // MARK: - Event Publishers
    
    /// Publisher for all coordination events
    public var eventPublisher: AnyPublisher<CoordinationEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for authentication events
    public var authEventPublisher: AnyPublisher<CoordinationEvent, Never> {
        eventSubject
            .filter { $0.type.isAuthenticationEvent }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for sync events
    public var syncEventPublisher: AnyPublisher<CoordinationEvent, Never> {
        eventSubject
            .filter { $0.type.isSyncEvent }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for network events
    public var networkEventPublisher: AnyPublisher<CoordinationEvent, Never> {
        eventSubject
            .filter { $0.type.isNetworkEvent }
            .eraseToAnyPublisher()
    }
    
    /// Publisher for subscription events
    public var subscriptionEventPublisher: AnyPublisher<CoordinationEvent, Never> {
        eventSubject
            .filter { $0.type.isSubscriptionEvent }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    private init() {
        Task { @MainActor in
            setupEventHandling()
            eventHandlingSetup = true
        }
    }
    
    // MARK: - Event Publishing
    
    /// Publish a coordination event
    /// - Parameter event: Event to publish
    internal func publish(_ event: CoordinationEvent) {
        Task {
            await ensureEventHandlingSetup()
            
            await MainActor.run {
                self.activeEvents.append(event)
                self.coordinationState = .coordinating
            }
            
            // Notify subscribers
            eventSubject.send(event)
            
            // Handle event internally
            await handleEvent(event)
            
            await MainActor.run {
                self.activeEvents.removeAll { $0.id == event.id }
                if self.activeEvents.isEmpty {
                    self.coordinationState = .idle
                }
            }
        }
    }
    
    /// Ensure event handling is properly set up
    private func ensureEventHandlingSetup() async {
        await MainActor.run {
            if !eventHandlingSetup {
                setupEventHandling()
                eventHandlingSetup = true
            }
        }
    }
    
    /// Convenience method to publish authentication state change
    /// - Parameters:
    ///   - user: Current user (nil if signed out)
    ///   - isAuthenticated: Whether user is authenticated
    ///   - authStatus: Current authentication status
    internal func publishAuthStateChanged(
        user: User?,
        isAuthenticated: Bool,
        authStatus: AuthenticationStatus
    ) {
        let event = CoordinationEvent(
            type: .authStateChanged,
            data: [
                "user": user as Any,
                "isAuthenticated": isAuthenticated,
                "authStatus": authStatus
            ]
        )
        publish(event)
    }
    
    /// Convenience method to publish sync state change
    /// - Parameters:
    ///   - syncState: Current sync state
    ///   - isSyncing: Whether sync is active
    ///   - progress: Sync progress (0.0 to 1.0)
    internal func publishSyncStateChanged(
        syncState: SyncState,
        isSyncing: Bool,
        progress: Double
    ) {
        let event = CoordinationEvent(
            type: .syncStateChanged,
            data: [
                "syncState": syncState,
                "isSyncing": isSyncing,
                "progress": progress
            ]
        )
        publish(event)
    }
    
    /// Convenience method to publish network state change
    /// - Parameters:
    ///   - isConnected: Whether network is connected
    ///   - connectionType: Type of network connection
    ///   - isExpensive: Whether connection is expensive
    internal func publishNetworkStateChanged(
        isConnected: Bool,
        connectionType: ConnectionType,
        isExpensive: Bool
    ) {
        let event = CoordinationEvent(
            type: .networkStateChanged,
            data: [
                "isConnected": isConnected,
                "connectionType": connectionType,
                "isExpensive": isExpensive
            ]
        )
        publish(event)
    }
    
    /// Convenience method to publish subscription change
    /// - Parameters:
    ///   - tier: Current subscription tier
    ///   - isValid: Whether subscription is valid
    ///   - features: Available features
    internal func publishSubscriptionChanged(
        tier: SubscriptionTier,
        isValid: Bool,
        features: Set<Feature>
    ) {
        let event = CoordinationEvent(
            type: .subscriptionChanged,
            data: [
                "tier": tier,
                "isValid": isValid,
                "features": features
            ]
        )
        publish(event)
    }
    
    // MARK: - Event Handling Registration
    
    /// Register a handler for specific event types
    /// - Parameters:
    ///   - eventType: Type of event to handle
    ///   - handler: Handler function to execute
    internal func registerHandler(
        for eventType: CoordinationEventType,
        handler: @escaping (CoordinationEvent) async -> Void
    ) {
        if eventHandlers[eventType] == nil {
            eventHandlers[eventType] = []
        }
        eventHandlers[eventType]?.append(handler)
    }
    
    /// Remove all handlers for a specific event type
    /// - Parameter eventType: Event type to clear handlers for
    internal func clearHandlers(for eventType: CoordinationEventType) {
        eventHandlers[eventType] = []
    }
    
    // MARK: - Coordination Actions
    
    /// Coordinate authentication state change across all managers
    /// - Parameter user: New user state
    internal func coordinateAuthenticationChange(_ user: User?) async {
        let isAuthenticated = user != nil
        let authStatus = user?.authenticationStatus ?? .unauthenticated
        
        publishAuthStateChanged(
            user: user,
            isAuthenticated: isAuthenticated,
            authStatus: authStatus
        )
        
        // Additional coordination logic can be added here
        if !isAuthenticated {
            // User signed out - coordinate cleanup
            let cleanupEvent = CoordinationEvent(
                type: .authCleanupRequired,
                data: ["reason": "user_signed_out"]
            )
            publish(cleanupEvent)
        }
    }
    
    /// Coordinate network state change response
    /// - Parameters:
    ///   - isConnected: Whether network is connected
    ///   - connectionType: Type of connection
    internal func coordinateNetworkChange(isConnected: Bool, connectionType: ConnectionType) async {
        publishNetworkStateChanged(
            isConnected: isConnected,
            connectionType: connectionType,
            isExpensive: connectionType.isExpensive
        )
        
        if !isConnected {
            // Network disconnected - coordinate offline mode
            let offlineEvent = CoordinationEvent(
                type: .offlineModeActivated,
                data: ["reason": "network_disconnected"]
            )
            publish(offlineEvent)
        } else {
            // Network reconnected - coordinate sync resume
            let onlineEvent = CoordinationEvent(
                type: .onlineModeActivated,
                data: ["connectionType": connectionType]
            )
            publish(onlineEvent)
        }
    }
    
    /// Coordinate sync error across managers
    /// - Parameter error: Sync error that occurred
    internal func coordinateSyncError(_ error: SyncError) async {
        let event = CoordinationEvent(
            type: .syncErrorOccurred,
            data: [
                "error": error,
                "isRecoverable": error.isRecoverable,
                "retryDelay": error.retryDelay
            ]
        )
        publish(event)
    }
    
    // MARK: - Private Event Handling
    
    private func setupEventHandling() {
        // Set up default event handling patterns
        registerHandler(for: .authStateChanged) { [weak self] event in
            await self?.handleAuthStateChange(event)
        }
        
        registerHandler(for: .networkStateChanged) { [weak self] event in
            await self?.handleNetworkStateChange(event)
        }
        
        registerHandler(for: .syncErrorOccurred) { [weak self] event in
            await self?.handleSyncError(event)
        }
    }
    
    private func handleEvent(_ event: CoordinationEvent) async {
        guard let handlers = eventHandlers[event.type] else { return }
        
        for handler in handlers {
            do {
                await handler(event)
            } catch {
                await setError(.handlerExecutionFailed(event.type, error))
            }
        }
    }
    
    private func handleAuthStateChange(_ event: CoordinationEvent) async {
        guard let isAuthenticated = event.data["isAuthenticated"] as? Bool else { return }
        
        if !isAuthenticated {
            // User signed out - coordinate cleanup across managers
            // This would typically trigger:
            // - Subscription refresh
            // - Sync pause
            // - Cache clearing
            // - Connection cleanup
        }
    }
    
    private func handleNetworkStateChange(_ event: CoordinationEvent) async {
        guard let isConnected = event.data["isConnected"] as? Bool else { return }
        
        if isConnected {
            // Network reconnected - coordinate reconnection
            let reconnectEvent = CoordinationEvent(
                type: .coordinationRequired,
                data: ["action": "network_reconnect"]
            )
            publish(reconnectEvent)
        }
    }
    
    private func handleSyncError(_ event: CoordinationEvent) async {
        guard let error = event.data["error"] as? SyncError else { return }
        
        if error.isRecoverable {
            // Schedule retry coordination
            let retryEvent = CoordinationEvent(
                type: .retryRequired,
                data: [
                    "error": error,
                    "delay": error.retryDelay
                ]
            )
            
            // Delay before publishing retry event
            try? await Task.sleep(nanoseconds: UInt64(error.retryDelay * 1_000_000_000))
            publish(retryEvent)
        }
    }
    
    private func setError(_ error: CoordinationError) async {
        await MainActor.run {
            self.lastError = error
            self.coordinationState = .error
        }
    }
    
    // MARK: - State Management
    
    /// Clear all coordination errors
    internal func clearErrors() {
        Task {
            await MainActor.run {
                self.lastError = nil
                if self.coordinationState == .error {
                    self.coordinationState = .idle
                }
            }
        }
    }
    
    /// Reset coordination hub to initial state
    internal func reset() {
        Task {
            await MainActor.run {
                self.activeEvents.removeAll()
                self.lastError = nil
                self.coordinationState = .idle
            }
            
            eventHandlers.removeAll()
            setupEventHandling()
        }
    }
}

// MARK: - Supporting Types

/// Coordination event for cross-manager communication
public struct CoordinationEvent: Identifiable, Equatable {
    public let id: UUID
    public let type: CoordinationEventType
    public let data: [String: Any]
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        type: CoordinationEventType,
        data: [String: Any] = [:],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.timestamp = timestamp
    }
    
    public static func == (lhs: CoordinationEvent, rhs: CoordinationEvent) -> Bool {
        lhs.id == rhs.id
    }
}

/// Types of coordination events
public enum CoordinationEventType: String, CaseIterable {
    // Authentication events
    case authStateChanged = "auth_state_changed"
    case authCleanupRequired = "auth_cleanup_required"
    case tokenRefreshRequired = "token_refresh_required"
    
    // Sync events
    case syncStateChanged = "sync_state_changed"
    case syncErrorOccurred = "sync_error_occurred"
    case syncPauseRequired = "sync_pause_required"
    case syncResumeRequired = "sync_resume_required"
    
    // Network events
    case networkStateChanged = "network_state_changed"
    case offlineModeActivated = "offline_mode_activated"
    case onlineModeActivated = "online_mode_activated"
    
    // Subscription events
    case subscriptionChanged = "subscription_changed"
    case subscriptionValidationRequired = "subscription_validation_required"
    case featureAccessChanged = "feature_access_changed"
    
    // Schema events
    case schemaChanged = "schema_changed"
    case modelRegistered = "model_registered"
    case modelUnregistered = "model_unregistered"
    
    // Coordination events
    case coordinationRequired = "coordination_required"
    case retryRequired = "retry_required"
    case cacheInvalidationRequired = "cache_invalidation_required"
    
    // Event type categories
    var isAuthenticationEvent: Bool {
        switch self {
        case .authStateChanged, .authCleanupRequired, .tokenRefreshRequired:
            return true
        default:
            return false
        }
    }
    
    var isSyncEvent: Bool {
        switch self {
        case .syncStateChanged, .syncErrorOccurred, .syncPauseRequired, .syncResumeRequired:
            return true
        default:
            return false
        }
    }
    
    var isNetworkEvent: Bool {
        switch self {
        case .networkStateChanged, .offlineModeActivated, .onlineModeActivated:
            return true
        default:
            return false
        }
    }
    
    var isSubscriptionEvent: Bool {
        switch self {
        case .subscriptionChanged, .subscriptionValidationRequired, .featureAccessChanged:
            return true
        default:
            return false
        }
    }
}

/// Coordination state
public enum CoordinationState: String, CaseIterable {
    case idle = "idle"
    case coordinating = "coordinating"
    case error = "error"
}

/// Coordination errors
public enum CoordinationError: Error, LocalizedError {
    case handlerExecutionFailed(CoordinationEventType, Error)
    case invalidEventData(CoordinationEventType, String)
    case coordinationTimeout(CoordinationEventType)
    
    public var errorDescription: String? {
        switch self {
        case .handlerExecutionFailed(let eventType, let error):
            return "Handler execution failed for \(eventType.rawValue): \(error.localizedDescription)"
        case .invalidEventData(let eventType, let reason):
            return "Invalid event data for \(eventType.rawValue): \(reason)"
        case .coordinationTimeout(let eventType):
            return "Coordination timeout for \(eventType.rawValue)"
        }
    }
}

// MARK: - ConnectionType Extension

extension ConnectionType {
    var isExpensive: Bool {
        switch self {
        case .cellular:
            return true
        case .wifi, .wired, .loopback, .unknown:
            return false
        }
    }
}