// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RiffMasterHID",
    platforms: [.macOS("27.0")],  // matches the Homebrew libusb archive this links
    targets: [
        // libusb headers only; the static archive is linked by the executable below
        // so the signed binary carries no Homebrew dylib dependency.
        .systemLibrary(name: "CLibUSB", path: "Sources/CLibUSB"),
        .target(name: "RiffMasterCore"),
        .executableTarget(
            name: "riffmaster-hid",
            dependencies: ["CLibUSB", "RiffMasterCore"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "/opt/homebrew/lib/libusb-1.0.a"]),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Security"),
            ]
        ),
        .testTarget(name: "RiffMasterCoreTests", dependencies: ["RiffMasterCore"]),
    ]
)
