// swift-tools-version: 5.9
import PackageDescription

// VocablyCore — the portable, UI-free heart of the app.
// Builds and tests on Windows / Linux / macOS with the open-source Swift toolchain.
// No Apple-only frameworks (SwiftUI/SwiftData/StoreKit/VisionKit) are imported here,
// so the exact same code drops into the Xcode app later, behind the Live service impls.
let package = Package(
    name: "VocablyCore",
    platforms: [
        // Apple platforms only: gives access to modern concurrency (AsyncStream, etc.).
        // Windows/Linux builds ignore this and use the open-source toolchain defaults.
        .macOS(.v13),
        .iOS(.v17),
    ],
    products: [
        .library(name: "VocablyDomain", targets: ["VocablyDomain"]),
        .library(name: "SRSEngine", targets: ["SRSEngine"]),
        .library(name: "VocablyServices", targets: ["VocablyServices"]),
        .library(name: "VocablyPresentation", targets: ["VocablyPresentation"]),
        .executable(name: "vocably-cli", targets: ["VocablyCLI"]),
    ],
    targets: [
        .target(name: "VocablyDomain"),
        .target(name: "SRSEngine", dependencies: ["VocablyDomain"]),
        .target(name: "VocablyServices", dependencies: ["VocablyDomain"]),
        .target(name: "VocablyPresentation", dependencies: ["VocablyDomain", "SRSEngine"]),
        .executableTarget(
            name: "VocablyCLI",
            dependencies: ["VocablyDomain", "SRSEngine", "VocablyServices"]
        ),
        .testTarget(name: "VocablyDomainTests", dependencies: ["VocablyDomain"]),
        .testTarget(name: "SRSEngineTests", dependencies: ["SRSEngine", "VocablyDomain"]),
        .testTarget(name: "VocablyServicesTests", dependencies: ["VocablyServices", "VocablyDomain"]),
        .testTarget(name: "VocablyPresentationTests", dependencies: ["VocablyPresentation", "VocablyDomain", "SRSEngine"]),
    ]
)
