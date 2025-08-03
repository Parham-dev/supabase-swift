# SQL Migration Generation

## Overview

The **SQLScriptGenerator** provides a simple, effective solution for generating Supabase-compatible SQL scripts from your SwiftData models **without requiring admin credentials**.

## Key Features

✅ **No Authentication Required** - Generate SQL scripts without Supabase admin access  
✅ **SwiftData Integration** - Works with your existing SwiftData models  
✅ **Sync-Ready Tables** - Generates tables with all required sync capabilities  
✅ **Security Built-in** - Includes Row Level Security (RLS) policies  
✅ **Performance Optimized** - Adds sync-specific indexes  
✅ **Manual Control** - You review and execute SQL in Supabase Dashboard  

## Problems with Previous Approach

The original `SQLMigrationGenerator` had several issues:

1. **Over-complex reflection** - Tried to analyze SwiftData models using complex Mirror API
2. **SwiftData initialization issues** - Models require `backingData` parameter
3. **Missing types** - Referenced undefined `SQLMigrationScript` type
4. **Architectural complexity** - Too many abstractions for a simple SQL generation task

## New Simplified Approach

### 1. Make Your Models Compatible

```swift
import SwiftData
import SwiftSupabaseSync

@Model
class TodoModel: SQLGeneratable {
    // Required: Specify table name
    static var tableName: String { "todos" }
    
    // Your model properties
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var userID: String?  // For RLS policies
    
    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

### 2. Generate SQL Scripts

```swift
// Initialize the public API (no auth required)
let schemaAPI = SchemaAPI()

// Generate SQL for a single model
let todoSQL = schemaAPI.generateMigrationSQL(for: TodoModel.self)
print(todoSQL)

// Generate combined SQL for multiple models
let models: [any SQLGeneratable.Type] = [TodoModel.self, NoteModel.self]
let combinedSQL = schemaAPI.generateCombinedMigrationSQL(for: models)
print(combinedSQL)
```

### 3. Execute in Supabase

1. **Copy the generated SQL** from your console/logs
2. **Open Supabase Dashboard** → SQL Editor  
3. **Paste and execute** the SQL script
4. **Your sync-enabled tables are ready!**

## Generated SQL Features

### Core Sync Columns
Every table gets these essential sync columns:
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid()
sync_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid()
last_modified TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
last_synced TIMESTAMP WITH TIME ZONE
is_deleted BOOLEAN NOT NULL DEFAULT FALSE
version INTEGER NOT NULL DEFAULT 1
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
```

### Performance Indexes
```sql
CREATE INDEX idx_todos_sync_id ON todos (sync_id);
CREATE INDEX idx_todos_last_modified ON todos (last_modified);
CREATE INDEX idx_todos_sync_status ON todos (last_modified, is_deleted);
CREATE INDEX idx_todos_version ON todos (version);
```

### Row Level Security (RLS)
```sql
ALTER TABLE todos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own todos" ON todos
  FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can insert own todos" ON todos
  FOR INSERT WITH CHECK (auth.uid()::text = user_id);
```

### Auto-Update Triggers
```sql
CREATE OR REPLACE FUNCTION update_todos_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  NEW.last_modified = NOW();
  NEW.version = OLD.version + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER todos_update_timestamps
  BEFORE UPDATE ON todos
  FOR EACH ROW
  EXECUTE FUNCTION update_todos_updated_at();
```

## Configuration Options

```swift
let generator = SQLScriptGenerator(
    configuration: SQLScriptGenerator.Configuration(
        enableRLS: true,              // Row Level Security
        enableSyncTriggers: true,     // Auto-update timestamps  
        enableSyncIndexes: true,      // Performance indexes
        addTimestamps: true           // created_at, updated_at
    )
)
```

## Next Steps

1. **Add Your Columns**: The generated SQL includes placeholders for your model-specific columns
2. **Customize RLS Policies**: Modify the user isolation logic as needed
3. **Test Sync**: Use the existing sync APIs to test data synchronization
4. **Iterate**: Regenerate SQL as your models evolve

## Why This Works

✅ **Simple** - Just conform to `SQLGeneratable` protocol  
✅ **Safe** - You control when and how SQL is executed  
✅ **Flexible** - Customize table structure before execution  
✅ **Compatible** - Works with existing SwiftSupabaseSync infrastructure  
✅ **Reliable** - No complex reflection or model instantiation  

The key insight: **Generate SQL templates that you customize and execute manually** rather than trying to fully automate schema creation without admin access.
