//
//  SupabaseDataDataSource.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

/// Remote data source for Supabase database operations
/// Handles CRUD operations, bulk sync, and schema management
public final class SupabaseDataDataSource {
    
    // MARK: - Properties
    
    private let httpClient: SupabaseClient
    private let baseURL: URL
    
    // MARK: - Initialization
    
    /// Initialize data source with HTTP client
    /// - Parameters:
    ///   - httpClient: HTTP client for database requests
    ///   - baseURL: Supabase project URL
    public init(httpClient: SupabaseClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }
    
    // MARK: - CRUD Operations
    
    /// Insert a new record
    /// - Parameters:
    ///   - snapshot: Sync snapshot to insert
    ///   - tableName: Database table name
    /// - Returns: Inserted record data
    /// - Throws: DataSourceError
    public func insert(_ snapshot: SyncSnapshot, into tableName: String) async throws -> [String: Any] {
        do {
            let recordData = try convertSnapshotToRecord(snapshot)
            
            let request = RequestBuilder.post("/rest/v1/\(tableName)", baseURL: baseURL)
                .rawBody(try JSONSerialization.data(withJSONObject: recordData))
                .header("Prefer", "return=representation")
            
            let responseData = try await httpClient.executeRaw(request)
            let response = try JSONSerialization.jsonObject(with: responseData) as? [[String: Any]] ?? []
            
            guard let insertedRecord = response.first else {
                throw DataSourceError.insertFailed("No record returned after insert")
            }
            
            return insertedRecord
            
        } catch {
            throw DataSourceError.insertFailed("Insert failed: \(error.localizedDescription)")
        }
    }
    
    /// Update an existing record
    /// - Parameters:
    ///   - snapshot: Sync snapshot with updated data
    ///   - tableName: Database table name
    /// - Returns: Updated record data
    /// - Throws: DataSourceError
    public func update(_ snapshot: SyncSnapshot, in tableName: String) async throws -> [String: Any] {
        do {
            let recordData = try convertSnapshotToRecord(snapshot)
            
            let request = RequestBuilder.patch("/rest/v1/\(tableName)", baseURL: baseURL)
                .rawBody(try JSONSerialization.data(withJSONObject: recordData))
                .query("sync_id", "eq.\(snapshot.syncID.uuidString)")
                .header("Prefer", "return=representation")
            
            let responseData = try await httpClient.executeRaw(request)
            let response = try JSONSerialization.jsonObject(with: responseData) as? [[String: Any]] ?? []
            
            guard let updatedRecord = response.first else {
                throw DataSourceError.updateFailed("Record not found for update")
            }
            
            return updatedRecord
            
        } catch {
            throw DataSourceError.updateFailed("Update failed: \(error.localizedDescription)")
        }
    }
    
    /// Delete a record (soft delete)
    /// - Parameters:
    ///   - syncID: Unique sync identifier
    ///   - tableName: Database table name
    /// - Throws: DataSourceError
    public func delete(syncID: UUID, from tableName: String) async throws {
        do {
            let deleteData: [String: Any] = [
                "is_deleted": true,
                "last_modified": ISO8601DateFormatter().string(from: Date()),
                "version": "version + 1" // This would be handled by the database
            ]
            
            let request = RequestBuilder.patch("/rest/v1/\(tableName)", baseURL: baseURL)
                .rawBody(try JSONSerialization.data(withJSONObject: deleteData))
                .query("sync_id", "eq.\(syncID.uuidString)")
            
            try await httpClient.execute(request)
            
        } catch {
            throw DataSourceError.deleteFailed("Delete failed: \(error.localizedDescription)")
        }
    }
    
    /// Fetch a single record by sync ID
    /// - Parameters:
    ///   - syncID: Unique sync identifier
    ///   - tableName: Database table name
    /// - Returns: Sync snapshot if found
    /// - Throws: DataSourceError
    public func fetch(syncID: UUID, from tableName: String) async throws -> SyncSnapshot? {
        do {
            let request = RequestBuilder.get("/rest/v1/\(tableName)", baseURL: baseURL)
                .query("sync_id", "eq.\(syncID.uuidString)")
                .query("limit", "1")
            
            let responseData = try await httpClient.executeRaw(request)
            let response = try JSONSerialization.jsonObject(with: responseData) as? [[String: Any]] ?? []
            
            guard let record = response.first else {
                return nil
            }
            
            return try convertRecordToSnapshot(record, tableName: tableName)
            
        } catch {
            throw DataSourceError.fetchFailed("Fetch failed: \(error.localizedDescription)")
        }
    }
    
