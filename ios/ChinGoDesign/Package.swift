// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChinGoDesign",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ChinGoDesign", targets: ["ChinGoDesign"]),
        .library(name: "ChinGoEngine", targets: ["ChinGoEngine"]),
    ],
    targets: [
        .target(name: "ChinGoDesign"),
        // Pure logic: no UIKit, no SwiftUI, no CoreLocation. Bond tiers, XP curves and
        // the k-anonymity gate all compile and test on macOS, so the rules that decide
        // who is visible to whom can be verified in a second from the command line
        // rather than only inside a simulator.
        .target(name: "ChinGoEngine"),
        .testTarget(name: "ChinGoDesignTests", dependencies: ["ChinGoDesign"]),
        .testTarget(name: "ChinGoEngineTests", dependencies: ["ChinGoEngine"]),
    ]
)
