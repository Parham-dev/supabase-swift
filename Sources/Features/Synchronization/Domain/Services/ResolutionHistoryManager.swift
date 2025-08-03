//
//  ResolutionHistoryManager.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Actor responsible for managing conflict resolution history
/// Tracks resolved conflicts with automatic cleanup of old entries
internal actor ResolutionHistoryManager {
    
    // MARK: - Properties
    
    private var history: [ConflictResolutionRecord] = []
    private let retentionDays: Int
    
    // MARK: - Initialization
    
    /// Initialize history manager with retention policy
    /// - Parameter retentionDays: Number of days to retain history entries
    init(retentionDays: Int) {
        self.retentionDays = retentionDays
    }
    
    // MARK: - Public Methods
    
    /// Add a new resolution record to history
    /// - Parameter record: The conflict resolution record to add
    func addRecord(_ record: ConflictResolutionRecord) {
        history.append(record)
        cleanupOldEntries()
    }
    
    /// Get resolution history with optional filtering
    /// - Parameters:
    ///   - entityType: Optional entity type to filter by
    ///   - limit: Optional maximum number of records to return
    /// - Returns: Array of resolution records matching criteria
    func getHistory(entityType: String?, limit: Int?) -> [ConflictResolutionRecord] {
        var filteredHistory = history
        
        // Filter by entity type if specified
        if let entityType = entityType {
            filteredHistory = filteredHistory.filter { $0.entityType == entityType }
        }
        
        // Filter by date (only recent entries)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        filteredHistory = filteredHistory.filter { $0.resolvedAt >= cutoffDate }
        
        // Sort by resolution date (newest first)
        filteredHistory.sort { $0.resolvedAt > $1.resolvedAt }
        
        // Apply limit if specified
        if let limit = limit {
            filteredHistory = Array(filteredHistory.prefix(limit))
        }
        
        return filteredHistory
    }
    
    /// Get total number of records in history
    /// - Returns: Current history count
    func getHistoryCount() -> Int {
        return history.count
    }
    
    /// Clear all history records
    func clearHistory() {
        history.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Remove old entries based on retention policy
    private func cleanupOldEntries() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        history.removeAll { $0.resolvedAt < cutoffDate }
    }
}