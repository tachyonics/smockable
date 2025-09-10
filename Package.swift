// swift-tools-version:6.0

import CompilerPluginSupport
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
            ]
        ),
        .target(
            name: "Smockable",
            dependencies: [
                .target(name: "SmockMacro")
            ]
        ),
        .testTarget(
            name: "SmockMacroTests",
            dependencies: [
                .target(name: "Smockable"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
