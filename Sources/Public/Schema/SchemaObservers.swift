//
//  SchemaObservers.swift
//  SwiftSupabaseSync
//
//  Created by Parham on 03/08/2025.
//

import Foundation
import Combine

// MARK: - Schema Observer Manager

/// Internal class to manage schema observers
internal class SchemaObserverManager {
    private var observers: [WeakSchemaObserver] = []
    private let queue = DispatchQueue(label: "schema.observer.queue", attributes: .concurrent)
    
    func addObserver(_ observer: SchemaObserver) {
        queue.async(flags: .barrier) {
            self.observers.append(WeakSchemaObserver(observer))
            self.cleanupDeallocatedObservers()
        }
    }
    
    func removeObserver(_ observer: SchemaObserver) {
        queue.async(flags: .barrier) {
            self.observers.removeAll { $0.observer === observer }
        }
    }
    
    func removeAllObservers() {
        queue.async(flags: .barrier) {
            self.observers.removeAll()
        }
    }
    
    func notifyValidationCompleted(_ result: PublicSchemaValidation) {
        queue.async {
            self.observers.forEach { $0.observer?.schemaValidationCompleted(result) }
        }
    }
    
    func notifyMigrationCompleted(_ result: PublicSchemaMigration) {
        queue.async {
            self.observers.forEach { $0.observer?.schemaMigrationCompleted(result) }
        }
    }
    
    func notifyStatusChanged(_ status: PublicSchemaStatus, for modelName: String?) {
        queue.async {
            self.observers.forEach { $0.observer?.schemaStatusChanged(status, for: modelName) }
        }
    }
    
    func notifyErrorOccurred(_ error: SwiftSupabaseSyncError, for modelName: String) {
        queue.async {
            self.observers.forEach { $0.observer?.schemaErrorOccurred(error, for: modelName) }
        }
    }
    
    func notify(_ notification: @escaping (SchemaObserver) -> Void) {
        queue.async {
            self.cleanupDeallocatedObservers()
            
            for weakObserver in self.observers {
                if let observer = weakObserver.observer {
                    notification(observer)
                }
            }
        }
    }
    
    private func cleanupDeallocatedObservers() {
        observers.removeAll { $0.observer == nil }
    }
}

// MARK: - Weak Observer Wrapper

/// Weak reference wrapper for schema observers
internal class WeakSchemaObserver {
    weak var observer: SchemaObserver?
    
    init(_ observer: SchemaObserver) {
        self.observer = observer
    }
}

// MARK: - Schema API Observer Extensions

extension SchemaAPI {
    
    /// Add schema observer
    /// - Parameter observer: Observer to add
    public func addObserver(_ observer: SchemaObserver) {
        observerManager.addObserver(observer)
    }
    
    /// Remove schema observer
    /// - Parameter observer: Observer to remove
    public func removeObserver(_ observer: SchemaObserver) {
        observerManager.removeObserver(observer)
    }
    
    /// Remove all observers
    public func removeAllObservers() {
        observerManager.removeAllObservers()
    }
    
    /// Notify all observers with a custom notification
    /// - Parameter notification: Notification block to execute for each observer
    internal func notifyObservers(_ notification: @escaping (SchemaObserver) -> Void) {
        observerManager.notify(notification)
    }
}