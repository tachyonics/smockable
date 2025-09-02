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
- Supports async/await and throwing functions

**Note:** The due to the need for the mock implementations to be thread safe and Sendable, non-async functions and properties are not supported.

## Topics

### Getting Started

- <doc:Overview>
- <doc:GettingStarted>

### Core Concepts

- <doc:Expectations>
- <doc:Verification>

### Advanced Usage

- <doc:FrameworkLimitations>
- <doc:AssociatedTypes>

### Examples

- <doc:TestingStrategies>
