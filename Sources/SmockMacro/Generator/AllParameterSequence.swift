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
//  AllParameterSequence.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum AllParameterSequenceGenerator {
    enum ParameterForm: CaseIterable {
        case explicitMatcher
        case range
        case exact
    }

    static func getAllParameterSequences(
        parameters: ArraySlice<FunctionParameterSyntax>,
        typeConformanceProvider: (String) -> TypeConformance
    ) -> [[(FunctionParameterSyntax, TypeConformance, ParameterForm)]] {
        if let firstParameter = parameters.first {
            let firstParamType = firstParameter.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let firstIsOptional = firstParamType.hasSuffix("?")
            let firstBaseType = (firstIsOptional ? String(firstParamType.dropLast()) : firstParamType)
            let firstTypeConformance = typeConformanceProvider(firstBaseType)

            if parameters.count == 1 {
                switch firstTypeConformance {
                case .onlyEquatable:
                    return [
                        [(firstParameter, .onlyEquatable, .explicitMatcher)],
                        [(firstParameter, .onlyEquatable, .exact)],
                    ]
                case .neitherComparableNorEquatable:
                    // only have the explicitMatcher form for this parameter
                    return [[(firstParameter, .neitherComparableNorEquatable, .explicitMatcher)]]
                case .comparableAndEquatable:
                    // when there is only one parameter
                    return ParameterForm.allCases.map { parameterForm in
                        // parameter combination for each form
                        return [(firstParameter, .comparableAndEquatable, parameterForm)]
                    }
                }
            }

            // otherwise get the combinations for the parameters array minus the first element
            let dropFirstParameterSequences = getAllParameterSequences(
                parameters: parameters.dropFirst(),
                typeConformanceProvider: typeConformanceProvider
            )

            // iterate through the remaining cases
            return dropFirstParameterSequences.flatMap { partialParameterSequence in
                switch firstTypeConformance {
                case .onlyEquatable:
                    return [
                        [(firstParameter, .onlyEquatable, .explicitMatcher)] + partialParameterSequence,
                        [(firstParameter, .onlyEquatable, .exact)] + partialParameterSequence,
                    ]
                case .neitherComparableNorEquatable:
                    // only have the explicitMatcher form for this parameter
                    return [
                        [(firstParameter, .neitherComparableNorEquatable, ParameterForm.explicitMatcher)]
                            + partialParameterSequence
                    ]
                case .comparableAndEquatable:
                    // when there is only one parameter
                    return ParameterForm.allCases.map { parameterForm in
                        // parameter combination for each type
                        return [(firstParameter, .comparableAndEquatable, parameterForm)] + partialParameterSequence
                    }
                }
            }
        } else {
            // terminating case
            return []
        }
    }

    static func generateMatcherCall(parameters: [FunctionParameterSyntax], prefix: String = "") -> String {
        return parameters.map { parameter in
            let paramName = parameter.secondName?.text ?? parameter.firstName.text
            let firstName = parameter.firstName.text
            return "\(firstName): \(prefix)\(paramName)"
        }.joined(separator: ", ")
    }
}
