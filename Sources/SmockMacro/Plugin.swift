#if canImport(SwiftCompilerPlugin)
  import SwiftCompilerPlugin
  import SwiftSyntaxMacros

  @main
  struct SmockCompilerPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
      SmockMacro.self
    ]
  }
#endif
