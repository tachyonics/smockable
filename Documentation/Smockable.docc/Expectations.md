# Expectations

Learn how to configure mock behavior using Smockable's expectation system.

## Overview

Expectations are the core of Smockable's mocking system. They define how your mock should behave when methods are called, what values to return, what errors to throw, and how many times these behaviors should occur.

Expectations can only be set prior to a mock being created and are always passed into the constructor of the mock instance.

## Function-Style Range Matching

Smockable provides a powerful function-style API that allows you to match method calls based on parameter ranges, making your tests more flexible and expressive.

### Basic Range Matching

```swift
var expectations = MockUserService.Expectations()

// For functions that return values, use when()
when(expectations.fetchUser(id: "100"..."999"), return: user)
when(expectations.getUserProfile(name: "A"..."Z"), return: profile)

// For functions with no return type (Void)
when(expectations.updateUser(name: "A"..."Z", age: 18...65), complete: .withSuccess)
when(expectations.deleteUser(id: "100"..."999"), complete: .withSuccess)

// Match any value using .any
when(expectations.fetchUser(id: .any), return: defaultUser)
```

### Optional Parameter Matching

```swift
// Match nil values for functions returning values
when(expectations.processUser(name: "A"..."Z", age: .nil), return: "no age")

// Match non-nil values in range
when(expectations.processUser(name: "A"..."Z", age: .range(18...65)), return: "valid age")

// Match nil OR values in range
when(expectations.processUser(name: "A"..."Z", age: .nilOrRange(18...65)), return: "flexible age")

// For void functions with optional parameters
when(expectations.updateUser(name: "A"..."Z", age: .nil), complete: .withSuccess)
when(expectations.updateUser(name: "A"..."Z", age: .range(18...65)), complete: .withSuccess)
```

### Multiple Call Expectations

```swift
// Specify number of times expectation should apply
when(expectations.fetchUser(id: "100"..."999"), times: 3, return: user)
when(expectations.saveData(data: "A"..."Z"), times: 5, complete: .withSuccess)

// Unbounded expectations (apply to all matching calls)
when(expectations.fetchUser(id: .any), times: .unbounded, return: defaultUser)
when(expectations.logEvent(message: .any), times: .unbounded, complete: .withSuccess)
```

### Error Handling

```swift
// For functions that can throw errors and return values
when(expectations.fetchUser(id: "invalid"), throw: UserError.notFound)

// For functions that can throw errors but return void
when(expectations.saveData(data: "invalid"), throw: ValidationError.invalidData)
```

## Basic Expectations

### Return Values

Use `when()` with `return:` to specify what a method should return:

```swift
var expectations = MockUserService.Expectations()

// Simple return value with range matching
when(expectations.fetchUser(id: "100"..."999"), return: User(id: "123", name: "John"))

// Multiple different return values for different ranges
when(expectations.fetchUser(id: "001"..."099"), return: user1)
when(expectations.fetchUser(id: "100"..."199"), return: user2)
when(expectations.fetchUser(id: "200"..."299"), return: user3)

// Match any value
when(expectations.fetchUser(id: .any), return: defaultUser)
```

### Functions with no Return Value

When a function has no return value use `when(:times:complete)` (where times will default to 1 if not specified) to specify that the mocked
implementation should return successfully:

```swift
var expectations = MockUserService.Expectations()

// Functions that complete successfully
when(expectations.updateUser(name: "A"..."Z", age: 18...65), complete: .withSuccess)
when(expectations.deleteUser(id: "100"..."999"), complete: .withSuccess)
when(expectations.saveSettings(key: .any, value: .any), complete: .withSuccess)
```

### Throwing Errors

Use `when()` with `throw:` for both functions that return values and functions that return void:

**Note:** Error expectations are only available for methods that can throw.

```swift
// For functions that return values and can throw
when(expectations.fetchUser(id: "invalid"), throw: NetworkError.notFound)
when(expectations.fetchUser(id: "timeout"), throw: NetworkError.timeout)

// For functions that return void and can throw
when(expectations.saveData(data: "invalid"), throw: ValidationError.invalidData)
when(expectations.deleteUser(id: "000"), throw: UserError.notFound)

// Mix values and errors for different parameter ranges
when(expectations.fetchUser(id: "100"..."999"), return: user1)
when(expectations.fetchUser(id: "invalid"), throw: NetworkError.notFound)
when(expectations.fetchUser(id: .any), return: defaultUser)
```

### Custom Logic with Closures

Use `when()` with the `use:` parameter to provide custom logic. The closure comes after the `times:` parameter and can be used as a trailing closure:

