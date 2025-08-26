# Expectations

Learn how to configure mock behavior using Smockable's expectation system.

## Overview

Expectations are the core of Smockable's mocking system. They define how your mock should behave when methods are called, what values to return, what errors to throw, and how many times these behaviors should occur.

Expectations can only be set prior to a mock being created and are always passed into the constructor of the mock instance.

## Basic Expectations

### Return Values

Use `.value()` to specify what a method should return:

```swift
let expectations = MockUserService.Expectations()

// Simple return value
expectations.fetchUser_user.value(User(id: "123", name: "John"))

// Multiple different return values
expectations.fetchUser_user
    .value(user1)      // First call
    .value(user2)      // Second call
    .value(user3)      // Third call
```

### Functions with no Return Value

When a function has no return value use `.success()` to specify that the mocked implementation should return successfully.

```swift
let expectations = MockUserService.Expectations()

// Simple return value
expectations.setUser_user.success()
```

### Throwing Errors

Use `.error()` to make a method throw an error:

**Note:** The error expectation will only be available if the method or property can throw.

```swift
expectations.fetchUser_id.error(NetworkError.notFound)

// Mix values and errors
expectations.fetchUser_id
    .value(user1)                    // First call succeeds
    .error(NetworkError.timeout)     // Second call throws
    .value(user2)                    // Third call succeeds
```

### Custom Logic with Closures

Use `.using()` to provide custom logic:

```swift
// Simple closure
expectations.fetchUser_id.using { id in
    return User(id: id, name: "Generated User")
}

// Complex logic
expectations.processData_with.using { data, options in
    if options.validate {
        guard !data.isEmpty else {
            throw ValidationError.emptyData
        }
    }
    return ProcessedData(from: data)
}
```

## Call Count Modifiers

### Specific Number of Times

Use `.times()` to specify how many times an expectation should apply:

```swift
expectations.fetchUser_id
    .value(user1).times(3)    // Return user1 for first 3 calls
    .value(user2).times(2)    // Return user2 for next 2 calls
```

### Unbounded Times

Use `.unboundedTimes()` for expectations that should apply to all remaining calls:

```swift
expectations.fetchUser_id
    .value(user1).times(2)        // First 2 calls
    .error(NetworkError.notFound).unboundedTimes()  // All subsequent calls
```

### Default Behavior

If you don't specify a count modifier, it defaults to `.times(1)`:

```swift
// These are equivalent:
expectations.fetchUser_id.value(user1)
expectations.fetchUser_id.value(user1).times(1)
```

### Stateful Mocks

Using closures for your expectations allows you to manage state within your mock. The simplest way to do this is to capture
variables by the closure. However as your expectation closures may be called concurrently, any captured variables must 
themselves be thread-safe. As an example the following will not compile-

```swift
var lastCity: String?

expectations.getCurrentTemperature_for.using { city in
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
}.unboundedTimes()
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
expectations.getCurrentTemperature_for.using { city in
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
}.unboundedTimes()
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
expectations.withdraw_amount.using(logic.withdraw).unboundedTimes()
expectations.getBalance.using(logic.getBalance).unboundedTimes()
```

In this exanple, the `withdraw` implementation is checking the existing balance, subtracting the withdraw amount and then returning the new balance.
For correctness, you want to protect all three of these operations within the same actor isolation. This technique is also useful for larger protocols 
when you only need to test a subset of its functions. You can provide the implementations of those functions and let the mock provide implementations 
for the rest.

## Working with Different Return Types

### Optional Returns

Handle optional return types naturally:

```swift
expectations.findUser_email
    .value(user)        // Returns Optional(user)
    .value(nil)         // Returns nil
```

### Async Functions

Expectations work seamlessly with async functions:

```swift
expectations.fetchDataAsync_from.using { url in
    // This closure can be async if needed
    let data = await someAsyncOperation(url)
    return data
}
```

## Next Steps

- Learn about <doc:Verification> to check how your mocks were used
- Explore <doc:AsyncAndThrowing> for async and throwing function patterns
- See <doc:CommonPatterns> for real-world examples
