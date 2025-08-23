# Expectations

Learn how to configure mock behavior using Smockable's expectation system.

## Overview

Expectations are the core of Smockable's mocking system. They define how your mock should behave when methods are called, what values to return, what errors to throw, and how many times these behaviors should occur.

## Basic Expectations

### Return Values

Use `.value()` to specify what a method should return:

```swift
let expectations = MockUserService.Expectations()

// Simple return value
expectations.fetchUser_id.value(User(id: "123", name: "John"))

// Multiple different return values
expectations.fetchUser_id
    .value(user1)      // First call
    .value(user2)      // Second call
    .value(user3)      // Third call
```

### Throwing Errors

Use `.error()` to make a method throw an error:

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

## Advanced Patterns

### Chaining Expectations

You can chain multiple expectations for complex scenarios:

```swift
expectations.authenticate_username_password
    .error(AuthError.invalidCredentials).times(2)  // First 2 attempts fail
    .value(AuthToken(value: "valid-token"))        // Third attempt succeeds
    .error(AuthError.sessionExpired).unboundedTimes() // All further attempts fail
```

### Conditional Logic

Use closures for conditional behavior:

```swift
expectations.processPayment_amount_method.using { amount, method in
    switch method {
    case .creditCard:
        guard amount <= 10000 else {
            throw PaymentError.amountTooHigh
        }
        return PaymentResult.success
    case .bankTransfer:
        // Bank transfers have no limit
        return PaymentResult.pending
    }
}
```

### Stateful Mocks

Create stateful behavior using closures with captured variables:

```swift
var balance: Decimal = 1000

expectations.withdraw_amount.using { amount in
    guard balance >= amount else {
        throw BankError.insufficientFunds
    }
    balance -= amount
    return WithdrawalResult(newBalance: balance)
}

expectations.getBalance.using { _ in
    return balance
}.unboundedTimes()
```

## Working with Different Return Types

### Void Functions

For functions that return `Void`, use `()`:

```swift
expectations.updateUser.value(())
expectations.deleteUser_id.value(())
```

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

## Error Handling

### Throwing Functions

For throwing functions, you can mix successful returns and errors:

```swift
expectations.riskyOperation_input
    .value(successResult)
    .error(OperationError.temporaryFailure)
    .value(anotherSuccessResult)
    .error(OperationError.permanentFailure).unboundedTimes()
```

### Non-throwing Functions

You cannot use `.error()` with non-throwing functions - this will result in a compile error:

```swift
@Smock
protocol Service {
    func safeOperation() -> String  // Non-throwing
}

// This won't compile:
// expectations.safeOperation.error(SomeError())

// This is correct:
expectations.safeOperation.value("result")
```

## Best Practices

### 1. Set Up All Expectations Before Creating Mock

```swift
// Good: Set up all expectations first
let expectations = MockService.Expectations()
expectations.method1.value(result1)
expectations.method2.value(result2)
let mock = MockService(expectations: expectations)

// Avoid: Trying to modify expectations after mock creation
// This won't work - expectations are consumed during mock creation
```

### 2. Use Descriptive Test Data

```swift
// Good: Clear, descriptive test data
let validUser = User(id: "valid-123", name: "John Doe", email: "john@example.com")
let invalidUser = User(id: "", name: "", email: "invalid-email")

expectations.validateUser.value(true).value(false)

// Better: Use the actual test data in expectations
expectations.validateUser
    .using { user in user.id.isEmpty ? false : true }
```

### 3. Handle Edge Cases

```swift
expectations.divide_by.using { divisor in
    guard divisor != 0 else {
        throw MathError.divisionByZero
    }
    return 10.0 / divisor
}
```

### 4. Use Unbounded Times Carefully

```swift
// Good: Specific expectations followed by fallback
expectations.fetchConfig
    .value(config1).times(1)           // First call
    .value(config2).times(2)           // Next 2 calls  
    .error(ConfigError.unavailable).unboundedTimes()  // All remaining calls

// Avoid: Starting with unbounded - no further expectations can be added
// expectations.fetchConfig.value(config).unboundedTimes().value(other) // Won't work
```

## Next Steps

- Learn about <doc:Verification> to check how your mocks were used
- Explore <doc:AsyncAndThrowing> for async and throwing function patterns
- See <doc:CommonPatterns> for real-world examples