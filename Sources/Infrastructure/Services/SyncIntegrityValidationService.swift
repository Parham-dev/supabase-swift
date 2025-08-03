//
//  SyncIntegrityValidationService.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Service responsible for validating sync data integrity
/// Performs comprehensive checks on sync metadata, content hashes, and data consistency
internal final class SyncIntegrityValidationService {
    
    // MARK: - Dependencies
    
    private let localDataSource: LocalDataSource
    private let metadataManager: SyncMetadataManager
    private let logger: SyncLoggerProtocol?
    
    // MARK: - Initialization
    
    public init(
        localDataSource: LocalDataSource,
        metadataManager: SyncMetadataManager,
        logger: SyncLoggerProtocol? = nil
    ) {
        self.localDataSource = localDataSource
        self.metadataManager = metadataManager
        self.logger = logger
    }
    
    // MARK: - Public Methods
    
    /// Validate sync integrity for an entity type
    /// - Parameter entityType: Entity type to validate
    /// - Returns: Integrity validation result
    public func validateSyncIntegrity<T: Syncable>(for entityType: T.Type) async throws -> SyncIntegrityResult {
        logger?.debug("SyncIntegrityValidationService: Validating sync integrity for \(entityType)")
        
        let entityTypeName = String(describing: entityType)
        var issues: [IntegrityIssue] = []
        var recordsChecked = 0
        
        do {
            // Get all local records for this entity type
            let allLocalRecords = try localDataSource.fetchRecordsModifiedAfter(entityType, date: Date(timeIntervalSince1970: 0), limit: nil)
            recordsChecked = allLocalRecords.count
            
            for record in allLocalRecords {
                // Check 1: Validate content hash consistency
                let expectedHash = record.contentHash
                let actualHash = generateContentHash(for: record)
                
                if expectedHash != actualHash {
                    let issue = IntegrityIssue(
                        type: .checksumMismatch,
                        recordID: record.syncID,
                        description: "Content hash mismatch: expected \(expectedHash), got \(actualHash)",
                        severity: .critical
                    )
                    issues.append(issue)
                }
                
                // Check 2: Validate sync metadata consistency
                if record.lastSynced != nil && record.lastSynced! > record.lastModified {
                    let issue = IntegrityIssue(
                        type: .timestampInconsistency,
                        recordID: record.syncID,
                        description: "Last synced timestamp is newer than last modified timestamp",
                        severity: .medium
                    )
                    issues.append(issue)
                }
                
                // Check 3: Validate version consistency
                if record.version < 1 {
                    let issue = IntegrityIssue(
                        type: .versionMismatch,
                        recordID: record.syncID,
                        description: "Invalid version number: \(record.version)",
                        severity: .critical
                    )
                    issues.append(issue)
                }
                
                // Check 4: Validate sync ID
                if record.syncID.uuidString.isEmpty {
                    let issue = IntegrityIssue(
                        type: .duplicateRecord,
                        recordID: record.syncID,
                        description: "Invalid or empty sync ID",
                        severity: .critical
                    )
                    issues.append(issue)
                }
            }
            
            // Check 5: Validate sync metadata consistency with metadataManager
            let _ = await metadataManager.getSyncStatus(for: entityTypeName)
            let lastSyncTimestamp = await metadataManager.getLastSyncTimestamp(for: entityTypeName)
            
            if let lastSync = lastSyncTimestamp {
                let recordsSyncedAfterLastSync = allLocalRecords.filter { record in
                    record.lastSynced != nil && record.lastSynced! > lastSync
                }
                
                if !recordsSyncedAfterLastSync.isEmpty {
                    let issue = IntegrityIssue(
                        type: .orphanedRecord,
                        recordID: nil,
                        description: "\(recordsSyncedAfterLastSync.count) records have sync timestamps newer than the last recorded sync",
                        severity: .medium
                    )
                    issues.append(issue)
                }
            }
            
            let isValid = issues.filter { $0.severity == .critical }.isEmpty
            
            let result = SyncIntegrityResult(
                entityType: entityTypeName,
                isValid: isValid,
                issues: issues,
                recordsChecked: recordsChecked
            )
            
            logger?.info("SyncIntegrityValidationService: Integrity validation completed - valid: \(isValid), issues: \(issues.count)")
            return result
            
        } catch {
            logger?.error("SyncIntegrityValidationService: Integrity validation failed - \(error.localizedDescription)")
            throw SyncRepositoryError.fetchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    /// Generate content hash for entity (uses entity's own implementation)
    /// - Parameter entity: Entity to generate hash for
    /// - Returns: Content hash string
    private func generateContentHash<T: Syncable>(for entity: T) -> String {
        return entity.contentHash
    }
}