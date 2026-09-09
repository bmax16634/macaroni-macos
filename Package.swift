// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Macaroni",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Macaroni", targets: ["Macaroni"])
    ],
    targets: [
        .target(
            name: "MacaroniHIDShim",
            path: "Sources/MacaroniHIDShim",
            publicHeadersPath: "include",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "Macaroni",
            dependencies: ["MacaroniHIDShim"],
            path: "Sources/Macaroni",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("FinderSync"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "MacaroniTests",
            dependencies: ["Macaroni"],
            path: "Tests/MacaroniTests"
        )
    ]
)
