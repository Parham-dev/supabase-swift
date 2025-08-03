//
//  SQLScriptGenerator.swift
//  SwiftSupabaseSync
//
//  Created by GitHub Copilot on 03/08/2025.
//

import Foundation

// Define a simplified protocol for this generator
public protocol SQLGeneratable {
    static var tableName: String { get }
}

/// Simple SQL script generator for Supabase migration
/// Generates SQL scripts that users can manually execute in Supabase SQL Editor
public struct SQLScriptGenerator {
    
    // MARK: - Public Types
    
    /// Generated SQL script for a table
    public struct SQLScript {
        /// The table name
        public let tableName: String
        
        /// Complete SQL script
        public let sql: String
        
        /// Human-readable summary
        public let summary: String
        
        /// Generated timestamp
        public let generatedAt: Date
        
        public init(tableName: String, sql: String, summary: String, generatedAt: Date = Date()) {
            self.tableName = tableName
            self.sql = sql
            self.summary = summary
            self.generatedAt = generatedAt
        }
    }
    
    // MARK: - Configuration
    
    /// Configuration for SQL generation
    public struct Configuration {
        /// Enable Row Level Security
        public let enableRLS: Bool
        
        /// Enable sync-related triggers
        public let enableSyncTriggers: Bool
        
        /// Enable optimized indexes
        public let enableSyncIndexes: Bool
        
        /// Add standard timestamp columns
        public let addTimestamps: Bool
        
        public init(
            enableRLS: Bool = true,
            enableSyncTriggers: Bool = true,
            enableSyncIndexes: Bool = true,
            addTimestamps: Bool = true
        ) {
            self.enableRLS = enableRLS
            self.enableSyncTriggers = enableSyncTriggers
            self.enableSyncIndexes = enableSyncIndexes
            self.addTimestamps = addTimestamps
        }
        
        public static let `default` = Configuration()
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Generate SQL script for a model using its table name and basic structure
    /// - Parameter modelType: The model type conforming to SQLGeneratable
    /// - Returns: SQL script
    public func generateScript<T: SQLGeneratable>(for modelType: T.Type) -> SQLScript {
        let tableName = T.tableName
        let sql = generateTableSQL(for: tableName)
        let summary = "SQL script for table '\(tableName)' with sync capabilities"
        
        return SQLScript(
            tableName: tableName,
            sql: sql,
            summary: summary
        )
    }
    
    /// Generate SQL scripts for multiple models
    /// - Parameter modelTypes: Array of SQLGeneratable model types
    /// - Returns: Array of SQL scripts
    public func generateScripts(for modelTypes: [any SQLGeneratable.Type]) -> [SQLScript] {
        return modelTypes.map { modelType in
            generateScriptForAnyType(modelType)
        }
    }
    
    /// Generate combined SQL for multiple models
    /// - Parameter modelTypes: Array of SQLGeneratable model types
    /// - Returns: Combined SQL string
    public func generateCombinedSQL(for modelTypes: [any SQLGeneratable.Type]) -> String {
        let scripts = generateScripts(for: modelTypes)
        
        var combinedSQL: [String] = []
        
        // Header
        combinedSQL.append("-- SwiftSupabaseSync Migration Script")
        combinedSQL.append("-- Generated: \\(Date())")
        combinedSQL.append("-- Models: \\(modelTypes.count)")
        combinedSQL.append("--")
        combinedSQL.append("-- Instructions:")
        combinedSQL.append("-- 1. Review this SQL script carefully")
        combinedSQL.append("-- 2. Copy and paste into Supabase SQL Editor")
        combinedSQL.append("-- 3. Execute to create your sync-enabled tables")
        combinedSQL.append("--")
        combinedSQL.append("")
        
        // Individual table scripts
        for (index, script) in scripts.enumerated() {
            combinedSQL.append("-- ==========================================")
            combinedSQL.append("-- Table \\(index + 1): \\(script.tableName)")
            combinedSQL.append("-- ==========================================")
            combinedSQL.append("")
            combinedSQL.append(script.sql)
            
            if index < scripts.count - 1 {
                combinedSQL.append("")
                combinedSQL.append("")
            }
        }
        
        return combinedSQL.joined(separator: "\\n")
    }
}

// MARK: - Private Implementation

private extension SQLScriptGenerator {
    
    /// Generate SQL for any SQLGeneratable type (type erasure workaround)
    func generateScriptForAnyType(_ modelType: any SQLGeneratable.Type) -> SQLScript {
        let tableName = modelType.tableName
        let sql = generateTableSQL(for: tableName)
        let summary = "SQL script for table '\(tableName)' with sync capabilities"
        
        return SQLScript(
            tableName: tableName,
            sql: sql,
            summary: summary
        )
    }
    
    /// Generate complete SQL for a table
    func generateTableSQL(for tableName: String) -> String {
        var sqlParts: [String] = []
        
        // 1. Create table
        sqlParts.append(generateCreateTableSQL(for: tableName))
        
        // 2. Add indexes
        if configuration.enableSyncIndexes {
            sqlParts.append("")
            sqlParts.append("-- Indexes for sync performance")
            sqlParts.append(contentsOf: generateSyncIndexes(for: tableName))
        }
        
        // 3. Enable RLS
        if configuration.enableRLS {
            sqlParts.append("")
            sqlParts.append("-- Enable Row Level Security")
            sqlParts.append(contentsOf: generateRLSPolicies(for: tableName))
        }
        
        // 4. Add triggers
        if configuration.enableSyncTriggers {
            sqlParts.append("")
            sqlParts.append("-- Sync triggers")
            sqlParts.append(contentsOf: generateSyncTriggers(for: tableName))
        }
        
        return sqlParts.joined(separator: "\\n")
    }
    
