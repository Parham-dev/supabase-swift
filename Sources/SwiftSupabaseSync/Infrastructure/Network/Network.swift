//
//  Network.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

/// Network Infrastructure Module
/// 
/// This module provides all networking functionality for SwiftSupabaseSync:
/// - HTTP client configured for Supabase APIs
/// - Type-safe request building
/// - Comprehensive error handling with retry logic
/// - Network connectivity monitoring
/// - Request/response logging for debugging
///
/// Import this module to access:
/// - NetworkError: Comprehensive error types for network operations
/// - RequestBuilder: Type-safe HTTP request builder
/// - HTTPMethod: HTTP method enumeration
/// - SupabaseClient: HTTP client configured for Supabase
/// - NetworkMonitor: Network connectivity monitoring
/// - NetworkConfiguration: Network configuration options
/// - NetworkService: Main network service coordinator