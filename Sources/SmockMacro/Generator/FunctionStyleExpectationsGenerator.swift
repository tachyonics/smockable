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
//  FunctionStyleExpectationsGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionStyleExpectationsGenerator {
    /// Generate function-style expectation methods for a given function declaration
    static func generateExpectationMethods(
        for functionDeclaration: FunctionDeclSyntax,
        typePrefix: String,
        accessLevel: AccessLevel,
        typeConformanceProvider: (String) -> TypeConformance
    ) throws -> [FunctionDeclSyntax] {
        let parameterList = functionDeclaration.signature.parameterClause.parameters
        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let expectationClassName = "\(typePrefix)\(variablePrefix.capitalizingComponentsFirstLetter())_FieldOptions"

        // If function has no parameters, generate a simple method
        if parameterList.isEmpty {
            return [
                try generateNoParameterMethod(
                    functionName: functionDeclaration.name.text,
                    expectationClassName: expectationClassName,
                    variablePrefix: variablePrefix,
                    accessLevel: accessLevel
                )
            ]
        }

        let genericContext = GenericContext(
            functionDeclaration: functionDeclaration,
            typeConformanceProvider: typeConformanceProvider
        )

        // Generate all overload combinations for functions with parameters
        return try generateOverloadCombinations(
            functionDeclaration: functionDeclaration,
            parameterList: parameterList,
            expectationClassName: expectationClassName,
            typePrefix: typePrefix,
            variablePrefix: variablePrefix,
            accessLevel: accessLevel,
            typeConformanceProvider: typeConformanceProvider,
            genericContext: genericContext
        )
    }

    /// Generate method for functions with no parameters
    private static func generateNoParameterMethod(
        functionName: String,
        expectationClassName: String,
        variablePrefix: String,
        accessLevel: AccessLevel
    ) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax(
            """
            \(raw: accessLevel.rawValue) mutating func \(raw: functionName)() -> \(raw: expectationClassName) {
                let matcher = AlwaysMatcher()
                let fieldOptions = \(raw: expectationClassName)()
                _\(raw: variablePrefix).append((fieldOptions, matcher))
                return fieldOptions
            }
            """
        )
    }

    /// Generate all overload combinations for functions with parameters
    private static func generateOverloadCombinations(
        //functionName: String,
        functionDeclaration: FunctionDeclSyntax,
        parameterList: FunctionParameterListSyntax,
        expectationClassName: String,
        typePrefix: String,
        variablePrefix: String,
        accessLevel: AccessLevel,
        typeConformanceProvider: (String) -> TypeConformance,
        genericContext: GenericContext
    ) throws -> [FunctionDeclSyntax] {
        let parameters = Array(parameterList)
        let allParameterSequences = AllParameterSequenceGenerator.getAllParameterSequences(
            parameters: parameters[...],
            typeConformanceProvider: typeConformanceProvider,
            genericContext: genericContext
        )

        var methods: [FunctionDeclSyntax] = []

        // Generate all combinations where each parameter can be either explicit matcher or range
        for parameterSequence in allParameterSequences {
            let method = try generateMethodForCombination(
                functionDeclaration: functionDeclaration,
                parameterSequence: parameterSequence,
                expectationClassName: expectationClassName,
                typePrefix: typePrefix,
                variablePrefix: variablePrefix,
                accessLevel: accessLevel,
                genericContext: genericContext
            )
            methods.append(method)
        }

        return methods
    }

    /// Generate the (parameter declaration, matcher initializer) for a single parameter
    /// in an expectation setter, given its conformance and parameter form. Generic
    /// parameters take precedence and are handled with the existential / `AnyValueMatcher`
    /// substitution.
    private static func parameterFragments(
        parameter: FunctionParameterSyntax,
        parameterType: TypeConformance,
        form: AllParameterSequenceGenerator.ParameterForm,
        genericContext: GenericContext
    ) -> (paramDecl: String, matcherInit: String) {
        let paramName = parameter.secondName?.text ?? parameter.firstName.text
        let paramNameForSignature: String
        if let secondName = parameter.secondName?.text {
            paramNameForSignature = "\(parameter.firstName.text) \(secondName)"
        } else {
            paramNameForSignature = parameter.firstName.text
        }
        let paramType = parameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let isOptional = paramType.hasSuffix("?")

        // Generic parameter handling — uses NonComparableValueMatcher<existential>
        // for case 1 and AnyValueMatcher for case 2.
        switch genericContext.classify(parameter.type) {
        case .directGeneric(let info):
            return (
                "\(paramNameForSignature): NonComparableValueMatcher<\(info.storageType)>",
                "\(paramName): \(paramName)"
            )
        case .wrappedGeneric:
            return (
                "\(paramNameForSignature): AnyValueMatcher",
                "\(paramName): \(paramName)"
            )
        case .concrete:
            break
        }

        switch form {
        case .range:
            let baseType = isOptional ? String(paramType.dropLast()) : paramType
            return (
                "\(paramNameForSignature): ClosedRange<\(baseType)>",
                "\(paramName): .range(\(paramName))"
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
                    "\(paramNameForSignature): Optional\(matcherTypePrefix)ValueMatcher<\(paramType.dropLast())>",
                    "\(paramName): \(paramName)"
                )
            } else {
                return (
                    "\(paramNameForSignature): \(matcherTypePrefix)ValueMatcher<\(paramType)>",
                    "\(paramName): \(paramName)"
                )
            }
        case .exact:
            return (
                "\(paramNameForSignature): \(paramType)",
                "\(paramName): .exact(\(paramName))"
            )
        }
    }

    /// Generate a specific method for a parameter type combination
    private static func generateMethodForCombination(
        functionDeclaration: FunctionDeclSyntax,
        parameterSequence: [(
            FunctionParameterSyntax, TypeConformance, AllParameterSequenceGenerator.ParameterForm
        )],
        expectationClassName: String,
        typePrefix: String,
        variablePrefix: String,
        accessLevel: AccessLevel,
        genericContext: GenericContext
    ) throws -> FunctionDeclSyntax {
        var methodParameters: [String] = []
        var matcherInitializers: [String] = []

        for (parameter, parameterType, form) in parameterSequence {
            let fragments = parameterFragments(
                parameter: parameter,
                parameterType: parameterType,
                form: form,
                genericContext: genericContext
            )
            methodParameters.append(fragments.paramDecl)
            matcherInitializers.append(fragments.matcherInit)
        }

        let methodSignature = methodParameters.joined(separator: ", ")
        let matcherInit = matcherInitializers.joined(separator: ", ")
        let inputMatcherType = "\(typePrefix)\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let functionName = functionDeclaration.name.text

        return try FunctionDeclSyntax(
            """
            \(raw: accessLevel.rawValue) mutating func \(raw: functionName)(\(raw: methodSignature)) -> \(raw: expectationClassName) {
                let matcher = \(raw: inputMatcherType)(\(raw: matcherInit))
                let fieldOptions = \(raw: expectationClassName)()
                _\(raw: variablePrefix).append((fieldOptions, matcher))
                return fieldOptions
            }
            """
        )
    }
}
