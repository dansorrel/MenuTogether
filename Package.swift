// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuTogether",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MenuTogether",
            path: "Sources/MenuTogether"
        )
    ]
)
