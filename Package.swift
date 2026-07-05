// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "cmdFlow",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "cmdFlow",
            path: "Sources/cmdFlow",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
