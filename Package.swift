// swift-tools-version: 5.9

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "smockable",
  platforms: [
    .macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6),
  ],
  products: [
    .library(
      name: "Smockable",
      targets: ["Smockable"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-syntax", from: "509.0.0"),
  ],
  targets: [
    .macro(name: "SmockMacro", dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
    ]),
    .target(name: "Smockable", dependencies: [
        .target(name: "SmockMacro")
    ]),
    .testTarget(name: "SmockMacroTests", dependencies: [
        .target(name: "SmockMacro"),
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
    ]),
  ]
)
