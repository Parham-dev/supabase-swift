//
//  ValidationCacheManager.swift
//  SupabaseSwift
//
//  Created by Parham on 01/08/2025.
//

import Foundation

// MARK: - Cache Result Type

/// Internal cached validation result with timestamp
internal struct CachedValidationResult {
    let result: SubscriptionValidationResult
    let cachedAt: Date
}

// MARK: - Validation Cache Manager

/// Actor responsible for managing subscription validation cache
/// Provides efficient caching of validation results with expiration
internal actor ValidationCacheManager {
    
    // MARK: - Properties
    
    private var validationCache: [UUID: CachedValidationResult] = [:]
    private let cacheExpirationTime: TimeInterval
    private let maxCachedValidations: Int
    
    // MARK: - Initialization
    
    /// Initialize cache manager with configuration
    /// - Parameters:
    ///   - expirationTime: How long cache entries remain valid
    ///   - maxCachedValidations: Maximum number of cached validations
    init(expirationTime: TimeInterval, maxCachedValidations: Int) {
        self.cacheExpirationTime = expirationTime
        self.maxCachedValidations = maxCachedValidations
    }
    
    // MARK: - Cache Operations
    
    /// Get cached validation result if still valid
    /// - Parameter user: User to get cached validation for
    /// - Returns: Cached validation result if valid, nil if expired or not found
    func getCachedValidation(for user: User) -> SubscriptionValidationResult? {
        guard let cached = validationCache[user.id] else { return nil }
        
        // Check if cache is still valid
        let now = Date()
        guard now.timeIntervalSince(cached.cachedAt) < cacheExpirationTime else {
            validationCache.removeValue(forKey: user.id)
            return nil
        }
        
        return cached.result.withCacheFlag(true)
    }
    
    /// Get cached validation result even if expired (fallback scenario)
    /// - Parameter user: User to get cached validation for
    /// - Returns: Cached validation result regardless of expiration, nil if not found
    func getExpiredCachedValidation(for user: User) -> SubscriptionValidationResult? {
        guard let cached = validationCache[user.id] else { return nil }
        return cached.result.withCacheFlag(true)
    }
    
    /// Cache a validation result for a user
    /// - Parameters:
    ///   - result: Validation result to cache
    ///   - user: User to cache validation for
    func cacheValidationResult(_ result: SubscriptionValidationResult, for user: User) {
        // Clean up cache if it's getting too large
        if validationCache.count >= maxCachedValidations {
            let oldestKey = validationCache.min { $0.value.cachedAt < $1.value.cachedAt }?.key
            if let keyToRemove = oldestKey {
                validationCache.removeValue(forKey: keyToRemove)
            }
        }
        
        validationCache[user.id] = CachedValidationResult(
            result: result,
            cachedAt: Date()
        )
    }
    
    /// Invalidate cached validation for a specific user
    /// - Parameter user: User whose cache to invalidate
    func invalidateCache(for user: User) {
        validationCache.removeValue(forKey: user.id)
    }
    
    /// Clear all cached validations
    func clearAllCache() {
        validationCache.removeAll()
    }
    
    /// Get current cache statistics
    /// - Returns: Tuple with cache count and memory usage estimate
    func getCacheStats() -> (count: Int, estimatedMemoryUsage: Int) {
        let count = validationCache.count
        let estimatedUsage = count * MemoryLayout<CachedValidationResult>.size
        return (count: count, estimatedMemoryUsage: estimatedUsage)
    }
}