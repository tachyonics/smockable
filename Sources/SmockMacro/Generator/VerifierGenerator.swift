//===----------------------------------------------------------------------===//
//
// This source file is part of the Smockable open source project
//
// Copyright (c) 2026 the Smockable authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Smockable authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

//
//  VerifierGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum VerifierGenerator {
    static func verifierStructDeclaration(
        functionDeclarations: [FunctionDeclSyntax],
        propertyDeclarations: [PropertyDeclaration] = [],
        typePrefix: String = "",
        storagePrefix: String = "",
        typeConformanceProvider: (String) -> TypeConformance,
        accessLevel: AccessLevel
    ) throws -> StructDeclSyntax {
        try StructDeclSyntax(
            modifiers: [accessLevel.declModifier],
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

                try VariableDeclSyntax(
                    """
                    private let inOrder: InOrder?
                    """
                )

                for propertyDeclaration in propertyDeclarations {
                    try VariableDeclSyntax(
                        """
                        \(raw: accessLevel.rawValue) let \(raw: propertyDeclaration.name): \(raw: propertyDeclaration.typePrefix)Verifier
                        """
                    )
                }

                try InitializerDeclSyntax(
                    "init(state: State, mode: VerificationMode, sourceLocation: SourceLocation, inOrder: InOrder?) {"
                ) {
                    ExprSyntax("self.state = state")
                    ExprSyntax("self.mode = mode")
                    ExprSyntax("self.sourceLocation = sourceLocation")
                    ExprSyntax("self.inOrder = inOrder")

                    for propertyDeclaration in propertyDeclarations {
                        ExprSyntax(
                            "self.\(raw: propertyDeclaration.name) = .init(state: state, mode: mode, sourceLocation: sourceLocation, inOrder: inOrder)"
                        )
                    }
                }

                try verifierFunctions(
                    functionDeclarations: functionDeclarations,
                    typePrefix: typePrefix,
                    storagePrefix: storagePrefix,
                    typeConformanceProvider: typeConformanceProvider,
                    accessLevel: accessLevel
                )
            }
        )
    }

    @MemberBlockItemListBuilder
    private static func verifierFunctions(
        functionDeclarations: [FunctionDeclSyntax],
        typePrefix: String,
        storagePrefix: String,
        typeConformanceProvider: (String) -> TypeConformance,
        accessLevel: AccessLevel
    ) throws -> MemberBlockItemListSyntax {
        // Generate verifier methods for each function
        for functionDeclaration in functionDeclarations {
            let parameterList = functionDeclaration.signature.parameterClause.parameters
            let parameters = Array(parameterList)
            let allParameterSequences = AllParameterSequenceGenerator.getAllParameterSequences(
                parameters: parameters[...],
                typeConformanceProvider: typeConformanceProvider
            )

            if parameters.isEmpty {
                let functionName = functionDeclaration.name.text
                let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                let functionSignature = "\(functionName)()"

                // Function with no parameters
                try FunctionDeclSyntax(
                    """
                    \(raw: accessLevel.rawValue) func \(raw: functionName)() {
                        let invocations = self.state.mutex.withLock { storage in
                            return storage.receivedInvocations.\(raw: storagePrefix)\(raw: variablePrefix)
                        }
                        
                        if let inOrder = self.inOrder {
                            inOrder.performVerification(
                                mockIdentifier: self.state.mockIdentifier,
                                mode: self.mode,
                                matchingInvocations: invocations.map { ($0.__localCallIndex, $0.__globalCallIndex) },
                                functionName: "\(raw: storagePrefix)\(raw: functionSignature)",
                                sourceLocation: self.sourceLocation
                            )
                        } else {
                            VerificationHelper.performVerification(
                                mode: mode,
                                matchingCount: invocations.count,
                                functionName: "\(raw: storagePrefix)\(raw: functionSignature)",
                                sourceLocation: self.sourceLocation
                            )
                        }
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
                        storagePrefix: storagePrefix,
                        accessLevel: accessLevel
                    )
                }
            }
        }
    }

    private static func getParameters(
        parameterSequence: [(
            FunctionParameterSyntax, TypeConformance, AllParameterSequenceGenerator.ParameterForm
        )],
        allParametersAreMatchers: Bool
    )
        -> (methodParameters: [String], methodInterpolationParameters: [String], matcherInitializers: [String])
    {
        var methodParameters: [String] = []
        var methodInterpolationParameters: [String] = []
        var matcherInitializers: [String] = []

        for (parameter, parameterType, form) in parameterSequence {
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
            let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    "\(paramNameForSignature): \\(\(paramName).stringSpecficDescription)"
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
                let typePrefix: String
                switch parameterType {
                case .comparableAndEquatable:
                    typePrefix = ""
                case .neitherComparableNorEquatable:
                    typePrefix = "NonComparable"
                case .onlyEquatable:
                    typePrefix = "OnlyEquatable"
                }
                if isOptional {
                    methodParameters.append(
                        "\(paramNameForSignature): Optional\(typePrefix)ValueMatcher<\(paramType.dropLast())>"
                    )
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
        parameterSequence: [(
            FunctionParameterSyntax, TypeConformance, AllParameterSequenceGenerator.ParameterForm
        )],
        typePrefix: String,
        storagePrefix: String,
        accessLevel: AccessLevel
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

        let returnTypeString = captureReturnType(parameters: parameters)!
        let mapExpression = captureMapExpression(parameters: parameters)!

        // if this is not a varient with all matcher inputs
        if !allParametersAreMatchers {
            return try FunctionDeclSyntax(
                """
                @discardableResult \(raw: accessLevel.rawValue) func \(raw: functionName)(\(raw: methodSignature)) -> \(raw: returnTypeString) {
                    return \(raw: functionName)(\(raw: matcherInit))
                }
                """
            )
        }

        return try FunctionDeclSyntax(
            "@discardableResult \(raw: accessLevel.rawValue) func \(raw: functionName)(\(raw: methodSignature)) -> \(raw: returnTypeString)"
        ) {
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
                let matchingInvocations = invocations.filter { invocation in
                    matcher.matches(\(raw: matcherCall))
                }
                """
            )

            getVerificationCall(
                storagePrefix: storagePrefix,
                functionInterpolationSignature: functionInterpolationSignature
            )

            ReturnStmtSyntax(
                returnKeyword: .keyword(.return, leadingTrivia: .newline),
                expression: ExprSyntax("\(raw: mapExpression)")
            )
        }
    }

    private static func getVerificationCall(storagePrefix: String, functionInterpolationSignature: String) -> ExprSyntax
    {
        ExprSyntax(
            """
            if let inOrder = self.inOrder {
                inOrder.performVerification(
                    mockIdentifier: self.state.mockIdentifier,
                    mode: self.mode,
                    matchingInvocations: matchingInvocations.map { ($0.__localCallIndex, $0.__globalCallIndex) },
                    functionName: "\(raw: storagePrefix)\(raw: functionInterpolationSignature)",
                    sourceLocation: self.sourceLocation
                )
            } else {
                VerificationHelper.performVerification(
                    mode: mode,
                    matchingCount: matchingInvocations.count,
                    functionName: "\(raw: storagePrefix)\(raw: functionInterpolationSignature)",
                    sourceLocation: self.sourceLocation
                )
            }
            """
        )
    }
}

