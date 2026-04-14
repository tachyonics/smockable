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
        mockableFunctions: [MockableFunction],
        propertyDeclarations: [PropertyDeclaration] = [],
        typePrefix: String = "",
        storagePrefix: String = "",
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
                    mockableFunctions: mockableFunctions,
                    typePrefix: typePrefix,
                    storagePrefix: storagePrefix,
                    accessLevel: accessLevel
                )
            }
        )
    }

    @MemberBlockItemListBuilder
    private static func verifierFunctions(
        mockableFunctions: [MockableFunction],
        typePrefix: String,
        storagePrefix: String,
        accessLevel: AccessLevel
    ) throws -> MemberBlockItemListSyntax {
        // Generate verifier methods for each function
        for function in mockableFunctions {
            let functionDeclaration = function.declaration
            let parameterList = functionDeclaration.signature.parameterClause.parameters
            let parameters = Array(parameterList)
            let allParameterSequences = AllParameterSequenceGenerator.getAllParameterSequences(
                parameters: parameters[...],
                function: function
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
                        accessLevel: accessLevel,
                        function: function
                    )
                }
            }
        }
    }

    private static func getParameters(
        parameterSequence: [(
            FunctionParameterSyntax, TypeConformance, AllParameterSequenceGenerator.ParameterForm
        )],
        allParametersAreMatchers: Bool,
        function: MockableFunction
    )
        -> (methodParameters: [String], methodInterpolationParameters: [String], matcherInitializers: [String])
    {
        var methodParameters: [String] = []
        var methodInterpolationParameters: [String] = []
        var matcherInitializers: [String] = []

        for (parameter, parameterType, form) in parameterSequence {
            let fragments = parameterFragments(
                parameter: parameter,
                parameterType: parameterType,
                form: form,
                allParametersAreMatchers: allParametersAreMatchers,
                function: function
            )
            methodParameters.append(fragments.paramDecl)
            methodInterpolationParameters.append(fragments.interpolation)
            matcherInitializers.append(fragments.matcherInit)
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
        accessLevel: AccessLevel,
        function: MockableFunction
    ) throws -> FunctionDeclSyntax {
        let allParametersAreMatchers: Bool = parameterSequence.reduce(into: true) { partialResult, entry in
            if case .explicitMatcher = entry.2 {
                return
            }

            partialResult = false
        }

        let (methodParameters, methodInterpolationParameters, matcherInitializers) = getParameters(
            parameterSequence: parameterSequence,
            allParametersAreMatchers: allParametersAreMatchers,
            function: function
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

        let returnTypeString = captureReturnType(parameters: parameters, function: function)!
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
    /// Build the (param decl, interpolation, matcher init) fragments for a single
    /// verifier parameter, taking generic substitution into account. Lives in the
    /// extension to keep the main type body within size limits.
    fileprivate static func parameterFragments(
        parameter: FunctionParameterSyntax,
        parameterType: TypeConformance,
        form: AllParameterSequenceGenerator.ParameterForm,
        allParametersAreMatchers: Bool,
        function: MockableFunction
    ) -> (paramDecl: String, interpolation: String, matcherInit: String) {
        let names = parameterNames(parameter, allParametersAreMatchers: allParametersAreMatchers)

        // Generic parameter handling — uses NonComparableValueMatcher<existential>
        // for case 1 and ErasedValueMatcher for case 2.
        switch function.classify(parameter.type) {
        case .directGeneric(let info):
            return (
                "\(names.signature): NonComparableValueMatcher<\(info.storageType)>",
                "\(names.signature): \\(\(names.local).description)",
                "\(names.matcherPrefix)\(names.local)"
            )
        case .wrappedGeneric:
            return (
                "\(names.signature): ErasedValueMatcher",
                "\(names.signature): \\(\(names.local).description)",
                "\(names.matcherPrefix)\(names.local)"
            )
        case .concrete:
            return concreteParameterFragments(
                parameter: parameter,
                parameterType: parameterType,
                form: form,
                names: names
            )
        }
    }

    fileprivate struct ParameterNames {
        let local: String
        let signature: String
        let matcherPrefix: String
    }

    fileprivate static func parameterNames(
        _ parameter: FunctionParameterSyntax,
        allParametersAreMatchers: Bool
    ) -> ParameterNames {
        let local = parameter.secondName?.text ?? parameter.firstName.text
        let signature: String
        let call: String
        if let secondName = parameter.secondName?.text {
            signature = "\(parameter.firstName.text) \(secondName)"
            call = secondName
        } else {
            signature = parameter.firstName.text
            call = parameter.firstName.text
        }
        let matcherPrefix: String
        if parameter.firstName.text == "_" {
            // when allParametersAreMatchers != true, we will delegate to the all matchers variant
            matcherPrefix = allParametersAreMatchers ? "\(call): " : ""
        } else {
            matcherPrefix = allParametersAreMatchers ? "\(call): " : "\(parameter.firstName.text): "
        }
        return ParameterNames(local: local, signature: signature, matcherPrefix: matcherPrefix)
    }

    /// Fragment generation for non-generic parameters across the three parameter forms.
    fileprivate static func concreteParameterFragments(
        parameter: FunctionParameterSyntax,
        parameterType: TypeConformance,
        form: AllParameterSequenceGenerator.ParameterForm,
        names: ParameterNames
    ) -> (paramDecl: String, interpolation: String, matcherInit: String) {
        let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOptional = paramType.hasSuffix("?")

        let interpolation: String
        if paramType == "String" || paramType == "String?" {
            interpolation = "\(names.signature): \\(\(names.local).stringSpecficDescription)"
        } else {
            interpolation = "\(names.signature): \\(\(names.local).description)"
        }

        switch form {
        case .range:
            let baseType = isOptional ? String(paramType.dropLast()) : paramType
            return (
                "\(names.signature): ClosedRange<\(baseType)>",
                interpolation,
                "\(names.matcherPrefix).range(\(names.local))"
            )
        case .explicitMatcher:
            let matcherTypePrefix: String
            switch parameterType {
            case .comparableAndEquatable:
                matcherTypePrefix = ""
            case .neitherComparableNorEquatable:
                matcherTypePrefix = "NonComparable"
            case .onlyEquatable:
                matcherTypePrefix = "OnlyEquatable"
            }
            if isOptional {
                return (
                    "\(names.signature): Optional\(matcherTypePrefix)ValueMatcher<\(paramType.dropLast())>",
                    interpolation,
                    "\(names.matcherPrefix)\(names.local)"
                )
            } else {
                return (
                    "\(names.signature): \(matcherTypePrefix)ValueMatcher<\(paramType)>",
                    interpolation,
                    "\(names.matcherPrefix)\(names.local)"
                )
            }
        case .exact:
            return (
                "\(names.signature): \(paramType)",
                interpolation,
                "\(names.matcherPrefix).exact(\(names.local))"
            )
        }
    }

    fileprivate static func captureReturnType(
        parameters: [FunctionParameterSyntax],
        function: MockableFunction
    ) -> String? {
        guard !parameters.isEmpty else { return nil }

        if parameters.count == 1 {
            let param = parameters[0]
            let type = function.erasedTypeString(for: param.type)
            return "[\(type)]"
        } else {
            let tupleElements = parameters.map { param in
                let name = (param.secondName ?? param.firstName).text
                let type = function.erasedTypeString(for: param.type)
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
