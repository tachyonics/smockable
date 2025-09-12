import SwiftSyntax
import SwiftSyntaxBuilder

enum VerifierGenerator {
    static func verifierStructDeclaration(
        functionDeclarations: [FunctionDeclSyntax],
        propertyDeclarations: [PropertyDeclaration] = [],
        typePrefix: String = "",
        storagePrefix: String = "",
        isComparableProvider: (String) -> Bool
    ) throws -> StructDeclSyntax {
        try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: typePrefix)Verifier",
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    private let state: State
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

                for propertyDeclaration in propertyDeclarations {
                    try VariableDeclSyntax(
                        """
                        let \(raw: propertyDeclaration.name): \(raw: propertyDeclaration.typePrefix)Verifier
                        """
                    )
                }

                try InitializerDeclSyntax(
                    "init(state: State, mode: VerificationMode, sourceLocation: SourceLocation) {"
                ) {
                    ExprSyntax("self.state = state")
                    ExprSyntax("self.mode = mode")
                    ExprSyntax("self.sourceLocation = sourceLocation")

                    for propertyDeclaration in propertyDeclarations {
                        ExprSyntax(
                            "self.\(raw: propertyDeclaration.name) = .init(state: state, mode: mode, sourceLocation: sourceLocation)"
                        )
                    }
                }

                try verifierFunctions(
                    functionDeclarations: functionDeclarations,
                    typePrefix: typePrefix,
                    storagePrefix: storagePrefix,
                    isComparableProvider: isComparableProvider
                )
            }
        )
    }

    @MemberBlockItemListBuilder
    private static func verifierFunctions(
        functionDeclarations: [FunctionDeclSyntax],
        typePrefix: String,
        storagePrefix: String,
        isComparableProvider: (String) -> Bool
    ) throws -> MemberBlockItemListSyntax {
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
                    public func \(raw: functionName)() {
                        let matchingCount = self.state.mutex.withLock { storage in
                            return storage.receivedInvocations.\(raw: storagePrefix)\(raw: variablePrefix)
                        }.count
                        
                        VerificationHelper.performVerification(
                            mode: mode,
                            matchingCount: matchingCount,
                            functionName: "\(raw: storagePrefix)\(raw: functionSignature)",
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
                        parameterSequence: parameterSequence,
                        typePrefix: typePrefix,
                        storagePrefix: storagePrefix
                    )
                }
            }
        }
    }

    private static func getParameters(
        parameterSequence: [(FunctionParameterSyntax, Bool, AllParameterSequenceGenerator.ParameterForm)],
        allParametersAreMatchers: Bool
    )
        -> (methodParameters: [String], methodInterpolationParameters: [String], matcherInitializers: [String])
    {
        var methodParameters: [String] = []
        var methodInterpolationParameters: [String] = []
        var matcherInitializers: [String] = []

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

        return (methodParameters, methodInterpolationParameters, matcherInitializers)
    }

    private static func getWithLockCall(variablePrefix: String, storagePrefix: String) -> FunctionCallExprSyntax {
        let lockProtectedStatements = CodeBlockItemListSyntax([
            CodeBlockItemSyntax(
                item: .stmt(
                    StmtSyntax(
                        ReturnStmtSyntax(
                            expression: ExprSyntax(
                                "storage.receivedInvocations.\(raw: storagePrefix)\(raw: variablePrefix)"
                            )
                        )
                    )
                )
            )
        ])

        let lockClosure = ClosureExprSyntax(
            signature: ClosureSignatureSyntax(
                parameterClause: .simpleInput(
                    ClosureShorthandParameterListSyntax([
                        ClosureShorthandParameterSyntax(name: .identifier("storage"))
                    ])
                )
            ),
            statements: lockProtectedStatements
        )

        return FunctionCallExprSyntax(
            calledExpression: MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("self.state.mutex")),
                declName: DeclReferenceExprSyntax(baseName: .identifier("withLock"))
            ),
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(expression: ExprSyntax(lockClosure))
            ])
        )
    }

    /// Generate a specific method for a parameter type combination
    private static func generateMethodForCombination(
        functionDeclaration: FunctionDeclSyntax,
        parameterSequence: [(FunctionParameterSyntax, Bool, AllParameterSequenceGenerator.ParameterForm)],
        typePrefix: String,
        storagePrefix: String,
    ) throws -> FunctionDeclSyntax {
        let allParametersAreMatchers: Bool = parameterSequence.reduce(into: true) { partialResult, entry in
            if case .explicitMatcher = entry.2 {
                return
            }

            partialResult = false
        }

        let (methodParameters, methodInterpolationParameters, matcherInitializers) = getParameters(
            parameterSequence: parameterSequence,
            allParametersAreMatchers: allParametersAreMatchers
        )

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
        let inputMatcherType = "\(typePrefix)\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
        let functionName = functionDeclaration.name.text
        let functionInterpolationSignature = "\(functionName)(\(methodInterpolation))"

        // if this is not a varient with all matcher inputs
        if !allParametersAreMatchers {
            return try FunctionDeclSyntax(
                """
                public func \(raw: functionName)(\(raw: methodSignature)) {
                    return \(raw: functionName)(\(raw: matcherInit))
                }
                """
            )
        }

        return try FunctionDeclSyntax("public func \(raw: functionName)(\(raw: methodSignature))") {
            VariableDeclSyntax(
                bindingSpecifier: .keyword(.let),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier("invocations")),
                        initializer: InitializerClauseSyntax(
                            equal: .equalToken(),
                            value: ExprSyntax(
                                getWithLockCall(variablePrefix: variablePrefix, storagePrefix: storagePrefix)
                            )
                        )
                    )
                ])
            )

            DeclSyntax(
                """
                let matcher = \(raw: inputMatcherType)(\(raw: matcherInit))
                """
            )

            DeclSyntax(
                """
                let matchingCount = invocations.filter { invocation in
                    matcher.matches(\(raw: matcherCall))
                }.count
                """
            )

            ExprSyntax(
                """
                VerificationHelper.performVerification(
                    mode: mode,
                    matchingCount: matchingCount,
                    functionName: "\(raw: storagePrefix)\(raw: functionInterpolationSignature)",
                    sourceLocation: self.sourceLocation
                )
                """
            )
        }
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
