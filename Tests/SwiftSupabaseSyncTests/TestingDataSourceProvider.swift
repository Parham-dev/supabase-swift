//
//  TestingDataSourceProvider.swift
//  SwiftSupabaseSyncTests
//
//  Created by Parham on 02/08/2025.
//

import Foundation
@testable import SwiftSupabaseSync

/// Global provider for test data sources
/// Allows tests to provide their own LocalDataSource implementation
public class TestingDataSourceProvider {
    public static let shared = TestingDataSourceProvider()
    
    /// LocalDataSource for testing
    public var localDataSource: LocalDataSource?
    
    private init() {}
    
    /// Clear all test data sources
    public func clear() {
        localDataSource = nil
    }
}
