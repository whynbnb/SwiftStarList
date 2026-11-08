// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftStarList",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "SwiftStarList", targets: ["SwiftStarList"]),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "SwiftStarList",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "SwiftStarList",
            exclude: ["SwiftStarList.entitlements"],
            resources: [
                .process("Assets.xcassets")
            ]
        ),
    ]
)
