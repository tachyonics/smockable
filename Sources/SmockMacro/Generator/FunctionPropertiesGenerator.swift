import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionPropertiesGenerator {
    static func expectationsOptionsClassDeclaration(
        variablePrefix: String,
        functionSignature: FunctionSignatureSyntax
    ) throws -> ClassDeclSyntax {

        var genericParameterClauseElements: [String] = []
        if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
            genericParameterClauseElements.append("ErrorableFieldOptionsProtocol")
        }

        if functionSignature.returnClause?.type != nil {
            genericParameterClauseElements.append("ReturnableFieldOptionsProtocol")
        } else {
            genericParameterClauseElements.append("VoidReturnableFieldOptionsProtocol")
        }

        return try ClassDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_FieldOptions",
            genericParameterClause: genericParameterClauseElements.count > 0
                ? ": \(raw: genericParameterClauseElements.joined(separator: ", ")) " : nil,
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    var expectedResponse: \(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse?
                    """
                )

                try VariableDeclSyntax(
                    """
                    var times: Int?
                    """
                )

                try FunctionDeclSyntax(
                    """
                    public func update(using closure: @Sendable @escaping \(ClosureGenerator.closureElements(functionSignature: functionSignature))) {
                      self.expectedResponse = .closure(closure)
                    }
                    """
                )

                if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
                    try FunctionDeclSyntax(
                        """
                        public func update(error: Swift.Error) {
                          self.expectedResponse = .error(error)
                        }
                        """
                    )
                }

                if let returnType = functionSignature.returnClause?.type {
                    try FunctionDeclSyntax(
                        """
                        public func update(value: \(returnType)) {
                          self.expectedResponse = .value(value)
                        }
                        """
                    )
                } else {
                    try FunctionDeclSyntax(
                        """
                        public func success() {
                          self.expectedResponse = .success
                        }
                        """
                    )
                }

                try FunctionDeclSyntax(
                    """
                    public func update(times: Int?) {
                      self.times = times
                    }
                    """
                )
            }
        )
    }

    static func expectedResponseEnumDeclaration(
        variablePrefix: String,
        functionSignature: FunctionSignatureSyntax
    ) throws -> EnumDeclSyntax {
        try EnumDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse",
            genericParameterClause: ": Sendable",
            memberBlockBuilder: {
                try EnumCaseDeclSyntax(
                    """
                    case closure(@Sendable \(ClosureGenerator.closureElements(functionSignature: functionSignature)))
                    """
                )

                if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
                    try EnumCaseDeclSyntax(
                        """
                        case error(Swift.Error)
                        """
                    )
                }

                if let returnType = functionSignature.returnClause?.type {
                    try EnumCaseDeclSyntax(
                        """
                        case value(\(returnType))
                        """
                    )
                } else {
                    try EnumCaseDeclSyntax(
                        """
                        case success
                        """
                    )
                }
            }
        )
    }

    static func expectedResponseVariableDeclaration(
        variablePrefix: String,
        functionDeclaration: FunctionDeclSyntax,
        accessModifier: String,
        staticName: Bool
    ) throws -> VariableDeclSyntax {
        let expectedResponseType =
            "\(variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse"
        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let parameterList = functionDeclaration.signature.parameterClause.parameters
        let inputMatcherType =
            parameterList.count > 0
            ? "\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher" : "AlwaysMatcher"

        return try VariableDeclSyntax(
            """
            \(raw: accessModifier)var \(raw: staticName ? "expectedResponses" : variablePrefix): [(Int?,\(raw: expectedResponseType),\(raw: inputMatcherType))] = []
            """
        )
    }

    static func verifierClassDeclaration(
        functionDeclarations: [FunctionDeclSyntax],
        isComparableProvider: (String) -> Bool
    ) throws -> StructDeclSyntax {
        try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "Verifier",
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    private let storage: Storage
                    """
                )

                try VariableDeclSyntax(
                    """
                    private let mode: VerificationMode
                    """
                )

                try VariableDeclSyntax(
                    """
                    private let sourceLocation: SourceLocation
                    """
                )

                try InitializerDeclSyntax(
                    "init(storage: Storage, mode: VerificationMode, sourceLocation: SourceLocation) {"
                ) {
                    ExprSyntax("self.storage = storage")
                    ExprSyntax("self.mode = mode")
                    ExprSyntax("self.sourceLocation = sourceLocation")
                }

                // Generate verifier methods for each function
                for functionDeclaration in functionDeclarations {
                    let parameterList = functionDeclaration.signature.parameterClause.parameters
                    let parameters = Array(parameterList)
                    let allParameterSequences = AllParameterSequenceGenerator.getAllParameterSequences(
                        parameters: parameters[...],
                        isComparableProvider: isComparableProvider
                    )

                    if parameters.isEmpty {
                        let functionName = functionDeclaration.name.text
                        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                        let functionSignature = "\(functionName)()"

                        // Function with no parameters
                        try FunctionDeclSyntax(
                            """
                            public func \(raw: functionName)() async {
                                let matchingCount = await storage.receivedInvocations.\(raw: variablePrefix).count
                                
                                VerificationHelper.performVerification(
                                    mode: mode,
                                    matchingCount: matchingCount,
                                    functionName: "\(raw: functionSignature)",
                                    sourceLocation: self.sourceLocation
                                )
                            }
                            """
                        )
                    } else {
                        // Generate all combinations where each parameter can be either explicit matcher or range
                        for parameterSequence in allParameterSequences {
                            try generateMethodForCombination(
                                functionDeclaration: functionDeclaration,
                                parameterSequence: parameterSequence
                            )
                        }
                    }
                }
            }
        )
    }

    /// Generate a specific method for a parameter type combination
    private static func generateMethodForCombination(
        functionDeclaration: FunctionDeclSyntax,
        parameterSequence: [(FunctionParameterSyntax, Bool, AllParameterSequenceGenerator.ParameterForm)]
    ) throws -> FunctionDeclSyntax {
        var methodParameters: [String] = []
        var methodInterpolationParameters: [String] = []
        var matcherInitializers: [String] = []

        let allParametersAreMatchers: Bool = parameterSequence.reduce(into: true) { partialResult, entry in
            if case .explicitMatcher = entry.2 {
                return
            }

            partialResult = false
        }

        for (parameter, isComparable, form) in parameterSequence {
            let paramName = parameter.secondName?.text ?? parameter.firstName.text
            let paramNameForSignature: String
            let paramNameForCall: String
            if let secondName = parameter.secondName?.text {
                paramNameForSignature = "\(parameter.firstName.text) \(secondName)"
                paramNameForCall = secondName
            } else {
                paramNameForSignature = parameter.firstName.text
                paramNameForCall = parameter.firstName.text
            }
            let paramType = parameter.type.description
            let isOptional = paramType.hasSuffix("?")

            var matcherInitializerPrefix: String
            if parameter.firstName.text == "_" {
                // when allParametersAreMatchers != true, we will delegate to the all matchers variant
                matcherInitializerPrefix = allParametersAreMatchers ? "\(paramNameForCall): " : ""
            } else {
                matcherInitializerPrefix =
                    allParametersAreMatchers ? "\(paramNameForCall): " : "\(parameter.firstName.text): "
            }

            if paramType == "String" || paramType == "String?" {
                methodInterpolationParameters.append(
                    """
                    \(paramNameForSignature): \\"\\(\(paramName).description)\\"
                    """
                )
            } else {
                methodInterpolationParameters.append("\(paramNameForSignature): \\(\(paramName).description)")
            }

            switch form {
            case .range:
                if isOptional {
                    let baseType = String(paramType.dropLast())  // Remove '?'
                    methodParameters.append("\(paramNameForSignature): ClosedRange<\(baseType)>")
                    matcherInitializers.append("\(matcherInitializerPrefix).range(\(paramName))")
                } else {
                    methodParameters.append("\(paramNameForSignature): ClosedRange<\(paramType)>")
                    matcherInitializers.append("\(matcherInitializerPrefix).range(\(paramName))")
                }
            case .explicitMatcher:
                let typePrefix = isComparable ? "" : "NonComparable"
                if isOptional {
                    let baseType = String(paramType.dropLast())  // Remove '?'
                    methodParameters.append("\(paramNameForSignature): Optional\(typePrefix)ValueMatcher<\(baseType)>")
                    matcherInitializers.append("\(matcherInitializerPrefix)\(paramName)")
                } else {
                    methodParameters.append("\(paramNameForSignature): \(typePrefix)ValueMatcher<\(paramType)>")
                    matcherInitializers.append("\(matcherInitializerPrefix)\(paramName)")
                }
            case .exact:
                methodParameters.append("\(paramNameForSignature): \(paramType)")
                matcherInitializers.append("\(matcherInitializerPrefix).exact(\(paramName))")
            }
        }

        let methodSignature = methodParameters.joined(separator: ", ")
        let matcherInit = matcherInitializers.joined(separator: ", ")
        let methodInterpolation = methodInterpolationParameters.joined(separator: ", ")

        let parameterList = functionDeclaration.signature.parameterClause.parameters
        let parameters = Array(parameterList)
        let matcherCall = AllParameterSequenceGenerator.generateMatcherCall(
            parameters: parameters,
            prefix: "invocation."
        )

        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let inputMatcherType = "\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
        let functionName = functionDeclaration.name.text
        let functionInterpolationSignature = "\(functionName)(\(methodInterpolation))"

        // if this is not a varient with all matcher inputs
        if !allParametersAreMatchers {
            return try FunctionDeclSyntax(
                """
                public func \(raw: functionName)(\(raw: methodSignature)) async {
                    return await \(raw: functionName)(\(raw: matcherInit))
                }
                """
            )
        }

        // Function with parameters
        return try FunctionDeclSyntax(
            """
            public func \(raw: functionName)(\(raw: methodSignature)) async {
                let matcher = \(raw: inputMatcherType)(\(raw: matcherInit))
                let matchingCount = await storage.receivedInvocations.\(raw: variablePrefix).filter { invocation in
                    matcher.matches(\(raw: matcherCall))
                }.count
                
                VerificationHelper.performVerification(
                    mode: mode,
                    matchingCount: matchingCount,
                    functionName: "\(raw: functionInterpolationSignature)",
                    sourceLocation: self.sourceLocation
                )
            }
            """
        )
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        prefix(1).uppercased() + dropFirst()
    }

    func capitalizingComponentsFirstLetter() -> String {
        let components = self.split(separator: "_").map { String($0).capitalizingFirstLetter() }

        return components.joined(separator: "_")
    }
}