    /// Generate CREATE TABLE SQL with all required sync columns
    func generateCreateTableSQL(for tableName: String) -> String {
        var sql = "CREATE TABLE IF NOT EXISTS \\(tableName) ("
        
        var columns: [String] = []
        
        // Primary key - using UUID as recommended for distributed systems
        columns.append("  id UUID PRIMARY KEY DEFAULT gen_random_uuid()")
        
        // Standard Syncable columns (these are required by the protocol)
        columns.append("  sync_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid()")
        columns.append("  last_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()")
        columns.append("  last_synced TIMESTAMP WITH TIME ZONE")
        columns.append("  is_deleted BOOLEAN NOT NULL DEFAULT FALSE")
        columns.append("  version INTEGER NOT NULL DEFAULT 1")
        
        // Standard timestamp columns
        if configuration.addTimestamps {
            columns.append("  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()")
            columns.append("  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()")
        }
        
        // TODO: Add your model-specific columns here
        // This is where you would add columns based on your SwiftData model properties
        // For now, we add a placeholder
        columns.append("  -- Add your model-specific columns below")
        columns.append("  -- Example:")
        columns.append("  -- title TEXT NOT NULL")
        columns.append("  -- is_completed BOOLEAN NOT NULL DEFAULT FALSE")
        
        sql += "\n\(columns.joined(separator: ",\n"))\n"
        sql += ");"
        
        return sql
    }
    
    /// Generate sync-optimized indexes
    func generateSyncIndexes(for tableName: String) -> [String] {
        return [
            "CREATE INDEX IF NOT EXISTS idx_\\(tableName)_sync_id ON \\(tableName) (sync_id);",
            "CREATE INDEX IF NOT EXISTS idx_\\(tableName)_last_modified ON \\(tableName) (last_modified);",
            "CREATE INDEX IF NOT EXISTS idx_\\(tableName)_sync_status ON \\(tableName) (last_modified, is_deleted);",
            "CREATE INDEX IF NOT EXISTS idx_\\(tableName)_version ON \\(tableName) (version);"
        ]
    }
    
    /// Generate RLS policies for user isolation
    func generateRLSPolicies(for tableName: String) -> [String] {
        var policies: [String] = []
        
        // Enable RLS
        policies.append("ALTER TABLE \\(tableName) ENABLE ROW LEVEL SECURITY;")
        policies.append("")
        
        // Basic policies (you may want to customize these based on your auth system)
        policies.append("-- Policy: Users can see their own records")
        policies.append("CREATE POLICY \\\"Users can view own \\(tableName)\\\" ON \\(tableName)")
        policies.append("  FOR SELECT USING (auth.uid()::text = user_id);")
        policies.append("")
        
        policies.append("-- Policy: Users can insert their own records")
        policies.append("CREATE POLICY \\\"Users can insert own \\(tableName)\\\" ON \\(tableName)")
        policies.append("  FOR INSERT WITH CHECK (auth.uid()::text = user_id);")
        policies.append("")
        
        policies.append("-- Policy: Users can update their own records")
        policies.append("CREATE POLICY \\\"Users can update own \\(tableName)\\\" ON \\(tableName)")
        policies.append("  FOR UPDATE USING (auth.uid()::text = user_id);")
        policies.append("")
        
        policies.append("-- Policy: Users can delete their own records")
        policies.append("CREATE POLICY \\\"Users can delete own \\(tableName)\\\" ON \\(tableName)")
        policies.append("  FOR DELETE USING (auth.uid()::text = user_id);")
        
        return policies
    }
    
    /// Generate triggers for automatic timestamp updates
    func generateSyncTriggers(for tableName: String) -> [String] {
        var triggers: [String] = []
        
        // Function to update timestamps
        triggers.append("-- Function to update updated_at timestamp")
        triggers.append("CREATE OR REPLACE FUNCTION update_\\(tableName)_updated_at()")
        triggers.append("RETURNS TRIGGER AS $$")
        triggers.append("BEGIN")
        triggers.append("  NEW.updated_at = NOW();")
        triggers.append("  NEW.last_modified = NOW();")
        triggers.append("  NEW.version = OLD.version + 1;")
        triggers.append("  RETURN NEW;")
        triggers.append("END;")
        triggers.append("$$ LANGUAGE plpgsql;")
        triggers.append("")
        
        // Trigger for updates
        triggers.append("-- Trigger to automatically update timestamps")
        triggers.append("CREATE OR REPLACE TRIGGER \\(tableName)_update_timestamps")
        triggers.append("  BEFORE UPDATE ON \\(tableName)")
        triggers.append("  FOR EACH ROW")
        triggers.append("  EXECUTE FUNCTION update_\\(tableName)_updated_at();")
        
        return triggers
    }
}

// MARK: - Extensions for existing types

extension SQLScriptGenerator.SQLScript: CustomStringConvertible {
    public var description: String {
        return """
        SQLScript for \\(tableName):
        Summary: \\(summary)
        Generated: \\(generatedAt)
        
        \\(sql)
        """
    }
}