```swift
// Simple closure for functions that return values (trailing closure syntax)
when(expectations.fetchUser(id: "A"..."Z"), times: .unbounded) { id in
    return User(id: id, name: "Generated User")
}

// With explicit use: parameter
when(expectations.fetchUser(id: "A"..."Z"), times: 3, use: myClosure)

// Complex logic with validation
when(expectations.processData(data: .any, options: .any), times: 1) { data, options in
    if options.validate {
        guard !data.isEmpty else {
            throw ValidationError.emptyData
        }
    }
    return ProcessedData(from: data)
}

// For void functions, use when with a closure that doesn't return anything
when(expectations.logMessage(level: .any, message: .any), times: .unbounded) { level, message in
    print("[\(level)] \(message)")
}
```

## Call Count Modifiers

### Specific Number of Times

Use the `times:` parameter to specify how many times an expectation should apply:

```swift
// For functions that return values
when(expectations.fetchUser(id: "100"..."999"), times: 3, return: user1)
when(expectations.fetchUser(id: "A"..."M"), times: 2, return: user2)

// For functions that return void
when(expectations.saveData(data: "A"..."Z"), times: 5, complete: .withSuccess)
when(expectations.deleteUser(id: "100"..."999"), times: 2, complete: .withSuccess)
```

### Unbounded Times

Use `times: .unbounded` for expectations that should apply to all matching calls:

```swift
// For functions that return values
when(expectations.fetchUser(id: "default"), times: .unbounded, return: defaultUser)
when(expectations.fetchUser(id: "error"), times: .unbounded, throw: NetworkError.notFound)

// For functions that return void
when(expectations.logEvent(message: .any), times: .unbounded, complete: .withSuccess)
```

### Default Behavior

If you don't specify a `times:` parameter, it defaults to `times: 1`:

```swift
// These are equivalent:
when(expectations.fetchUser(id: "123"), return: user1)
when(expectations.fetchUser(id: "123"), times: 1, return: user1)

// Same for void functions:
when(expectations.saveData(data: "test"), complete: .withSuccess)
when(expectations.saveData(data: "test"), times: 1, complete: .withSuccess)
```

### Stateful Mocks

Using closures for your expectations allows you to manage state within your mock. The simplest way to do this is to capture
variables by the closure. However as your expectation closures may be called concurrently, any captured variables must 
themselves be thread-safe. As an example the following will not compile-

```swift
var lastCity: String?

when(expectations.getCurrentTemperature(for: .any), times: .unbounded) { city in
    lastCity = city // error: Mutation of captured var 'balance' in concurrently-executing code

    switch city {
    case "London":
        return 15.0
    case "Paris":
        return 18.0
    case "New York":
        return 25.0
    default:
        throw WeatherError.cityNotFound
    }
}
```

Instead you will need to serial access to any state you want to use within your mock-

```swift
actor LastCity {
    var value: String?

    func set(_ value: String) {
      self.value = value
    }
}

// then within your test

let lastCity = LastCity() // note this is an immutable let variable
when(expectations.getCurrentTemperature(for: .any), times: .unbounded) { city in
    await lastCity.set(city)

    switch city {
    case "London":
        return 15.0
    case "Paris":
        return 18.0
    case "New York":
        return 25.0
    default:
        throw WeatherError.cityNotFound
    }
}
```

This also allows you to store custom state from the mock to use later in the test as part of verifications if required.

This technique of capturing variables is useful for use cases like this where interaction with the state within the mock is fairly limited.
However some times a mocked implementation of a method is so closely tied that it makes more sense for the actor itself to manage the entire
mocked implementation


```swift
protocol Bank {
    func withdraw(amount: Double) async throws -> Double
    func getBalance() async -> Double
  }

  enum BankError: Error {
    case insufficientFunds
  }

  actor MockBankLogic {
      var balance: Double = 1000

      func withdraw(amount: Double) async throws -> Double {
          guard balance >= amount else {
            throw BankError.insufficientFunds
        }
        balance -= amount
        return balance
      }

      func getBalance() async -> Double {
          return balance
      }
  }

// then in the test
let logic = MockBankLogic()
when(expectations.withdraw(amount: .any), times: .unbounded, use: logic.withdraw)
when(expectations.getBalance(), times: .unbounded, use: logic.getBalance)
```

In this exanple, the `withdraw` implementation is checking the existing balance, subtracting the withdraw amount and then returning the new balance.
For correctness, you want to protect all three of these operations within the same actor isolation. This technique is also useful for larger protocols 
when you only need to test a subset of its functions. You can provide the implementations of those functions and let the mock provide implementations 
for the rest.

## Working with Different Return Types

### Optional Returns

Handle optional return types naturally:

```swift
when(expectations.findUser(email: .any), return: user)        // Returns Optional(user)
when(expectations.findUser(email: .any), return: nil)         // Returns nil
```

### Async Functions

Expectations work seamlessly with async functions:

```swift
when(expectations.fetchDataAsync(from: .any), times: .unbounded) { url in
    // This closure can be async if needed
    let data = await someAsyncOperation(url)
    return data
}
```

## Next Steps

- Learn about <doc:Verification> to check how your mocks were used
