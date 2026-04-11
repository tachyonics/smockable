# Generic Methods

Mocking protocol methods that have their own generic type parameters.

## Overview

Smockable supports protocol methods with their own generic parameters, like:

```swift
@Smock
protocol Storage {
    func store<T: Encodable & Sendable>(item: T) async
    func produce<T: Encodable & Sendable>(label: String) async -> T
}
```

Because the concrete type for `T` is only known at the point where the mock method is
called — not when the macro generates the mock — Smockable uses **type erasure** at the
matcher and storage layer. The exact ergonomics depend on whether the parameter type is
a direct generic reference or wraps the generic inside another type.

## Direct Generic Parameters

When the parameter type is exactly the generic parameter (e.g. `T`), Smockable stores
values using the generic parameter's constraint as an existential type. For
`T: Encodable & Sendable`, the storage type is `any Encodable & Sendable`.

```swift
@Smock
protocol Storage {
    func store<T: Encodable & Sendable>(item: T) async
}

@Test func storeAnyMatcher() async {
    var expectations = MockStorage.Expectations()
    when(expectations.store(item: .any), times: 2, complete: .withSuccess)

    let mock = MockStorage(expectations: expectations)
    await mock.store(item: "hello")
    await mock.store(item: 42)

    verify(mock, times: 2).store(item: .any)
}
```

The `.matching` matcher receives the constraint existential, so the closure parameter is
typed as `any Encodable & Sendable`. This requires that the test author cast to the actual concrete
type they expect in order to inspect properties or compare it to a concrete value:

```swift
struct UserPayload: Encodable, Sendable {
    let id: String
    let email: String
}

@Test func storeMatching() async {
    var expectations = MockStorage.Expectations()
    when(
        expectations.store(item: .matching { (item: any Encodable & Sendable) in
            (item as? UserPayload)?.email == "test@example.com"
        }),
        complete: .withSuccess
    )

    let mock = MockStorage(expectations: expectations)
    await mock.store(item: UserPayload(id: "u1", email: "test@example.com"))

    verify(mock, times: 1).store(item: .any)
}
```

## Wrapped Generic Parameters

When the parameter type *contains* a generic parameter inside a wrapper (e.g. `Foo<T>`,
`[T]`, `Optional<T>`), Smockable cannot express the wrapped existential as a storage type
— Swift doesn't allow types like `Foo<some Encodable & Sendable>` in storage positions.

In this case Smockable falls back to ``ErasedValueMatcher``, which stores values as
`any Sendable`. The matching closure receives `any Sendable`; the test author will again
need to cast to the expected concrete specialization.

```swift
struct PutItemInput<ItemType: Encodable & Sendable>: Sendable {
    let tableName: String
    let item: ItemType
}

@Smock
protocol Database {
    func putItem<ItemType: Encodable & Sendable>(input: PutItemInput<ItemType>) async
}

@Test func putItemAnyMatcher() async {
    var expectations = MockDatabase.Expectations()
    when(expectations.putItem(input: .any), times: 2, complete: .withSuccess)

    let mock = MockDatabase(expectations: expectations)
    await mock.putItem(input: PutItemInput(tableName: "users", item: 1))
    await mock.putItem(input: PutItemInput(tableName: "users", item: "hello"))

    verify(mock, times: 2).putItem(input: .any)
}

@Test func putItemMatching() async {
    var expectations = MockDatabase.Expectations()
    when(
        expectations.putItem(input: .matching { (anyInput: any Sendable) in
            guard let typed = anyInput as? PutItemInput<String> else { return false }
            return typed.tableName == "users"
        }),
        complete: .withSuccess
    )

    let mock = MockDatabase(expectations: expectations)
    await mock.putItem(input: PutItemInput(tableName: "users", item: "hello"))
}
```

## Generic Return Types

Methods with generic return types are supported via closure-based responses. The closure
returns a value typed as the storage type (the constraint existential for direct
generics, `any Sendable` for wrapped generics) — Swift implicitly upcasts concrete return
values. The mock implementation force-casts the returned value back to the declared
generic return type using the type information at the call site.

### Direct generic return

```swift
@Smock
protocol Producer {
    func produce<T: Encodable & Sendable>(label: String) async -> T
}

@Test func produceDirectReturn() async {
    var expectations = MockProducer.Expectations()
    expectations.produce(label: .any).update(using: { _ in
        "the answer"  // implicitly upcast to `any Encodable & Sendable`
    })

    let mock = MockProducer(expectations: expectations)
    // The caller's type annotation determines `T` and the mock force-casts the result.
    let result: String = await mock.produce(label: "x")
    #expect(result == "the answer")
}
```

### Wrapped generic return

```swift
@Smock
protocol Factory {
    func make<T: Sendable>(label: String) async -> Wrapper<T>
}

@Test func makeWrappedReturn() async {
    var expectations = MockFactory.Expectations()
    expectations.make(label: .any).update(using: { _ in
        Wrapper(value: 99)  // implicitly upcast to `any Sendable`
    })

    let mock = MockFactory(expectations: expectations)
    let result: Wrapper<Int> = await mock.make(label: "x")
    #expect(result.value == 99)
}
```

> Important: For generic return types, the test author **must** ensure the closure
> returns a value whose runtime type matches what the production code expects. A
> mismatch produces a runtime force-cast failure inside the mock.

## Constraints

> Note: Generic constraints **must** include `Sendable`. Mock state lives behind a `Mutex`
> and must be `Sendable`-conforming. The generated code will fail to compile if your
> generic parameter doesn't include `Sendable`.

Several matchers available for non-generic methods (`.exact()`, range, `update(value:)`)
are not available for parameters or return types that reference a generic parameter. See
<doc:FrameworkLimitations> for the full list and rationale.

## See Also

- <doc:AssociatedTypes>
- <doc:Expectations>
- <doc:FrameworkLimitations>