extension VerifierGenerator {
    fileprivate static func captureReturnType(parameters: [FunctionParameterSyntax]) -> String? {
        guard !parameters.isEmpty else { return nil }

        if parameters.count == 1 {
            let param = parameters[0]
            let type = strippedParameterType(param)
            return "[\(type)]"
        } else {
            let tupleElements = parameters.map { param in
                let name = (param.secondName ?? param.firstName).text
                let type = strippedParameterType(param)
                return "\(name): \(type)"
            }
            return "[(\(tupleElements.joined(separator: ", ")))]"
        }
    }

    fileprivate static func captureMapExpression(parameters: [FunctionParameterSyntax]) -> String? {
        guard !parameters.isEmpty else { return nil }

        if parameters.count == 1 {
            let param = parameters[0]
            let name = (param.secondName ?? param.firstName).text
            return "matchingInvocations.map { $0.\(name) }"
        } else {
            let tupleElements = parameters.map { param in
                let name = (param.secondName ?? param.firstName).text
                return "\(name): $0.\(name)"
            }
            return "matchingInvocations.map { (\(tupleElements.joined(separator: ", "))) }"
        }
    }

    fileprivate static func strippedParameterType(_ parameter: FunctionParameterSyntax) -> String {
        if let attributedType = parameter.type.as(AttributedTypeSyntax.self) {
            return attributedType.baseType.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
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
