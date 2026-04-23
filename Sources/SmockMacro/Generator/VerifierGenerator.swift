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
        -> (methodParameters: [String], matcherInitializers: [String])
    {
        var methodParameters: [String] = []
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
            matcherInitializers.append(fragments.matcherInit)
        }

        return (methodParameters, matcherInitializers)
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

        let (methodParameters, matcherInitializers) = getParameters(
            parameterSequence: parameterSequence,
            allParametersAreMatchers: allParametersAreMatchers,
            function: function
        )

        let methodSignature = methodParameters.joined(separator: ", ")
        let matcherInit = matcherInitializers.joined(separator: ", ")

        let parameterList = functionDeclaration.signature.parameterClause.parameters
        let parameters = Array(parameterList)
        let matcherCall = AllParameterSequenceGenerator.generateMatcherCall(
            parameters: parameters,
            prefix: "invocation."
        )

        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let inputMatcherType = "\(typePrefix)\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
        let functionName = functionDeclaration.name.text

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

        // Interpolation is only consumed by the verification-message path below,
        // which runs only when every parameter is an explicit matcher. Computing
        // it here (rather than alongside the paramDecl/matcherInit fragments)
        // keeps `parameterFragments` honest: callers that don't reach this branch
        // never see a bogus interpolation field.
        let methodInterpolation = parameterSequence.map { parameter, _, _ in
            interpolationFragment(
                parameter: parameter,
                allParametersAreMatchers: allParametersAreMatchers,
                function: function
            )
        }
        .joined(separator: ", ")
        let functionInterpolationSignature = "\(functionName)(\(methodInterpolation))"

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
    /// Build the (param decl, matcher init) fragments for a single verifier
    /// parameter, taking generic substitution into account. Lives in the
    /// extension to keep the main type body within size limits.
    ///
    /// Interpolation is computed separately by ``interpolationFragment(parameter:allParametersAreMatchers:function:)``
    /// and only on the code path that actually emits a verification-message string
    /// (the all-matchers body). Keeping it out of this tuple prevents shim-path
    /// callers from having to invent a placeholder that would never compile against
    /// their parameter types.
    fileprivate static func parameterFragments(
        parameter: FunctionParameterSyntax,
        parameterType: TypeConformance,
        form: AllParameterSequenceGenerator.ParameterForm,
        allParametersAreMatchers: Bool,
        function: MockableFunction
    ) -> (paramDecl: String, matcherInit: String) {
        let names = parameterNames(parameter, allParametersAreMatchers: allParametersAreMatchers)

        switch function.classify(parameter.type) {
        case .directGeneric(let info):
            if case .exact = form {
                // Constraint body without the leading `any ` — e.g.
                // `any Equatable & Sendable` becomes `Equatable & Sendable`.
                let constraintBody =
                    info.storageType.hasPrefix("any ")
                    ? String(info.storageType.dropFirst(4)) : info.storageType
                return (
                    "\(names.signature): some \(constraintBody)",
                    "\(names.matcherPrefix).exactAs(\(names.local))"
                )
            }
            return (
                "\(names.signature): ExistentialValueMatcher<\(info.storageType)>",
                "\(names.matcherPrefix)\(names.local)"
            )
        case .wrappedGeneric:
            return (
                "\(names.signature): ExistentialValueMatcher<any Sendable>",
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

    /// Build the verification-message interpolation fragment for a single
    /// parameter. Only called on the all-matchers code path, where every
    /// `names.local` refers to a matcher value whose `.description` /
    /// `.stringSpecficDescription` is guaranteed to exist.
    fileprivate static func interpolationFragment(
        parameter: FunctionParameterSyntax,
        allParametersAreMatchers: Bool,
        function: MockableFunction
    ) -> String {
        let names = parameterNames(parameter, allParametersAreMatchers: allParametersAreMatchers)
        switch function.classify(parameter.type) {
        case .concrete:
            let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if paramType == "String" || paramType == "String?" {
                return "\(names.signature): \\(\(names.local).stringSpecficDescription)"
            }
            return "\(names.signature): \\(\(names.local).description)"
        case .directGeneric, .wrappedGeneric:
            return "\(names.signature): \\(\(names.local).description)"
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
    ) -> (paramDecl: String, matcherInit: String) {
        let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOptional = paramType.hasSuffix("?")

        switch form {
        case .range:
            let baseType = isOptional ? String(paramType.dropLast()) : paramType
            return (
                "\(names.signature): ClosedRange<\(baseType)>",
                "\(names.matcherPrefix).range(\(names.local))"
            )
        case .explicitMatcher:
            return (
                "\(names.signature): ValueMatcher<\(paramType)>",
                "\(names.matcherPrefix)\(names.local)"
            )
        case .exact:
            return (
                "\(names.signature): \(paramType)",
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
