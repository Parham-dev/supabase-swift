# Presentation Layer

This layer provides reactive interfaces for UI consumption and manages presentation state. It bridges the gap between domain use cases and SwiftUI views by exposing Combine publishers and view models.

The Presentation layer ensures that UI components can reactively respond to changes in authentication state, synchronization progress, and subscription status without tight coupling to business logic.