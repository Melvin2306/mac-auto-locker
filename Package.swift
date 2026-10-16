// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WordLock",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "WordLockCore"),
        .executableTarget(name: "WordLock", dependencies: ["WordLockCore"]),
        .testTarget(name: "WordLockCoreTests", dependencies: ["WordLockCore"]),
    ]
)
