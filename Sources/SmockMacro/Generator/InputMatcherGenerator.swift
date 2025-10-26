import SwiftSyntax
import SwiftSyntaxBuilder

enum InputMatcherGenerator {
    /// Generate an input matcher struct for a specific function
    static func inputMatcherStructDeclaration(
        variablePrefix: String,
        parameterList: FunctionParameterListSyntax,
        typePrefix: String = "",
        accessLevel: AccessLevel,
        typeConformanceProvider: (String) -> TypeConformance
    ) throws -> StructDeclSyntax? {
        // Only generate matcher if function has parameters
        guard !parameterList.isEmpty else { return nil }

        let structName = "\(typePrefix)\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
        let parameters = Array(parameterList)

        return try StructDeclSyntax(
            modifiers: [accessLevel.declModifier],
            name: TokenSyntax.identifier(structName),
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: "Sendable"))
            },
            memberBlockBuilder: {
                // Generate properties for each parameter
                for parameter in parameters {
                    try generateMatcherProperty(for: parameter, typeConformanceProvider: typeConformanceProvider)
                }

                // Generate matches method
                try generateMatchesMethod(parameters: parameters)
            }
        )
    }

    /// Generate a matcher property for a function parameter
    private static func generateMatcherProperty(
        for parameter: FunctionParameterSyntax,
        typeConformanceProvider: (String) -> TypeConformance
    ) throws -> VariableDeclSyntax {
        let paramName = parameter.secondName?.text ?? parameter.firstName.text
        let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOptional = paramType.hasSuffix("?")
        let baseType = (isOptional ? String(paramType.dropLast()) : paramType)
        let typePrefix: String

        switch typeConformanceProvider(baseType) {
        case .comparableAndEquatable:
            typePrefix = ""
        case .onlyEquatable:
            typePrefix = "OnlyEquatable"
        case .neitherComparableNorEquatable:
            typePrefix = "NonComparable"
        }

        if isOptional {
            return try VariableDeclSyntax(
                """
                let \(raw: paramName): Optional\(raw: typePrefix)ValueMatcher<\(raw: paramType.dropLast())>
                """
            )
        } else {
            return try VariableDeclSyntax(
                """
                let \(raw: paramName): \(raw: typePrefix)ValueMatcher<\(raw: paramType)>
                """
            )
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
            """
        )
    }
}
