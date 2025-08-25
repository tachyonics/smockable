@attached(peer, names: prefixed(Mock))
public macro Smock(named name: String? = nil) =
  #externalMacro(
    module: "SmockMacro",
    type: "SmockMacro")
