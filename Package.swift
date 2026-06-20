// swift-tools-version: 5.9

import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let executableExcludes = [
    ".codex",
    ".git",
    "Benchmark.swift",
    "benchmark_keychain.swift",
    "script",
    "Tests",
    "README.md",
    "Widget"
] + ["dist", "ScrutinyMonitor.xctestplan"].filter {
    FileManager.default.fileExists(atPath: packageDirectory + "/" + $0)
}

let package = Package(
    name: "ScrutinyMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ScrutinyMonitor", targets: ["ScrutinyMonitor"])
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.2")
    ],
    targets: [
        .executableTarget(
            name: "ScrutinyMonitor",
            path: ".",
            exclude: executableExcludes,
            sources: [
                "App",
                "Models",
                "Services",
                "Stores",
                "Support",
                "enums",
                "Views"
            ]
        ),
        .executableTarget(
            name: "ScrutinyMonitorWidget",
            path: "Widget",
            exclude: [
                "Info.plist",
                "ScrutinyMonitorWidget.entitlements"
            ],
            sources: [
                "Widget.swift",
                "Models",
                "Services",
                "Support",
                "enums",
                "Stores"
            ]
        ),
        .testTarget(
            name: "ScrutinyMonitorTests",
            dependencies: [
                "ScrutinyMonitor",
                .product(name: "ViewInspector", package: "ViewInspector")
            ],
            path: "Tests/ScrutinyMonitorTests"
        ),
        .testTarget(
            name: "ScrutinyMonitorUITests",
            dependencies: [
                "ScrutinyMonitor",
                .product(name: "ViewInspector", package: "ViewInspector")
            ],
            path: "Tests/ScrutinyMonitorUITests",
            exclude: ["__Snapshots__"]
        ),
        .testTarget(
            name: "ModelsTests",
            dependencies: [
                "ScrutinyMonitor"
            ],
            path: "Tests/ModelsTests"
        ),
        .testTarget(
            name: "WidgetTests",
            dependencies: [
                "ScrutinyMonitorWidget",
                "ScrutinyMonitor"
            ],
            path: "Tests/WidgetTests"
        )
    ]
)
