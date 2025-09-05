import SwiftSyntax
import SwiftSyntaxBuilder

enum InputMatcherGenerator {
  /// Generate an input matcher struct for a specific function
  static func inputMatcherStructDeclaration(
    variablePrefix: String,
    parameterList: FunctionParameterListSyntax
  ) throws -> StructDeclSyntax? {
    // Only generate matcher if function has parameters
    guard !parameterList.isEmpty else { return nil }

    let structName = "\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
    let parameters = Array(parameterList)

    return try StructDeclSyntax(
      modifiers: [DeclModifierSyntax(name: "public")],
      name: TokenSyntax.identifier(structName),
      inheritanceClause: InheritanceClauseSyntax {
        InheritedTypeSyntax(type: IdentifierTypeSyntax(name: "Sendable"))
      },
      memberBlockBuilder: {
        // Generate properties for each parameter
        for parameter in parameters {
          try generateMatcherProperty(for: parameter)
        }

        // Generate matches method
        try generateMatchesMethod(parameters: parameters)
      })
  }

  /// Generate a matcher property for a function parameter
  private static func generateMatcherProperty(
    for parameter: FunctionParameterSyntax
  ) throws -> VariableDeclSyntax {
    let paramName = parameter.secondName?.text ?? parameter.firstName.text
    let paramType = parameter.type.description
    let isOptional = paramType.hasSuffix("?")

    if isOptional {
      let baseType = String(paramType.dropLast())  // Remove '?'
      return try VariableDeclSyntax(
        """
        let \(raw: paramName): OptionalValueMatcher<\(raw: baseType)>
        """)
    } else {
      return try VariableDeclSyntax(
        """
        let \(raw: paramName): ValueMatcher<\(raw: paramType)>
        """)
    }
  }

  /// Generate the matches method that checks if all parameters match
  private static func generateMatchesMethod(
    parameters: [FunctionParameterSyntax]
  ) throws -> FunctionDeclSyntax {
    // Build parameter list for matches method
    var methodParameters: [String] = []
    var matchChecks: [String] = []

    for parameter in parameters {
      let paramName = parameter.secondName?.text ?? parameter.firstName.text
      let paramType = parameter.type.description

      // Add parameter to method signature
      let firstName = parameter.firstName.text
      if firstName != paramName {
        methodParameters.append("\(firstName) \(paramName): \(paramType)")
      } else {
        methodParameters.append("\(paramName): \(paramType)")
      }

      // Add match check
      matchChecks.append("self.\(paramName).matches(\(paramName))")
    }

    let methodSignature = methodParameters.joined(separator: ", ")
    let matchCondition = matchChecks.joined(separator: " && ")

    return try FunctionDeclSyntax(
      """
      func matches(\(raw: methodSignature)) -> Bool {
          return \(raw: matchCondition)
      }
      """)
  }
}
