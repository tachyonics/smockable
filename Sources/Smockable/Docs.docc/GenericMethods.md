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

The raw `.matching` matcher receives the constraint existential, so its closure
parameter is typed as `any Encodable & Sendable` and the test author would need to
cast it manually. Smockable provides ``ExistentialValueMatcher/matchingAs(_:_:)``
and ``ExistentialValueMatcher/exactAs(_:)`` to do that cast for you, so the
test closure / expected value is fully typed:

```swift
struct UserPayload: Equatable, Encodable, Sendable {
    let id: String
    let email: String
}

@Test func storeMatchingAs() async {
    var expectations = MockStorage.Expectations()
    when(
        expectations.store(item: .matchingAs(UserPayload.self) { payload in
            payload.email == "test@example.com"
        }),
        complete: .withSuccess
    )

    let mock = MockStorage(expectations: expectations)
    await mock.store(item: UserPayload(id: "u1", email: "test@example.com"))

    verify(mock, times: 1).store(item: .any)
}

@Test func storeExactAs() async {
    var expectations = MockStorage.Expectations()
    let expected = UserPayload(id: "u1", email: "test@example.com")
    when(
        expectations.store(item: .exactAs(expected)),
        complete: .withSuccess
    )

    let mock = MockStorage(expectations: expectations)
    await mock.store(item: expected)

    verify(mock, times: 1).store(item: .any)
}
```

If the production code calls the method with a value that isn't a `UserPayload`,
the cast inside `matchingAs` / `exactAs` returns `false` and the matcher simply
doesn't match — it never crashes.

If you'd rather write the cast inline, the unwrapped form is still available:

```swift
when(
    expectations.store(item: .matching { (item: any Encodable & Sendable) in
        (item as? UserPayload)?.email == "test@example.com"
    }),
    complete: .withSuccess
)
```

## Wrapped Generic Parameters

When the parameter type *contains* a generic parameter inside a wrapper (e.g. `Foo<T>`,
`[T]`, `Optional<T>`), Smockable cannot express the wrapped existential as a storage type
— Swift doesn't allow types like `Foo<some Encodable & Sendable>` in storage positions.

In this case Smockable uses ``ExistentialValueMatcher`` with `any Sendable` as the
storage type. As with direct generics, you can either let
``ExistentialValueMatcher/matchingAs(_:_:)`` and ``ExistentialValueMatcher/exactAs(_:)``
do the cast for you, or write it manually inside `.matching`.

```swift
struct PutItemInput<ItemType: Encodable & Sendable>: Equatable, Sendable
where ItemType: Equatable {
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

@Test func putItemMatchingAs() async {
    var expectations = MockDatabase.Expectations()
    when(
        expectations.putItem(
            input: .matchingAs(PutItemInput<String>.self) { input in
                input.tableName == "users" && input.item == "hello"
            }
        ),
        complete: .withSuccess
    )

    let mock = MockDatabase(expectations: expectations)
    await mock.putItem(input: PutItemInput(tableName: "users", item: "hello"))
}

@Test func putItemExactAs() async {
    var expectations = MockDatabase.Expectations()
    let expected = PutItemInput(tableName: "users", item: "hello")
    when(
        expectations.putItem(input: .exactAs(expected)),
        complete: .withSuccess
    )

    let mock = MockDatabase(expectations: expectations)
    await mock.putItem(input: expected)
}
```

The manual-cast equivalent of `matchingAs` is still available if you prefer it:

```swift
when(
    expectations.putItem(input: .matching { (anyInput: any Sendable) in
        guard let typed = anyInput as? PutItemInput<String> else { return false }
        return typed.tableName == "users"
    }),
    complete: .withSuccess
)
```

> Tip: ``ExistentialValueMatcher/matchingAs(_:_:)`` and
> ``ExistentialValueMatcher/exactAs(_:)`` are available on every
> ``ExistentialValueMatcher`` used by the generic-method codepaths, so the same
> pattern works whether the parameter is a direct generic, a wrapped generic,
> or a non-generic existential parameter (like `any Encodable & Sendable`).

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

## Opaque `some` Parameters

Smockable also supports `some Constraint` opaque types in parameter position. They
are semantically equivalent to the explicit-generic form and produce the same mock
surface, so you can pick whichever reads more clearly in the protocol you are
mirroring.

```swift
// Direct opaque — equivalent to `func process<T: Encodable & Sendable>(item: T)`
@Smock
protocol DirectOpaqueService {
    func process(item: some Encodable & Sendable) async
}

// Wrapped opaque — equivalent to `func process<T: Sendable>(wrapper: GenericWrapper<T>)`
@Smock
protocol WrappedOpaqueService {
    func process(wrapper: GenericWrapper<some Sendable>) async
}
```

The matcher API and the choice of `matchingAs` / `exactAs` work the same way as for
explicit generics — see the **Direct Generic Parameters** and **Wrapped Generic
Parameters** sections above.

> Note: This applies to parameter position only. Swift forbids `some` in the
> return position of a protocol requirement (`func produce() -> some Encodable`
> fails to compile with *"'some' type cannot be the return type of a protocol
> requirement; did you mean to add an associated type?"*), so the case never
> arises for `@Smock`-annotated protocols.

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
