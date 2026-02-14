# ``Smockable``

A Swift library that uses code generation through Macros for creating type-safe mocks from protocols.

## Overview

Smockable is a powerful Swift library that automatically generates mock implementations for your protocols. It provides a clean, type-safe and concurrency safe API for setting up expectations, verifying calls, and testing your code with confidence.

Smockable leverages Swift macros to generate mock code at compile time, ensuring type safety and optimal performance. Smockable's macro inspects the async methods and properties and creates an implementation that allows you to set expectations for when the mock implementation is used and retrieve the state of the mock to verify that the correct behaviour was performed.

When you annotate a protocol with `@Smock`, the macro generates a corresponding `Mock{ProtocolName}` struct that:

- Implements all protocol requirements
- Provides an expectations-based API for configuring behavior
- Tracks all method calls for verification
- Is thread-safe and Sendable
- Supports sync, async/await and throwing functions (including typed throws)
- Supports property getters (including async and/or throwing) and setters

## Topics

### Getting Started

- <doc:Capabilities>
- <doc:GettingStarted>

### Core Concepts

- <doc:Expectations>
- <doc:Verification>
- <doc:InOrderVerification>

### Advanced Topics

- <doc:TypedThrows>
- <doc:MacroParameters>
- <doc:AssociatedTypes>
- <doc:FrameworkLimitations>
