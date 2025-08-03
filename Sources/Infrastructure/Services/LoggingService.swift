//
//  LoggingService.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation
import os.log

/// Implementation of SyncLoggerProtocol that provides configurable logging
/// Supports different log levels, output destinations, and formatting options
internal final class LoggingService: SyncLoggerProtocol {
    
    // MARK: - Properties
    
    /// Log level configuration
    public enum LogLevel: Int, CaseIterable, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    /// Logging destination options
    public enum LogDestination {
        case console
        case osLog
        case file(URL)
        case custom((LogLevel, String) -> Void)
    }
    
    // MARK: - Configuration
    
    /// Current log level - only messages at this level or higher will be logged
    internal var logLevel: LogLevel
    
    /// Active log destinations
    internal var destinations: Set<LogDestination>
    
    /// Date formatter for log timestamps
    private let dateFormatter: DateFormatter
    
    /// OS Logger instance
    private let osLogger: Logger
    
    /// Queue for thread-safe file operations
    private let fileQueue = DispatchQueue(label: "com.swiftsupabasesync.logging", qos: .utility)
    
    /// Shared instance for convenience
    public static let shared = LoggingService()
    
    // MARK: - Initialization
    
    /// Initialize logging service
    /// - Parameters:
    ///   - logLevel: Minimum log level to output (default: .info)
    ///   - destinations: Where to output logs (default: console and osLog)
    ///   - subsystem: Subsystem identifier for OS logging
    ///   - category: Category for OS logging
    public init(
        logLevel: LogLevel = .info,
        destinations: Set<LogDestination> = [.console, .osLog],
        subsystem: String = "com.swiftsupabasesync",
        category: String = "Sync"
    ) {
        self.logLevel = logLevel
        self.destinations = destinations
        self.osLogger = Logger(subsystem: subsystem, category: category)
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        self.dateFormatter.timeZone = TimeZone.current
    }
    
    // MARK: - SyncLoggerProtocol Implementation
    
    /// Log debug message
    internal func debug(_ message: String) {
        log(.debug, message)
    }
    
    /// Log info message
    internal func info(_ message: String) {
        log(.info, message)
    }
    
    /// Log warning message
    internal func warning(_ message: String) {
        log(.warning, message)
    }
    
    /// Log error message
    internal func error(_ message: String) {
        log(.error, message)
    }
    
    // MARK: - Core Logging
    
    /// Core logging method
    /// - Parameters:
    ///   - level: Log level
    ///   - message: Message to log
    ///   - file: Source file (automatically captured)
    ///   - function: Source function (automatically captured)
    ///   - line: Source line (automatically captured)
    internal func log(
        _ level: LogLevel,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Check if this level should be logged
        guard level >= logLevel else { return }
        
        // Format the message
        let timestamp = dateFormatter.string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = formatMessage(
            level: level,
            message: message,
            timestamp: timestamp,
            file: fileName,
            function: function,
            line: line
        )
        
        // Send to each destination
        for destination in destinations {
            switch destination {
            case .console:
                logToConsole(level: level, message: formattedMessage)
                
            case .osLog:
                logToOSLog(level: level, message: message)
                
            case .file(let url):
                logToFile(url: url, message: formattedMessage)
                
            case .custom(let handler):
                handler(level, formattedMessage)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Format log message
    private func formatMessage(
        level: LogLevel,
        message: String,
        timestamp: String,
        file: String,
        function: String,
        line: Int
    ) -> String {
        return "\(timestamp) \(level.emoji) [\(file):\(line)] \(function) - \(message)"
    }
    
    /// Log to console
    private func logToConsole(level: LogLevel, message: String) {
        print(message)
    }
    
    /// Log to OS unified logging system
    private func logToOSLog(level: LogLevel, message: String) {
        osLogger.log(level: level.osLogType, "\(message)")
    }
    
    /// Log to file
    private func logToFile(url: URL, message: String) {
        fileQueue.async { [weak self] in
            guard self != nil else { return }
            
            do {
                let messageWithNewline = message + "\n"
                
                if FileManager.default.fileExists(atPath: url.path) {
                    // Append to existing file
                    let fileHandle = try FileHandle(forWritingTo: url)
                    fileHandle.seekToEndOfFile()
                    if let data = messageWithNewline.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                } else {
                    // Create new file
                    try messageWithNewline.write(to: url, atomically: true, encoding: .utf8)
                }
            } catch {
                // Fallback to console if file logging fails
                print("⚠️ Failed to write to log file: \(error.localizedDescription)")
                print(message)
            }
        }
    }
}

// MARK: - LogDestination Hashable

extension LoggingService.LogDestination: Hashable {
    internal static func == (lhs: LoggingService.LogDestination, rhs: LoggingService.LogDestination) -> Bool {
        switch (lhs, rhs) {
        case (.console, .console), (.osLog, .osLog):
            return true
        case (.file(let url1), .file(let url2)):
            return url1 == url2
        case (.custom, .custom):
            // Custom handlers are considered equal if they're the same case
            // In practice, you might want to store an identifier
            return true
        default:
            return false
        }
    }
    
    internal func hash(into hasher: inout Hasher) {
        switch self {
        case .console:
            hasher.combine("console")
        case .osLog:
            hasher.combine("osLog")
        case .file(let url):
            hasher.combine("file")
            hasher.combine(url)
        case .custom:
            hasher.combine("custom")
        }
    }
}

// MARK: - Convenience Methods

internal extension LoggingService {
    /// Configure logging for development
    static func configureForDevelopment() {
        shared.logLevel = .debug
        shared.destinations = [.console, .osLog]
    }
    
    /// Configure logging for production
    static func configureForProduction() {
        shared.logLevel = .warning
        shared.destinations = [.osLog]
    }
    
    /// Configure logging for testing
    static func configureForTesting() {
        shared.logLevel = .error
        shared.destinations = [.console]
    }
    
    /// Add file logging
    /// - Parameter url: File URL for log output
    func addFileLogging(to url: URL) {
        destinations.insert(.file(url))
    }
    
    /// Remove file logging
    /// - Parameter url: File URL to remove
    func removeFileLogging(from url: URL) {
        destinations.remove(.file(url))
    }
    
    /// Add custom logging handler
    /// - Parameter handler: Custom handler for log messages
    func addCustomHandler(_ handler: @escaping (LogLevel, String) -> Void) {
        destinations.insert(.custom(handler))
    }
}