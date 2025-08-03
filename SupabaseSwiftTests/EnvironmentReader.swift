//
//  EnvironmentReader.swift
//  SwiftSupabaseSyncTests
//
//  Created by Parham on 02/08/2025.
//

import Foundation

/// Utility to read environment variables from .env file for testing
struct EnvironmentReader {
    
    /// Read environment variables from .env file
    /// - Returns: Dictionary of environment variables
    static func loadEnvFile() -> [String: String] {
        var envVars: [String: String] = [:]
        
        // Try to find .env file in various locations
        // Xcode often runs tests from DerivedData, so we need to search more paths
        let possiblePaths = [
            ".env",                           // Current directory
            "../.env",                        // Parent directory
            "../../.env",                     // Grandparent directory
            "../../../.env",                  // Great-grandparent directory
            "../../../../.env",               // For deep Xcode paths
            "../../../../../.env",            // Even deeper
            "../../../../../../.env",         // Very deep Xcode paths
        ]
        
        // Also try absolute path to project root (more reliable for Xcode)
        let projectRootPaths = findProjectRootPaths()
        
        // Combine relative and absolute paths
        let allPaths = possiblePaths + projectRootPaths
        
        for path in allPaths {
            if let envPath = findEnvFile(relativePath: path) {
                envVars = parseEnvFile(at: envPath)
                if !envVars.isEmpty {
                    print("📄 Loaded environment variables from: \(envPath)")
                    break
                }
            }
        }
        
        if envVars.isEmpty {
            print("⚠️ No .env file found. Searched paths:")
            for path in allPaths {
                let fullPath = findEnvFile(relativePath: path) ?? "Not found: \(path)"
                print("   - \(fullPath)")
            }
        }
        
        return envVars
    }
    
    /// Find .env file starting from current working directory
    private static func findEnvFile(relativePath: String) -> String? {
        let currentDirectory = FileManager.default.currentDirectoryPath
        let envPath = (currentDirectory as NSString).appendingPathComponent(relativePath)
        
        if FileManager.default.fileExists(atPath: envPath) {
            return envPath
        }
        
        return nil
    }
    
    /// Find potential project root paths by looking for characteristic files
    private static func findProjectRootPaths() -> [String] {
        var projectPaths: [String] = []
        
        // Look for project indicators (Package.swift, .git, etc.)
        let projectIndicators = ["Package.swift", ".git", "README.md"]
        let currentDirectory = FileManager.default.currentDirectoryPath
        
        // Search up the directory tree
        var searchPath = currentDirectory
        for _ in 0..<10 { // Limit search depth
            for indicator in projectIndicators {
                let indicatorPath = (searchPath as NSString).appendingPathComponent(indicator)
                if FileManager.default.fileExists(atPath: indicatorPath) {
                    let envPath = (searchPath as NSString).appendingPathComponent(".env")
                    if !projectPaths.contains(envPath) {
                        projectPaths.append(envPath)
                    }
                    break
                }
            }
            
            // Move up one directory
            let parentPath = (searchPath as NSString).deletingLastPathComponent
            if parentPath == searchPath {
                break // Reached root
            }
            searchPath = parentPath
        }
        
        return projectPaths
    }
    
    /// Parse .env file and return key-value pairs
    private static func parseEnvFile(at path: String) -> [String: String] {
        var envVars: [String: String] = [:]
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip empty lines and comments
                if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                    continue
                }
                
                // Parse KEY=VALUE format
                if let equalIndex = trimmedLine.firstIndex(of: "=") {
                    let key = String(trimmedLine[..<equalIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(trimmedLine[trimmedLine.index(after: equalIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    envVars[key] = value
                }
            }
        } catch {
            print("❌ Failed to read .env file at \(path): \(error)")
        }
        
        return envVars
    }
    
    /// Get environment variable with fallback
    static func getEnvVar(_ key: String, fallback: String = "") -> String {
        // First try system environment
        if let systemValue = ProcessInfo.processInfo.environment[key] {
            return systemValue
        }
        
        // Then try .env file
        let envVars = loadEnvFile()
        return envVars[key] ?? fallback
    }
}
