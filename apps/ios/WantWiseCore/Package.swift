// swift-tools-version: 6.0
import PackageDescription

// Foundation-only domain logic for WantWise (DECISIONS.md D-004).
// Must build and test on Linux: never import SwiftUI, SwiftData, UIKit or other Apple-only frameworks here.
let package = Package(
    name: "WantWiseCore",
    platforms: [
        // Package minimum stays at iOS 17 so the app's deployment target (D-021) can be either 17 or 18.
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "WantWiseCore", targets: ["WantWiseCore"]),
    ],
    targets: [
        .target(name: "WantWiseCore"),
        .testTarget(name: "WantWiseCoreTests", dependencies: ["WantWiseCore"]),
    ]
)
