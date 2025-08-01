// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftSupabaseSync",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "SwiftSupabaseSync",
            targets: ["SwiftSupabaseSync"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftSupabaseSync",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            sources: [
                "SwiftSupabaseSync.swift",
                "Core/Common/Extensions/ArrayExtensions.swift",
                "Infrastructure/Network/NetworkError.swift",
                "Core/Domain/Entities/SharedTypes.swift"
            ]
        ),
        .testTarget(
            name: "SwiftSupabaseSyncTests",
            dependencies: ["SwiftSupabaseSync"]
        ),
    ]
)