    /// Fetch records modified after a specific date
    /// - Parameters:
    ///   - date: Date threshold
    ///   - tableName: Database table name
    ///   - limit: Maximum number of records
    /// - Returns: Array of sync snapshots
    /// - Throws: DataSourceError
    public func fetchRecordsModifiedAfter(
        _ date: Date,
        from tableName: String,
        limit: Int? = nil
    ) async throws -> [SyncSnapshot] {
        do {
            var request = RequestBuilder.get("/rest/v1/\(tableName)", baseURL: baseURL)
                .query("last_modified", "gt.\(ISO8601DateFormatter().string(from: date))")
                .query("order", "last_modified.desc")
            
            if let limit = limit {
                request = request.query("limit", String(limit))
            }
            
            let responseData = try await httpClient.executeRaw(request)
            let response = try JSONSerialization.jsonObject(with: responseData) as? [[String: Any]] ?? []
            
            return try response.compactMap { record in
                try convertRecordToSnapshot(record, tableName: tableName)
            }
            
        } catch {
            throw DataSourceError.fetchFailed("Fetch records modified after failed: \(error.localizedDescription)")
        }
    }
    
    /// Fetch deleted records (tombstones)
    /// - Parameters:
    ///   - tableName: Database table name
    ///   - since: Optional date to filter from
    ///   - limit: Maximum number of records
    /// - Returns: Array of deleted record snapshots
    /// - Throws: DataSourceError
    public func fetchDeletedRecords(
        from tableName: String,
        since: Date? = nil,
        limit: Int? = nil
    ) async throws -> [SyncSnapshot] {
        do {
            var request = RequestBuilder.get("/rest/v1/\(tableName)", baseURL: baseURL)
                .query("is_deleted", "eq.true")
                .query("order", "last_modified.desc")
            
            if let since = since {
                request = request.query("last_modified", "gt.\(ISO8601DateFormatter().string(from: since))")
            }
            
            if let limit = limit {
                request = request.query("limit", String(limit))
            }
            
            let responseData = try await httpClient.executeRaw(request)
            let response = try JSONSerialization.jsonObject(with: responseData) as? [[String: Any]] ?? []
            
            return try response.compactMap { record in
                try convertRecordToSnapshot(record, tableName: tableName)
            }
            
        } catch {
            throw DataSourceError.fetchFailed("Fetch deleted records failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Batch Operations
    
    /// Batch insert multiple records
    /// - Parameters:
    ///   - snapshots: Array of sync snapshots to insert
    ///   - tableName: Database table name
    /// - Returns: Array of inserted record results
    /// - Throws: DataSourceError
    public func batchInsert(_ snapshots: [SyncSnapshot], into tableName: String) async throws -> [BatchOperationResult] {
        do {
            let recordsData = try snapshots.map { try convertSnapshotToRecord($0) }
            
            let request = RequestBuilder.post("/rest/v1/\(tableName)", baseURL: baseURL)
                .rawBody(try JSONSerialization.data(withJSONObject: recordsData))
                .header("Prefer", "return=representation")
            
            let responseData = try await httpClient.executeRaw(request)
            let response = try JSONSerialization.jsonObject(with: responseData) as? [[String: Any]] ?? []
            
            // Map results back to snapshots
            return snapshots.enumerated().map { index, snapshot in
                let success = index < response.count
                return BatchOperationResult(
                    syncID: snapshot.syncID,
                    success: success,
                    error: success ? nil : DataSourceError.insertFailed("Batch insert failed for record")
                )
            }
            
        } catch {
            let dataError = DataSourceError.batchOperationFailed("Batch insert failed: \(error.localizedDescription)")
            return snapshots.map { snapshot in
                BatchOperationResult(syncID: snapshot.syncID, success: false, error: dataError)
            }
        }
    }
    
    /// Upsert (insert or update) records
    /// - Parameters:
    ///   - snapshots: Array of sync snapshots to upsert
    ///   - tableName: Database table name
    /// - Returns: Array of upsert results
    /// - Throws: DataSourceError
    public func batchUpsert(_ snapshots: [SyncSnapshot], into tableName: String) async throws -> [BatchOperationResult] {
        print("🔄 [SupabaseDataDataSource] Starting batch upsert for \(snapshots.count) snapshots into table '\(tableName)'")
        
        do {
            let recordsData = try snapshots.map { try convertSnapshotToRecord($0) }
            print("🔄 [SupabaseDataDataSource] Converted snapshots to records:")
            for (index, record) in recordsData.enumerated() {
                print("   Record \(index): \(record)")
            }
            
            let request = RequestBuilder.post("/rest/v1/\(tableName)", baseURL: baseURL)
                .rawBody(try JSONSerialization.data(withJSONObject: recordsData))
                .header("Prefer", "return=representation,resolution=merge-duplicates")
            
            print("🔄 [SupabaseDataDataSource] Making request to: \(baseURL)/rest/v1/\(tableName)")
            print("🔄 [SupabaseDataDataSource] Request headers: \(request.headers)")
            
            let responseData = try await httpClient.executeRaw(request)
            print("✅ [SupabaseDataDataSource] Got response, size: \(responseData.count) bytes")
            
            let response = try JSONSerialization.jsonObject(with: responseData) as? [[String: Any]] ?? []
            print("✅ [SupabaseDataDataSource] Parsed response: \(response.count) records returned")
            
            return snapshots.enumerated().map { index, snapshot in
                let success = index < response.count
                print("🔄 [SupabaseDataDataSource] Snapshot \(index) (\(snapshot.syncID)): success=\(success)")
                return BatchOperationResult(
                    syncID: snapshot.syncID,
                    success: success,
                    error: success ? nil : DataSourceError.upsertFailed("Upsert failed for record")
                )
            }
            
        } catch {
            print("❌ [SupabaseDataDataSource] Batch upsert failed: \(error)")
            print("❌ [SupabaseDataDataSource] Error type: \(type(of: error))")
            if let networkError = error as? NetworkError {
                print("❌ [SupabaseDataDataSource] Network error details: \(networkError)")
            }
            
            let dataError = DataSourceError.batchOperationFailed("Batch upsert failed: \(error.localizedDescription)")
            return snapshots.map { snapshot in
                BatchOperationResult(syncID: snapshot.syncID, success: false, error: dataError)
            }
        }
    }
    
    /// Check if table exists
    /// - Parameter tableName: Database table name
    /// - Returns: Whether table exists
    /// - Throws: DataSourceError
    public func tableExists(_ tableName: String) async throws -> Bool {
        do {
            let request = RequestBuilder.get("/rest/v1/\(tableName)", baseURL: baseURL)
                .query("limit", "0")
            
            try await httpClient.execute(request)
            return true
            
        } catch let error as NetworkError {
            if case .httpError(let statusCode, _) = error, statusCode == 404 {
                return false
            }
            throw DataSourceError.schemaError("Failed to check table existence: \(error.localizedDescription)")
        } catch {
            throw DataSourceError.schemaError("Failed to check table existence: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    private func convertSnapshotToRecord(_ snapshot: SyncSnapshot) throws -> [String: Any] {
        var record: [String: Any] = [
            "sync_id": snapshot.syncID.uuidString,
            "version": snapshot.version,
            "last_modified": ISO8601DateFormatter().string(from: snapshot.lastModified),
            "is_deleted": snapshot.isDeleted,
            "content_hash": snapshot.contentHash
        ]
        
        if let lastSynced = snapshot.lastSynced {
            record["last_synced"] = ISO8601DateFormatter().string(from: lastSynced)
        }
        
        // Add conflict data (optional - only if table has this column)
        // Since we're extracting specific properties, conflict_data is not always needed
        if !snapshot.conflictData.isEmpty {
            let conflictDataJSON = try JSONSerialization.data(withJSONObject: snapshot.conflictData)
            // Only add conflict_data if it's meaningful (for advanced sync scenarios)
            // For basic entity sync, the specific properties are sufficient
            if snapshot.conflictData.keys.contains(where: { !["id", "title", "isCompleted", "createdAt", "updatedAt"].contains($0) }) {
                record["conflict_data"] = String(data: conflictDataJSON, encoding: .utf8)
            }
        }
        
        // Add table-specific data based on table name
        try addTableSpecificData(to: &record, from: snapshot)
        
        return record
    }
    
    /// Add table-specific data from SyncSnapshot to database record
    private func addTableSpecificData(to record: inout [String: Any], from snapshot: SyncSnapshot) throws {
        switch snapshot.tableName {
        case "todos":
            try addTodoSpecificData(to: &record, from: snapshot)
        default:
            // For unknown table types, look for generic data in conflictData
            // In production, this would use a type registry
            break
        }
    }
    
    /// Add TestTodo-specific data to database record
    private func addTodoSpecificData(to record: inout [String: Any], from snapshot: SyncSnapshot) throws {
        // Extract TestTodo properties from the snapshot's conflictData
        // The conflictData serves as a generic property bag for entity data
        
        if let todoId = snapshot.conflictData["id"] as? String {
            record["id"] = todoId
        }
        
        if let title = snapshot.conflictData["title"] as? String {
            record["title"] = title
        }
        
        if let isCompleted = snapshot.conflictData["isCompleted"] as? Bool {
            record["is_completed"] = isCompleted
        }
        
        if let createdAtString = snapshot.conflictData["createdAt"] as? String,
           let createdAt = ISO8601DateFormatter().date(from: createdAtString) {
            record["created_at"] = ISO8601DateFormatter().string(from: createdAt)
        }
        
        if let updatedAtString = snapshot.conflictData["updatedAt"] as? String,
           let updatedAt = ISO8601DateFormatter().date(from: updatedAtString) {
            record["updated_at"] = ISO8601DateFormatter().string(from: updatedAt)
        }
        
        // Note: user_id is automatically handled by Supabase auth.uid() default
    }
    
    private func convertRecordToSnapshot(_ record: [String: Any], tableName: String) throws -> SyncSnapshot {
        guard let syncIDString = record["sync_id"] as? String,
              let syncID = UUID(uuidString: syncIDString),
              let version = record["version"] as? Int,
              let lastModifiedString = record["last_modified"] as? String,
              let lastModified = ISO8601DateFormatter().date(from: lastModifiedString),
              let isDeleted = record["is_deleted"] as? Bool,
              let contentHash = record["content_hash"] as? String else {
            throw DataSourceError.invalidData("Invalid record format")
        }
        
        let lastSynced: Date?
        if let lastSyncedString = record["last_synced"] as? String {
            lastSynced = ISO8601DateFormatter().date(from: lastSyncedString)
        } else {
            lastSynced = nil
        }
        
        var conflictData: [String: Any] = [:]
        if let conflictDataString = record["conflict_data"] as? String,
           let conflictDataJSON = conflictDataString.data(using: .utf8) {
            conflictData = (try? JSONSerialization.jsonObject(with: conflictDataJSON) as? [String: Any]) ?? [:]
        }
        
        // Extract table-specific data and add to conflictData
        try extractTableSpecificData(from: record, tableName: tableName, into: &conflictData)
        
        return SyncSnapshot(
            syncID: syncID,
            tableName: tableName,
            version: version,
            lastModified: lastModified,
            lastSynced: lastSynced,
            isDeleted: isDeleted,
            contentHash: contentHash,
            conflictData: conflictData
        )
    }
    
    /// Extract table-specific data from database record to conflictData
    private func extractTableSpecificData(from record: [String: Any], tableName: String, into conflictData: inout [String: Any]) throws {
        switch tableName {
        case "todos":
            try extractTodoSpecificData(from: record, into: &conflictData)
        default:
            // For unknown table types, skip extraction
            // In production, this would use a type registry
            break
        }
    }
    
    /// Extract TestTodo-specific data from database record
    private func extractTodoSpecificData(from record: [String: Any], into conflictData: inout [String: Any]) throws {
        // Extract TestTodo properties from database record
        
        if let todoId = record["id"] as? String {
            conflictData["id"] = todoId
        }
        
        if let title = record["title"] as? String {
            conflictData["title"] = title
        }
        
        if let isCompleted = record["is_completed"] as? Bool {
            conflictData["isCompleted"] = isCompleted
        }
        
        if let createdAtString = record["created_at"] as? String {
            conflictData["createdAt"] = createdAtString
        }
        
        if let updatedAtString = record["updated_at"] as? String {
            conflictData["updatedAt"] = updatedAtString
        }
        
        if let userId = record["user_id"] as? String {
            conflictData["userId"] = userId
        }
    }
}

// MARK: - Supporting Types

public enum DataSourceError: Error, LocalizedError, Equatable {
    case insertFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case fetchFailed(String)
    case upsertFailed(String)
    case batchOperationFailed(String)
    case schemaError(String)
    case invalidData(String)
    case networkError(String)
    case unauthorized
    case rateLimitExceeded
    case serverError(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .insertFailed(let message):
            return "Insert failed: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .upsertFailed(let message):
            return "Upsert failed: \(message)"
        case .batchOperationFailed(let message):
            return "Batch operation failed: \(message)"
        case .schemaError(let message):
            return "Schema error: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unauthorized:
            return "Unauthorized access"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}