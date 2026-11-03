// swift-tools-version:5.9
// Open this folder in Xcode (File → Open… → the TrackTag folder) and press Run.
import PackageDescription
import Foundation

// Absolute path so the linker finds Info.plist no matter where Xcode runs it from.
let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("Support/Info.plist").path

let package = Package(
    name: "TrackTag",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TrackTag", targets: ["TrackTag"]),
    ],
    targets: [
        // Pure logic: Comments tags, title syntax, sound grades. No Apple-only frameworks,
        // so it is easy to test.
        .target(name: "TrackTagCore"),
        // The Mac app: SwiftUI screens + reading/writing the Music library.
        .executableTarget(
            name: "TrackTag",
            dependencies: ["TrackTagCore"],
            linkerSettings: [
                .linkedFramework("iTunesLibrary"),
                // Embeds Info.plist so macOS shows the "control Music" permission prompt.
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist", "-Xlinker", infoPlist]),
            ]
        ),
        .testTarget(name: "TrackTagCoreTests", dependencies: ["TrackTagCore"]),
    ]
)
