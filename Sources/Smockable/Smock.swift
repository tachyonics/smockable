@attached(peer, names: prefixed(Mock))
public macro Smock(named name: String? = nil) =
    #externalMacro(
        module: "SmockMacro",
        type: "SmockMacro"
    )

// MARK: - Stringify Macro

/// "Stringify" the provided value and produce a tuple that includes both the
/// original value as well as the source code that generated it.
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) =
    #externalMacro(module: "SmockMacro", type: "StringifyMacro")
