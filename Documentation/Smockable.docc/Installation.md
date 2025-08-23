# Installation

How to add Smockable to your Swift project.

## Overview

Smockable can be added to your project using Swift Package Manager. It's designed to be used primarily in test targets, though the `@Smock` macro can be applied to protocols in your main code.

## Requirements

- **Swift**: 6.0 or later
- **Xcode**: 16.0 or later
- **Platforms**: 
  - iOS 13.0+
  - macOS 10.15+
  - tvOS 13.0+
  - watchOS 6.0+

## Swift Package Manager

### Using Package.swift

Add Smockable to your `Package.swift` file:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "YourPackage",
    dependencies: [
        .package(url: "https://github.com/tachyonics/smockable.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: [
                // Add to main target if you want to use @Smock in production code
                "Smockable"
            ]
        ),
        .testTarget(
            name: "YourTestTarget",
            dependencies: [
                "YourTarget",
                "Smockable" // Add to test target for creating mocks
            ]
        )
    ]
)
```

### Using Xcode

1. Open your project in Xcode
2. Select your project in the navigator
3. Go to the **Package Dependencies** tab
4. Click the **+** button
5. Enter the repository URL: `https://github.com/tachyonics/smockable.git`
6. Choose the version rule (recommended: "Up to Next Major Version")
7. Click **Add Package**
8. Select the targets where you want to use Smockable (typically test targets)

## Project Structure

### Recommended Setup

For most projects, we recommend this structure:

```
YourProject/
├── Sources/
│   └── YourModule/
│       ├── Protocols/
│       │   └── UserService.swift    // Contains @Smock protocols
│       └── Implementation/
│           └── RealUserService.swift
└── Tests/
    └── YourModuleTests/
        └── UserServiceTests.swift   // Uses MockUserService
```

### Protocol Placement

You have two options for where to place your `@Smock` annotated protocols:

#### Option 1: In Main Target (Recommended)

Place protocols with `@Smock` in your main target. This allows:
- Production code to depend on protocols
- Test code to use generated mocks
- Clean separation of concerns

```swift
// In main target: Sources/YourModule/UserService.swift
import Smockable

@Smock
public protocol UserService {
    func fetchUser(id: String) async throws -> User
}
```

#### Option 2: In Test Target

Place protocols only in test targets if they're purely for testing:

```swift
// In test target: Tests/YourModuleTests/TestProtocols.swift
import Smockable

@Smock
protocol TestableService {
    func performTestOperation() -> String
}
```

## Import Statements

In your test files, import Smockable to access the macro and generated mocks:

```swift
import XCTest
import Smockable
@testable import YourModule

class UserServiceTests: XCTestCase {
    func testUserFetching() async throws {
        let expectations = MockUserService.Expectations()
        // ... test implementation
    }
}
```

## Troubleshooting

### Common Issues

**"Cannot find 'MockProtocolName' in scope"**
- Ensure Smockable is added to your test target dependencies
- Verify the protocol is annotated with `@Smock`
- Check that you've imported Smockable in your test file

**"'@Smock' can only be applied to a 'protocol'"**
- The `@Smock` macro can only be used on protocol declarations
- Remove the macro from any non-protocol declarations

**Build errors related to Swift macros**
- Ensure you're using Swift 6.0+ and Xcode 16.0+
- Clean your build folder (Product → Clean Build Folder)
- Restart Xcode if macro expansion seems stuck

### Getting Help

If you encounter issues:
1. Check the [GitHub Issues](https://github.com/tachyonics/smockable/issues)
2. Review the <doc:CommonPatterns> for examples
3. Consult the <doc:BestPractices> guide