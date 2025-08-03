# Network Infrastructure

Provides network communication services and HTTP client configuration. Handles connection management, error handling, and request/response processing for Supabase API interactions.

## Files

### NetworkError.swift
Comprehensive error types for all network operations. Features detailed error cases (no connection, timeout, HTTP errors, rate limiting), localized error descriptions, retry logic helpers (`isRetryable`, `suggestedRetryDelay`), and HTTP status code mapping. Use this for consistent error handling across all network operations.

### RequestBuilder.swift
Type-safe, fluent API for constructing HTTP requests. Features chainable builder pattern, automatic header management, query parameter encoding, JSON body serialization, and authentication helpers. Use this to build requests with compile-time safety and avoid manual URL construction.

### SupabaseClient.swift
Actor-based HTTP client specifically configured for Supabase APIs. Features automatic authentication token injection, retry logic with exponential backoff, concurrent request safety, convenient methods for common operations (GET, POST, PUT, PATCH, DELETE), and proper error mapping. Use this as the main network client for all Supabase API calls.

### NetworkMonitor.swift
Real-time network connectivity monitoring using the Network framework. Features connection type detection (WiFi, Cellular, Wired), network quality assessment, expensive/constrained connection detection, Combine publishers for reactive updates, and sync eligibility checking. Use this to adapt sync behavior based on network conditions and respect user data preferences.

### NetworkConfiguration.swift
Configuration and coordination layer for network operations. Features environment-specific configurations (development, production, background), `NetworkService` as the main coordinator, optional request/response logging, and factory methods for common setups. Use `NetworkService` as the main entry point for network operations in your app.

### Network.swift
Module documentation file that describes the network infrastructure components and their relationships. Import types from their specific files rather than using this file directly.