//
//  AllParameterSequence.swift
//  smockable
//

import SwiftSyntax
import SwiftSyntaxBuilder

enum AllParameterSequenceGenerator {
    public enum ParameterForm: CaseIterable {
        case explicitMatcher
        case range
        case exact
    }

    public static func getAllParameterSequences(
        parameters: ArraySlice<FunctionParameterSyntax>,
        isComparableProvider: (String) -> Bool
    ) -> [[(FunctionParameterSyntax, Bool, ParameterForm)]] {
        if let firstParameter = parameters.first {
            let firstParamType = firstParameter.type.description
            let firstIsOptional = firstParamType.hasSuffix("?")
            let firstBaseType = (firstIsOptional ? String(firstParamType.dropLast()) : firstParamType).trimmingCharacters(in: .whitespacesAndNewlines)
            let firstIsComparable = isComparableProvider(firstBaseType)

            if parameters.count == 1 {
                if !firstIsComparable {
                    // only have the explicitMatcher form for this parameter
                    return [[(firstParameter, false, ParameterForm.explicitMatcher)]]
                } else {
                    // when there is only one parameter
                    return ParameterForm.allCases.map { parameterForm in
                        // parameter combination for each form
                        return [(firstParameter, true, parameterForm)]
                    }
                }
            }

            // otherwise get the combinations for the parameters array minus the first element
            let dropFirstParameterSequences = getAllParameterSequences(
                parameters: parameters.dropFirst(),
                isComparableProvider: isComparableProvider
            )

            // iterate through the remaining cases
            return dropFirstParameterSequences.flatMap { partialParameterSequence in
                if !firstIsComparable {
                    // only have the explicitMatcher form for this parameter
                    return [[(firstParameter, false, ParameterForm.explicitMatcher)] + partialParameterSequence]
                } else {
                    // when there is only one parameter
                    return ParameterForm.allCases.map { parameterForm in
                        // parameter combination for each type
                        return [(firstParameter, true, parameterForm)] + partialParameterSequence
                    }
                }
            }
        } else {
            // terminating case
            return []
        }
    }

    public static func generateMatcherCall(parameters: [FunctionParameterSyntax], prefix: String = "") -> String {
        return parameters.map { parameter in
            let paramName = parameter.secondName?.text ?? parameter.firstName.text
            let firstName = parameter.firstName.text
            return "\(firstName): \(prefix)\(paramName)"
        }.joined(separator: ", ")
    }
}
