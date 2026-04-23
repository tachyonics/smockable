# Smockable — Improvements Backlog

This document tracks potential improvements and architectural changes for Smockable. Each
entry notes whether the change is source-breaking (and therefore worth doing before 1.0)
or purely additive (and can be added at any time).

## 1.0 Considerations

Before tagging 1.0, the public API surface gets locked in. Changes that would alter:

- Generated type names (`Mock<Protocol>`, `Expectations`, `<Method>_FieldOptions`, etc.)
- Method signatures on `Expectations` or the verifier
- The `@Smock` macro parameters
- Public matcher types (`ValueMatcher`, `ExistentialValueMatcher`)
- The `when(...)` / `verify(...)` free functions

become source-breaking after 1.0.

### Before 1.0 — completed

- **Generated `_InputMatcher` and `_ExpectedResponse` are now `internal`.** Both types are
  generated without an explicit access modifier (defaulting to `internal`) regardless of
  the protocol's access level. They're implementation details used by the public matcher
  API but should never be referenced directly by users. Verified safe by searching across
  known consumers (dynamo-db-tables, swift-local-containers, task-cluster) — no references
  found. This preserves freedom to refactor matcher and response storage in the future.
  `_FieldOptions` remains at the protocol's access
  level because Swift's visibility chain requires it: it's returned from public methods
  on `Expectations`.
- **Collapsed seven matcher types into two: `ValueMatcher<T>` and
  `ExistentialValueMatcher<T>`.** The original design had seven distinct enum
  types (`ValueMatcher`, `OnlyEquatableValueMatcher`, `NonComparableValueMatcher`,
  three `Optional*` variants, `ErasedValueMatcher`) with the macro selecting the
  right type per parameter based on conformance. The new design uses two structs:
  `ValueMatcher<T: Sendable>` for concrete parameters (with constraint-restricted
  factory methods — `.exact()` requires `Equatable`, `.range()` requires
  `Comparable`) and `ExistentialValueMatcher<T: Sendable>` for generic/existential
  parameters (with `.matchingAs` and `.exactAs` for type-safe casting). The macro
  generators now emit `ValueMatcher<T>` for concrete parameters and
  `ExistentialValueMatcher<T>` for generic parameters based on the existing
  `classify()` result — no conformance detection needed for matcher type selection.
  The `additionalEquatableTypes` / `additionalComparableTypes` allowlists are no
  longer needed for correctness (Swift's type system handles conformance at the
  call site) but are retained as an ergonomic convenience for shorthand overload
  generation.
