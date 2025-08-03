//
//  SyncObservers.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Foundation
import Dispatch

// MARK: - Sync Observer Manager

/// Internal manager for sync observers using weak references
internal final class SyncObserverManager: @unchecked Sendable {
    private var observers: [WeakSyncObserver] = []
    private let queue = DispatchQueue(label: "sync.observers", qos: .userInteractive)
    
    func addObserver(_ observer: SyncObserver) {
        queue.async {
            // Remove any nil references
            self.observers = self.observers.filter { $0.observer != nil }
            
            // Add new observer if not already present
            if !self.observers.contains(where: { $0.observer === observer }) {
                self.observers.append(WeakSyncObserver(observer: observer))
            }
        }
    }
    
    func removeObserver(_ observer: SyncObserver) {
        queue.async {
            self.observers = self.observers.filter { $0.observer !== observer }
        }
    }
    
    func notifyStatusChange(_ status: PublicSyncStatus) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncStatusDidChange(status)
            }
        }
    }
    
    func notifyProgressUpdate(_ progress: Double) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncProgressDidUpdate(progress)
            }
        }
    }
    
    func notifyCompletion(_ result: PublicSyncResult) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncDidComplete(result)
            }
        }
    }
    
    func notifyFailure(_ error: SwiftSupabaseSyncError) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncDidFail(error)
            }
        }
    }
    
    func notifyConflicts(_ conflicts: [ConflictInfo]) {
        queue.async {
            self.observers = self.observers.filter { $0.observer != nil }
            for observer in self.observers {
                observer.observer?.syncDidDetectConflicts(conflicts)
            }
        }
    }
    
    /// Remove all observers
    func removeAllObservers() {
        queue.async {
            self.observers.removeAll()
        }
    }
    
    /// Get current observer count (for debugging)
    func observerCount() -> Int {
        return queue.sync {
            self.observers.filter { $0.observer != nil }.count
        }
    }
    
    private func cleanupDeallocatedObservers() {
        observers = observers.filter { $0.observer != nil }
    }
}

// MARK: - Weak Observer Wrapper

/// Weak reference wrapper for sync observers
internal struct WeakSyncObserver {
    weak var observer: SyncObserver?
}

// MARK: - SyncAPI Observer Extensions

public extension SyncAPI {
    
    /// Add an observer for sync events
    /// - Parameter observer: The observer to add
    func addObserver(_ observer: SyncObserver) {
        observerManager.addObserver(observer)
    }
    
    /// Remove an observer
    /// - Parameter observer: The observer to remove
    func removeObserver(_ observer: SyncObserver) {
        observerManager.removeObserver(observer)
    }
    
    /// Remove all observers
    func removeAllObservers() {
        observerManager.removeAllObservers()
    }
    
    /// Get current number of observers (for debugging)
    var observerCount: Int {
        return observerManager.observerCount()
    }
}