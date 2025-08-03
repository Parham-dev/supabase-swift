//
//  TodoModel.swift
//  SwiftSupabaseSync Example
//
//  Example of how to make your SwiftData model work with SQL generation
//

import Foundation
import SwiftData
import SwiftSupabaseSync

/// Example Todo model that conforms to SQLGeneratable
/// This demonstrates how to prepare your models for SQL generation
@Model
public class TodoModel: SQLGeneratable {
    
    // MARK: - SQLGeneratable Conformance
    
    /// Required: Table name for database
    public static var tableName: String { "todos" }
    
    // MARK: - Model Properties
    
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var updatedAt: Date
    
    // Optional: User association (for RLS)
    public var userID: String?
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        userID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userID = userID
    }
}

/// Example Note model
@Model
public class NoteModel: SQLGeneratable {
    
    // MARK: - SQLGeneratable Conformance
    
    public static var tableName: String { "notes" }
    
    // MARK: - Model Properties
    
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var content: String
    public var tags: [String]  // Will be stored as JSON array
    public var isPrivate: Bool
    public var createdAt: Date
    public var updatedAt: Date
    
    // User association
    public var userID: String?
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        title: String,
        content: String,
        tags: [String] = [],
        isPrivate: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        userID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.isPrivate = isPrivate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userID = userID
    }
}
