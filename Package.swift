// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DriveCaffeine",
    platforms: [.macOS(.v13)],
    targets: [
        // The testable core. No UI, no @main. `swift test` exercises this with
        // no external drive — the error-triage, identity, and selection logic
        // are all pure or temp-file-backed.
        .target(
            name: "DriveCaffeineKit"
        ),
        // The app shell. Thin SwiftUI layer over the kit. Built into a signed
        // .app bundle by build.sh (swiftc + ad-hoc codesign), not `swift run`,
        // because it needs the sandbox entitlements + LSUIElement Info.plist.
        .executableTarget(
            name: "DriveCaffeineApp",
            dependencies: ["DriveCaffeineKit"]
        ),
        .testTarget(
            name: "DriveCaffeineKitTests",
            dependencies: ["DriveCaffeineKit"]
        ),
    ]
)
