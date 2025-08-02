//
//  SyncConflictResolutionService.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import CryptoKit

/// Service responsible for applying conflict resolutions to local storage
/// Handles the actual application of resolved conflicts with proper data conversion
internal final class SyncConflictResolutionService {
    
    // MARK: - Dependencies
    
    private let localDataSource: LocalDataSource
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Initialization
    
    public init(
        localDataSource: LocalDataSource,
        logger: SyncLoggerProtocol? = nil
    ) {
        self.localDataSource = localDataSource
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Apply multiple conflict resolutions
    /// - Parameter resolutions: Array of conflict resolutions to apply
    /// - Returns: Array of application results
    public func applyConflictResolutions(_ resolutions: [ConflictResolution]) async throws -> [ConflictApplicationResult] {
        logger?.debug("SyncConflictResolutionService: Applying \(resolutions.count) conflict resolutions")
        
        var results: [ConflictApplicationResult] = []
        
        for resolution in resolutions {
            do {
                let success = try await applyConflictResolution(resolution)
                let result = ConflictApplicationResult(
                    resolution: resolution,
                    success: success
                )
                results.append(result)
                
            } catch {
                logger?.error("SyncConflictResolutionService: Failed to apply conflict resolution - \(error.localizedDescription)")
                let result = ConflictApplicationResult(
                    resolution: resolution,
                    success: false,
                    error: SyncError.unknownError(error.localizedDescription)
                )
                results.append(result)
            }
        }
        
        let successCount = results.filter { $0.success }.count
        logger?.info("SyncConflictResolutionService: Applied \(successCount)/\(results.count) conflict resolutions successfully")
        return results
    }
    
    // MARK: - Private Methods
    
    /// Apply a single conflict resolution
    /// - Parameter resolution: The conflict resolution to apply
    /// - Returns: Whether the resolution was applied successfully
    private func applyConflictResolution(_ resolution: ConflictResolution) async throws -> Bool {
        switch resolution.strategy {
        case .lastWriteWins:
            // Use the version with the most recent timestamp
            if let data = resolution.resolvedData {
                return try await applyResolvedData(data, using: resolution)
            }
            return false
            
        case .firstWriteWins:
            // Use the version with the earliest timestamp
            if let data = resolution.resolvedData {
                return try await applyResolvedData(data, using: resolution)
            }
            return false
            
        case .manual:
            // Apply manual resolution data
            if let data = resolution.resolvedData {
                return try await applyResolvedData(data, using: resolution)
            }
            return false
            
        case .localWins:
            // Apply local version
            if let data = resolution.resolvedData {
                return try await applyResolvedData(data, using: resolution)
            }
            return false
            
        case .remoteWins:
            // Apply remote version
            if let data = resolution.resolvedData {
                return try await applyResolvedData(data, using: resolution)
            }
            return false
        }
    }
    
    /// Apply resolved data to local storage
    /// - Parameters:
    ///   - data: The resolved record data
    ///   - resolution: The conflict resolution metadata
    /// - Returns: Whether the data was applied successfully
    private func applyResolvedData(_ data: [String: Any], using resolution: ConflictResolution) async throws -> Bool {
        // Convert resolved data to SyncSnapshot for application
        guard let syncIDString = data["sync_id"] as? String,
              let syncID = UUID(uuidString: syncIDString),
              let tableName = data["table_name"] as? String,
              let version = data["version"] as? Int,
              let lastModifiedTimestamp = data["last_modified"] as? Double,
              let isDeleted = data["is_deleted"] as? Bool else {
            logger?.error("SyncConflictResolutionService: Invalid resolved data format")
            return false
        }
        
        let lastModified = Date(timeIntervalSince1970: lastModifiedTimestamp)
        let lastSynced = Date() // Mark as just synced
        
        // Create content hash from resolved data
        let contentHash = generateContentHashFromData(data)
        
        let resolvedSnapshot = SyncSnapshot(
            syncID: syncID,
            tableName: tableName,
            version: version,
            lastModified: lastModified,
            lastSynced: lastSynced,
            isDeleted: isDeleted,
            contentHash: contentHash,
            conflictData: [:]
        )
        
        // Apply the resolved snapshot to local storage
        let applicationResults = localDataSource.applyRemoteChanges([resolvedSnapshot])
        
        return applicationResults.first?.success ?? false
    }
    
    /// Generate content hash from resolved data
    /// - Parameter data: The resolved record data
    /// - Returns: Content hash string
    private func generateContentHashFromData(_ data: [String: Any]) -> String {
        // Create sorted components from the data
        var components: [String] = []
        
        for (key, value) in data.sorted(by: { $0.key < $1.key }) {
            // Skip metadata fields
            if !["sync_id", "table_name", "last_modified", "last_synced", "is_deleted", "version"].contains(key) {
                components.append("\(key):\(value)")
            }
        }
        
        let contentString = components.joined(separator: "|")
        return contentString.isEmpty ? "empty" : contentString.sha256
    }
}

// MARK: - String SHA256 Extension

private extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}