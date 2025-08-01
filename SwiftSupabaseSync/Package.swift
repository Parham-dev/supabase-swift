// swift-tools-version: 5.9
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
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftSupabaseSync",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "SwiftSupabaseSyncTests",
            dependencies: ["SwiftSupabaseSync"]
        ),
    ]
)