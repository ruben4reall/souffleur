// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SouffleurKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SouffleurCore", targets: ["SouffleurCore"]),
        .library(name: "SouffleurShell", targets: ["SouffleurShell"]),
    ],
    targets: [
        // The script, the voice tracker, pace and geometry: free of AppKit so they run under `swift test`.
        .target(name: "SouffleurCore"),
        // The prompter's window and drawing, speech, the library, controls and settings.
        .target(name: "SouffleurShell", dependencies: ["SouffleurCore"], resources: [.process("Resources")]),
        .testTarget(name: "SouffleurCoreTests", dependencies: ["SouffleurCore"]),
    ]
)
