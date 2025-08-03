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
            ],
            path: "Sources",
            exclude: [
                "Core/Data/README.md",
                "Core/Data/DataSources/README.md",
                "Core/Data/DataSources/Local/README.md", 
                "Core/Data/DataSources/Remote/README.md",
                "Core/Data/Extensions/README.md",
                "Core/Data/Models/README.md",
                "Core/Data/Models/DTOs/README.md",
                "Core/Data/Models/Mappers/README.md",
                "Core/Data/Repositories/README.md",
                "Core/Data/Services/README.md",
                "Core/Domain/README.md",
                "Core/Domain/Entities/README.md",
                "Core/Domain/Protocols/README.md",
                "Core/Domain/Services/README.md",
                "Core/Domain/UseCases/README.md",
                "Core/Common/Extensions/README.md",
                "DI/README.md",
                "Features/README.md",
                "Features/Authentication/README.md",
                "Features/Authentication/Data/README.md",
                "Features/Authentication/Domain/README.md", 
                "Features/Authentication/Presentation/README.md",
                "Features/Schema/README.md",
                "Features/Schema/Data/README.md",
                "Features/Schema/Domain/README.md",
                "Features/Subscription/README.md",
                "Features/Subscription/Domain/README.md",
                "Features/Subscription/Presentation/README.md",
                "Features/Synchronization/README.md",
                "Features/Synchronization/Data/README.md",
                "Features/Synchronization/Domain/README.md",
                "Features/Synchronization/Presentation/README.md",
                "Infrastructure/README.md",
                "Infrastructure/Logging/README.md",
                "Infrastructure/Network/README.md",
                "Infrastructure/Storage/README.md",
                "Infrastructure/Utils/README.md",
                "Public/README.md"
            ]
        ),
        .testTarget(
            name: "SwiftSupabaseSyncTests",
            dependencies: ["SwiftSupabaseSync"],
            path: "SupabaseSwiftTests"
        ),
    ]
)