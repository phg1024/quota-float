// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuotaFloat",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "QuotaKit"),
        .executableTarget(name: "QuotaFloat", dependencies: ["QuotaKit"]),
        .testTarget(name: "QuotaKitTests", dependencies: ["QuotaKit"]),
    ]
)
