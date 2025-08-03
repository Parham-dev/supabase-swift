//
//  SQLGenerationUsageExample.swift
//  SwiftSupabaseSync Usage Example
//
//  This file demonstrates how to use the SQL generation feature
//

import Foundation

/// This example shows how to use the new SQLScriptGenerator
/// to generate Supabase-compatible SQL scripts for your models

class SQLGenerationUsageExample {
    
    /// Example of how to use the SchemaAPI for SQL generation
    func generateSQLExample() {
        
        // 1. Make sure your models conform to SQLGeneratable protocol
        // 
        // Example model:
        // @Model
        // class TodoModel: SQLGeneratable {
        //     static var tableName: String { "todos" }
        //     // ... your properties
        // }
        
        // 2. Initialize the SchemaAPI (no authentication required)
        let schemaAPI = SchemaAPI()
        
        // 3. Generate SQL for a single model
        // let todoSQL = schemaAPI.generateMigrationSQL(for: TodoModel.self)
        // print("SQL for TodoModel:")
        // print(todoSQL)
        
        // 4. Generate combined SQL for multiple models
        // let models: [any SQLGeneratable.Type] = [TodoModel.self, NoteModel.self]
        // let combinedSQL = schemaAPI.generateCombinedMigrationSQL(for: models)
        // print("Combined SQL:")
        // print(combinedSQL)
        
        // 5. Use the generated SQL:
        //    - Copy the output
        //    - Open Supabase Dashboard > SQL Editor
        //    - Paste and execute the SQL
        //    - Your sync-enabled tables are ready!
    }
    
    /// Example of direct SQLScriptGenerator usage
    func directGeneratorExample() {
        
        // If you want more control, use SQLScriptGenerator directly
        let generator = SQLScriptGenerator(
            configuration: SQLScriptGenerator.Configuration(
                enableRLS: true,              // Row Level Security
                enableSyncTriggers: true,     // Auto-update timestamps
                enableSyncIndexes: true,      // Performance indexes
                addTimestamps: true           // created_at, updated_at
            )
        )
        
        // Generate for specific models
        // let script = generator.generateScript(for: TodoModel.self)
        // print("Table: \\(script.tableName)")
        // print("SQL:\\n\\(script.sql)")
        // print("Summary: \\(script.summary)")
    }
}

/// Sample output from the SQL generator:
/// 
/// ```sql
/// -- SwiftSupabaseSync Migration Script
/// -- Generated: 2025-01-08 12:00:00 +0000
/// -- Models: 1
/// --
/// -- Instructions:
/// -- 1. Review this SQL script carefully
/// -- 2. Copy and paste into Supabase SQL Editor
/// -- 3. Execute to create your sync-enabled tables
/// --
/// 
/// -- ==========================================
/// -- Table 1: todos
/// -- ==========================================
/// 
/// CREATE TABLE IF NOT EXISTS todos (
///   id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
///   sync_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
///   last_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
///   last_synced TIMESTAMP WITH TIME ZONE,
///   is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
///   version INTEGER NOT NULL DEFAULT 1,
///   created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
///   updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
///   -- Add your model-specific columns below
///   -- Example:
///   -- title TEXT NOT NULL
///   -- is_completed BOOLEAN NOT NULL DEFAULT FALSE
/// );
/// 
/// -- Indexes for sync performance
/// CREATE INDEX IF NOT EXISTS idx_todos_sync_id ON todos (sync_id);
/// CREATE INDEX IF NOT EXISTS idx_todos_last_modified ON todos (last_modified);
/// CREATE INDEX IF NOT EXISTS idx_todos_sync_status ON todos (last_modified, is_deleted);
/// CREATE INDEX IF NOT EXISTS idx_todos_version ON todos (version);
/// 
/// -- Enable Row Level Security
/// ALTER TABLE todos ENABLE ROW LEVEL SECURITY;
/// 
/// -- Policy: Users can see their own records
/// CREATE POLICY "Users can view own todos" ON todos
///   FOR SELECT USING (auth.uid()::text = user_id);
/// 
/// -- Policy: Users can insert their own records
/// CREATE POLICY "Users can insert own todos" ON todos
///   FOR INSERT WITH CHECK (auth.uid()::text = user_id);
/// 
/// -- Policy: Users can update their own records
/// CREATE POLICY "Users can update own todos" ON todos
///   FOR UPDATE USING (auth.uid()::text = user_id);
/// 
/// -- Policy: Users can delete their own records
/// CREATE POLICY "Users can delete own todos" ON todos
///   FOR DELETE USING (auth.uid()::text = user_id);
/// 
/// -- Sync triggers
/// -- Function to update updated_at timestamp
/// CREATE OR REPLACE FUNCTION update_todos_updated_at()
/// RETURNS TRIGGER AS $$
/// BEGIN
///   NEW.updated_at = NOW();
///   NEW.last_modified = NOW();
///   NEW.version = OLD.version + 1;
///   RETURN NEW;
/// END;
/// $$ LANGUAGE plpgsql;
/// 
/// -- Trigger to automatically update timestamps
/// CREATE OR REPLACE TRIGGER todos_update_timestamps
///   BEFORE UPDATE ON todos
///   FOR EACH ROW
///   EXECUTE FUNCTION update_todos_updated_at();
/// ```
