// swift-tools-version:6.1

import CompilerPluginSupport
import Foundation
import PackageDescription

let package = Package(
    name: "smockable",
    platforms: [
        .macOS(.v15), .iOS(.v18), .watchOS(.v11), .tvOS(.v18),
    ],
    products: [
        .library(
            name: "Smockable",
            targets: ["Smockable"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax", "600.0.0"..<"602.0.0")
    ],
    targets: [
        .macro(
            name: "SmockMacro",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .target(name: "SmockableUtils"),
            ]
        ),
        .target(
            name: "Smockable",
            dependencies: [
                .target(name: "SmockMacro")
            ],
            swiftSettings: [
                .define("SMOCKABLE_UNHAPPY_PATH_TESTING")
            ]
            //swiftSettings: swiftSettingsForTopLevelPackage()
        ),
        .target(
            name: "SmockableUtils",
            dependencies: []
        ),
        .testTarget(
            name: "SmockMacroTests",
            dependencies: [
                .target(name: "Smockable"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .target(name: "SmockableUtils"),
            ],
            swiftSettings: [
                .define("SMOCKABLE_UNHAPPY_PATH_TESTING")
            ]
        ),
        .testTarget(
            name: "SmockableUtilsTests",
            dependencies: [
                .target(name: "SmockableUtils")
            ]
        ),
    ]
)

func swiftSettingsForTopLevelPackage() -> [SwiftSetting] {
    // Check if we're in the root of our own package by looking for specific files
    let fileManager = FileManager.default
    let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)

    // Look for package-specific files that indicate this is the top-level build
    let packageIndicators = [
        "README.md",
        ".git",
        "Sources/Smockable",
        "Tests/SmockMacroTests",
    ]

    let isTopLevel = packageIndicators.allSatisfy { indicator in
        fileManager.fileExists(atPath: currentDir.appendingPathComponent(indicator).path)
    }

    if isTopLevel {
        return [.define("SMOCKABLE_UNHAPPY_PATH_TESTING")]
    }
    return []
}
