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
        
        // Try to find .env file in project root
        let possiblePaths = [
            ".env",
            "../.env",
            "../../.env",
            "../../../.env"
        ]
        
        for path in possiblePaths {
            if let envPath = findEnvFile(relativePath: path) {
                envVars = parseEnvFile(at: envPath)
                if !envVars.isEmpty {
                    print("📄 Loaded environment variables from: \(envPath)")
                    break
                }
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
