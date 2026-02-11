# Contributing to Smockable

## Requirements

- Swift 6.1 or later
- macOS 15.0+

## Building and Testing

Build the package in release mode with strict concurrency checking (matching CI):

```bash
swift build -c release -Xswiftc -strict-concurrency=complete
```

Run the test suite:

```bash
swift test
```

## Tooling

### swift-format

This repository uses [swift-format](https://github.com/swiftlang/swift-format) to enforce a consistent code style. The configuration is defined in `.swift-format` at the repository root.

To format all source files in place:

```bash
swift-format format --recursive --in-place .
```

To check for formatting issues without modifying files:

```bash
swift-format lint --recursive .
```

swift-format ships with the Swift 6.0+ toolchain, so no separate installation is needed.

### SwiftLint

[SwiftLint](https://github.com/realm/SwiftLint) is run in CI (version 3.2.1) against the `Sources/` directory. The configuration is defined in `.swiftlint.yml`.

If you have SwiftLint installed locally you can run it with:

```bash
swiftlint
```

## CI

Pull requests are validated by three GitHub Actions jobs:

| Job | Description |
|---|---|
| **Build & Test** | Builds and tests against the latest Swift toolchains |
| **SwiftLint** | Lints `Sources/` with SwiftLint 3.2.1 |
| **swift-format** | Verifies that all code in `Sources/` and `Tests/` is formatted correctly |

All three jobs must pass before a pull request can be merged.