- **`MockableFunction.classify` switched from string-based to TypeSyntax-walking
  identifier matching, and gained support for `some` opaque types in parameter
  position.** Two visitors now drive parameter classification:
  `GenericParameterReferenceFinder` walks a parameter type's syntax tree looking
  for `IdentifierTypeSyntax` references to known generic parameter names while
  skipping the trailing `name` of `MemberTypeSyntax` (so qualified member
  references like `MyModule.T` or `Optional<Foo.T>` no longer produce false
  positives), and `OpaqueSomeFinder` detects `SomeOrAnyTypeSyntax` nodes with
  `some` specifier to recognize implicit generics introduced by opaque parameter
  types. Direct opaque parameters (`func foo(item: some Encodable & Sendable)`)
  classify as `.directGeneric` with the constraint existential as their storage
  type, and wrapped opaque parameters (`func foo(input: PutItemInput<some
  Encodable>)`) classify as `.wrappedGeneric` — equivalent to writing the
  explicit generic form. Return-position `some` doesn't need handling because
  Swift forbids `some` in the return position of a protocol requirement
  (`func produce() -> some Encodable` fails to compile with *"'some' type
  cannot be the return type of a protocol requirement; did you mean to add an
  associated type?"*), so the case never reaches the macro. Closes IMPROVEMENTS
  what was previously two separate backlog items describing the same fix from
  different angles (qualified-name false positives, and `some` opaque parameter
  support).
- **Validated generic method API in real-world usage.** dynamo-db-tables
  integrated the case 1 / case 2 split, `ExistentialValueMatcher`, and
  `matchingAs` / `exactAs`. No ergonomics issues or naming concerns surfaced.
  The typed-protocol refactor that originally motivated the work was reverted
  (the Soto encoder flat-composition bug made it unnecessary), confirming that
  the generic method support stands on its own.
- **Documented `additionalEquatableTypes` / `additionalComparableTypes` as
  convenience-only.** `MacroParameters.md` rewritten to clarify that the
  allowlists control shorthand overload generation, not matcher correctness.
  After the matcher collapse, Swift's type system handles conformance at the
  call site — the allowlists are no longer needed for correctness.
- **`.exact` overload for case-1 generics with Equatable constraint.** When a
  direct generic parameter's constraint includes `Equatable` (or `Hashable`),
  the macro now emits an additional overload on `Expectations` / the verifier
  that takes a typed concrete value and delegates to `.exactAs(_:)` internally.
  Lets test authors write `when(expectations.process(item: "hello"))` and
  `verify(mock).process(item: "hello")` directly, instead of
  `.exactAs("hello")`, for case-1 generic methods whose constraint allows
  equality checking. Opted not to add a public `.exact` alias on
  `ExistentialValueMatcher` — the generators emit `.exactAs` internally,
  keeping the public matcher API single-named. Implemented as:
  `AllParameterSequence` routes `isEquatable` case-1 parameters through
  `.onlyEquatable` (producing both `.explicitMatcher` and `.exact` forms), and
  both `FunctionStyleExpectationsGenerator` and `VerifierGenerator` emit a
  `some <constraint>` parameter signature with `.exactAs(_)` as the matcher
  initializer for the `.exact` form.

## Improvement Backlog

### 1. Generic method parsing edge cases

**Status:** Mostly addressed — remaining items are speculative

**Source-breaking?** No.

**Description:**
The main issue (opaque `some` parameter types) was fixed as part of the
TypeSyntax-walking refactor (see "Before 1.0 — completed"). The remaining
known edge case is same-type requirements in where clauses (e.g.
`where T == String`), which Swift itself rejects on generic parameters
("same-type requirement makes generic parameter 'T' non-generic"). No
real-world failure has been reported for any remaining edge case.

**Recommendation:** Close unless a concrete failure surfaces. The generic
method parsing is well-tested via `MockableFunctionTests` (46 tests) and
the end-to-end `GenericMethodsTests` (23 tests).

---

### 2. Argument capture API

**Status:** Gap noted in framework comparison

**Source-breaking?** No. Pure addition alongside existing verifier-return-value capture.

**Description:**
Other frameworks (Mockolo, Cuckoo, SwiftyMocky, Mockingbird) provide `ArgumentCaptor`
APIs that allow registering a captor at expectation setup time and inspecting the captured
values later. Smockable currently exposes captured arguments through the verifier return
value (`verify(mock).foo(item: .any)` returns `[Item]`).

The verifier-return approach is fine for most cases, but a captor API can be more
ergonomic when:
- Capturing across multiple invocations with different matchers
- Capturing for use in subsequent assertions without rerunning verification
- Capturing arguments from invocations where matching is done by other parameters

**Possible API:**
```swift
let captor = ArgumentCaptor<String>()
when(expectations.process(item: captor.matcher), complete: .withSuccess)

// later
let mock = MockStorage(expectations: expectations)
await mock.process(item: "hello")
await mock.process(item: "world")

#expect(captor.values == ["hello", "world"])
```

**Open questions:**
- Should captors be Sendable? (Probably yes — they need to work across actor boundaries.)
- How do they interact with `times: N` constraints? Do they capture all matches or only
  matches that satisfied the expectation?
- How do they compose with `.matching` closures?

---

### 3. Diagnostic improvements

**Status:** Partially complete

**Source-breaking?** No.

**Completed:**

- **Generic constraint missing `Sendable`.** The macro now detects generic
  parameters whose constraints don't include `Sendable` and emits a clear
  error naming the specific parameter and function, instead of the user
  getting an opaque Sendability error deep in macro output.
- **`additionalEquatableTypes` / `additionalComparableTypes` parsing failures.**
  Three new contextual diagnostics replace the generic `invalidMacroArguments`:
  `missingArgumentLabel` (unlabeled arguments), `typeArrayExpected` (value
  isn't an array), and `invalidTypeArrayElement` (unrecognized element
  syntax, naming the specific element that failed).
- **`TypeConformanceProvider` crash-on-bad-input.** Six `fatalError()` calls
  in the type-string parser replaced with graceful fallback to
  `.neitherComparableNorEquatable`. Malformed type syntax in the allowlists
  no longer crashes the compiler — the user just loses convenience overloads
  for that parameter.

- **Warning on unparseable type strings.** When `TypeConformanceProvider` can't
  parse a type string, it emits a warning diagnostic via `MacroExpansionContext`
  naming the specific type string that failed, so the user knows why convenience
  overloads are missing. `MacroExpansionContext` is now threaded from the macro
  entry point through `MockGenerator` to the provider's warning handler.

**Remaining:**

- **Unsupported parameter forms.** When the macro can't generate matchers for a
  parameter (e.g. function types, certain closure types), the failure mode is
  opaque. A diagnostic detecting these at expansion time would save debugging.

---

### 4. Generic mock protocols beyond direct conformance

**Status:** Idea — not investigated

**Source-breaking?** Likely no, but unexplored.

**Description:**
Currently, the test author has to declare a "shadow" protocol with `@Smock` that mirrors
the protocol they want to mock, including any generic methods. This works but causes
friction:

- Generic method signatures must be re-declared exactly
- The `additionalEquatableTypes` allowlist applies only to the shadow protocol
- If the original protocol changes, the shadow has to be updated manually

A potential improvement: an `@Smock(mirroring: SomeProtocol.self)` form that takes the
type to mirror as input and copies the requirements automatically. Likely runs into the
same fundamental constraint of macros (can't introspect types from other modules), but
might be feasible for protocols in the same module.

**Open questions:**
- Is this even possible with current macro capabilities?
- How does it interact with associated types?
- Would the friction reduction be worth the complexity?

## Considered and Dropped

Items that were originally on the backlog but, after concrete analysis, are not
worth pursuing. Documented here so future readers don't re-litigate the same
ground.

### `@SmockSpecialize` annotation for case 2 generic methods

**Original idea:** A `@SmockSpecialize` attribute on `@Smock` protocol methods
that would let test authors substitute a concrete type (Form A) or a protocol
existential (Form B) for a wrapped generic parameter, so the macro could emit
richer per-parameter matchers instead of falling back to `ExistentialValueMatcher`.
The two forms were intended to address case 2 verbosity at the expectation /
verifier call site for protocols like
`func putItem<T: Encodable & Sendable>(input: PutItemInput<T>)`.

**Why dropped:** The original motivation — cleaner test authoring against case 2
parameters — is now mostly addressed by the `matchingAs(_:_:)` and `exactAs(_:)`
helpers on `ExistentialValueMatcher`. Test authors get a typed closure
or typed exact value via:

```swift
when(
    expectations.putItem(input: .matchingAs(PutItemInput<TestPayload>.self) { input in
        input.tableName == "test-table" && input.item.id == "abc"
    }),
    complete: .withSuccess
)

when(
    expectations.putItem(input: .exactAs(expectedInput)),
    complete: .withSuccess
)
```

The cast happens inside the framework. Failures return `false` from the matcher
rather than crashing. Multiple test types in the same protocol work without any
extra ceremony.

The remaining things `@SmockSpecialize` would have offered on top of this are
small: slightly cleaner call sites (no explicit type at every matcher use site),
collections of wrapped generics with per-element protocol interface
(`[PutItemInput<T>]` → `[any PutItemInputProtocol]`), and compile-time
enforcement of the type assumption instead of a runtime cast that returns
`false`. Of these, only the mixed-type-collection case is genuinely
unaddressable by `matchingAs`/`exactAs`, and no real-world use case has
surfaced for it. The ergonomic delta on the other two is too small to justify
the macro infrastructure (substitution map plumbing, parsing two annotation
forms, threading substituted types through six generators).

If a user surfaces a real need for typed-element matching on collections of
wrapped generics, this item is worth revisiting — likely as Form B only, since
Form A's value collapses almost entirely into `matchingAs`/`exactAs`. The
original two-form design notes are preserved in git history.

### Parameter packs for matcher infrastructure

**Original idea:** Replace the per-method generated `_InputMatcher` struct (and
the per-method tuple-based invocation records, capture types, etc.) with a
library-defined variadic generic shell using Swift 5.9 parameter packs:

```swift
struct InputMatcher<each Param: Sendable>: Sendable {
    let matchers: (repeat ValueMatcher<each Param>)
    func matches(_ args: repeat each Param) -> Bool { ... }
}
```

The macro would emit per-method `typealias`es into this single library type
instead of generating distinct struct definitions, with the goal of reducing
the volume of generated code and unifying the verifier's tuple-construction
codepaths.

**Status: technically unblocked, deferred as low-priority.**

The original blocker was matcher-type heterogeneity: smockable had seven
distinct matcher types (previously seven, now collapsed to `ValueMatcher`
and `ExistentialValueMatcher`),
and a `(repeat ValueMatcher<each Param>)` pack requires a uniform element type.
**If the matcher collapse lands** (collapsing the seven types into a single
`ValueMatcher<T>` with constraint-restricted factories), this blocker is
removed — `(repeat ValueMatcher<each Param>)` works because every parameter
uses the same matcher type.

A comparison with swift-mocking (which ships parameter packs successfully)
confirmed that their architecture achieves packs via three design choices:
a single uniform matcher type (`ArgMatcher<Argument>`), heterogeneous spy
storage via `@dynamicMemberLookup`, and per-call-site generic specialization.
Of these three, only the first (uniform matcher type) is a prerequisite for
smockable-style packs; the other two are swift-mocking-specific architectural
choices that smockable doesn't need to adopt. The matcher collapse provides
the uniform type.

**Why deferred rather than pursued:** the benefit is still purely
macro-internal cleanliness — less generated code per protocol method, fewer
string-templated per-parameter loops in the generators. The user-visible API
(`Expectations` struct, `when(...)` / `verify(...)`, matcher factories) is
completely unchanged. No test author's day gets better. The costs, while
small, are nonzero:

- **Parameter labels on `matches()` become positional.** Today the generated
  `_InputMatcher` has `func matches(id: String, includeDeleted: Bool)` with
  labels from the original protocol method. The library-defined pack version
  has `func matches(_ values: repeat each Param)` — positional only, because
  packs can't express labels. This is internal generated code that users never
  see, but a transposed-argument bug in the generator would compile silently
  where the labeled version would catch it.
- **The verifier's capture-return-type tuples still need labels** (e.g.
  `[(id: String, includeDeleted: Bool)]`), so half the generator's
  string-building stays regardless.
- **The pack type itself is ~50-100 lines of library code** that needs testing
  and maintenance, partially offsetting the generated-code savings.

**Recommendation:** defer until there's a concrete maintenance pain from
per-method struct generation. If the macro's per-method code emission becomes a
real burden (e.g., a new feature requires threading changes through every
generated `_InputMatcher`), parameter packs provide a real solution and the
path is clear. Until then, invest in user-visible improvements (`.exact()` for
case 1 generics, argument capture, diagnostics). There is no API-breakage
risk from doing this later — the change is entirely internal to macro output
and library internals.

## Notes on Test Coverage Measurement

**The generator files in `Sources/SmockMacro/Generator/` will always show 0% coverage
in Codecov reports.** This is a measurement artifact, not a real testing gap.

Swift macros run inside a separate compiler plugin process that the Swift compiler
invokes at build time. When the test runner executes, code coverage instrumentation
attaches to the **test process**, not the macro plugin process. So even though every
`@Smock`-annotated test protocol exercises the generators heavily during build, those
executions are invisible to the coverage tool.

The generators are tested **indirectly but exhaustively** via the macro-expanded mocks
in `Tests/SmockMacroTests/`. Each `@Smock` annotation triggers the full generator
pipeline, and the resulting mocks' behavior is asserted by the test cases. A bug in
any generator codepath would surface as a test failure or compile error in those
tests, even though Codecov reports the generator file at 0%.

The only generator-side file that *can* show real coverage is
`Sources/SmockMacro/Utils/MockableFunction.swift`, because `MockableFunctionTests.swift`
imports `@testable SmockMacro` and exercises it directly from the test process. New
package-level helpers added to the macro target should follow the same pattern: a
direct unit test file in `Tests/SmockMacroTests/` so the helper isn't subject to the
plugin-process coverage gap.

**What NOT to do:**
- Don't add lots of `assertMacroExpansion`-style tests purely to lift the coverage
  number — they're brittle and add maintenance burden without catching bugs that the
  existing behavior tests don't already catch.
- Don't add a Codecov ignore for the generator files without first making sure the
  team understands the rationale; the metric should be visibly low and explained,
  not silently hidden.

**What is reasonable:**
- Add direct unit tests for any pure helpers that live in `Sources/SmockMacro/Utils/`
  (e.g. `MockableFunction`, `TypeConformanceProvider`). These run in the test process
  and contribute real coverage.
- For generator code that's hard to exercise via mock-behavior tests (e.g. error
  paths, edge cases in syntax handling), targeted `assertMacroExpansion` tests are
  acceptable but should be the exception rather than the rule.

## Notes on Source Stability

**The package is 1.0-ready.** All pre-1.0 recommended items are completed:

- The generic method API (case 1/2 distinction, `ExistentialValueMatcher`,
  opaque `some` parameters) has been validated against dynamo-db-tables
- The matcher collapse (`ValueMatcher<T>` + `ExistentialValueMatcher<T>`)
  has been integrated and tested
- The `additionalEquatableTypes` / `additionalComparableTypes` allowlists
  have been documented as convenience-only
- Diagnostics cover the most common failure modes (missing Sendable,
  malformed type arrays, type-string parse failures)

All remaining backlog items (`.exact()` for case 1 generics, argument
capture, remaining diagnostics, generic mock protocols) are additive and
can ship in 1.x releases without source breaks.
