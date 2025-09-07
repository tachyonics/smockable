import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionStyleExpectationsGenerator {
    /// Generate function-style expectation methods for a given function declaration
    static func generateExpectationMethods(
        for functionDeclaration: FunctionDeclSyntax,
        isComparableProvider: (String) -> Bool
    ) throws -> [FunctionDeclSyntax] {
        let parameterList = functionDeclaration.signature.parameterClause.parameters
        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let expectationClassName = "\(variablePrefix.capitalizingComponentsFirstLetter())_FieldOptions"

        // If function has no parameters, generate a simple method
        if parameterList.isEmpty {
            return [
                try generateNoParameterMethod(
                    functionName: functionDeclaration.name.text,
                    expectationClassName: expectationClassName,
                    variablePrefix: variablePrefix
                )
            ]
        }

        // Generate all overload combinations for functions with parameters
        return try generateOverloadCombinations(
            functionDeclaration: functionDeclaration,
            parameterList: parameterList,
            expectationClassName: expectationClassName,
            variablePrefix: variablePrefix,
            isComparableProvider: isComparableProvider
        )
    }

    /// Generate method for functions with no parameters
    private static func generateNoParameterMethod(
        functionName: String,
        expectationClassName: String,
        variablePrefix: String
    ) throws -> FunctionDeclSyntax {
        return try FunctionDeclSyntax(
            """
            public mutating func \(raw: functionName)() -> \(raw: expectationClassName) {
                let matcher = AlwaysMatcher()
                let fieldOptions = \(raw: expectationClassName)()
                _\(raw: variablePrefix).append((fieldOptions, matcher))
                return fieldOptions
            }
            """
        )
    }
    
    private enum ParameterForm: CaseIterable {
        case explicitMatcher
        case range
        case exact
    }
    
    private static func getAllParameterSequences(parameters: ArraySlice<FunctionParameterSyntax>,
                                                 isComparableProvider: (String) -> Bool) -> [[(FunctionParameterSyntax, Bool, ParameterForm)]] {
        if let firstParameter = parameters.first {
            let firstParamType = firstParameter.type.description
            let firstIsOptional = firstParamType.hasSuffix("?")
            let firstBaseType = firstIsOptional ? String(firstParamType.dropLast()) : firstParamType
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
            let dropFirstParameterSequences = getAllParameterSequences(parameters: parameters.dropFirst(), isComparableProvider: isComparableProvider)
            
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

    /// Generate all overload combinations for functions with parameters
    private static func generateOverloadCombinations(
        //functionName: String,
        functionDeclaration: FunctionDeclSyntax,
        parameterList: FunctionParameterListSyntax,
        expectationClassName: String,
        variablePrefix: String,
        isComparableProvider: (String) -> Bool
    ) throws -> [FunctionDeclSyntax] {
        let parameters = Array(parameterList)
        let allParameterSequences = getAllParameterSequences(parameters: parameters[...], isComparableProvider: isComparableProvider)
        
        var methods: [FunctionDeclSyntax] = []

        // Generate all combinations where each parameter can be either explicit matcher or range
        for parameterSequence in allParameterSequences {
            let method = try generateMethodForCombination(
                functionDeclaration: functionDeclaration,
                parameterSequence: parameterSequence,
                expectationClassName: expectationClassName,
                variablePrefix: variablePrefix
            )
            methods.append(method)
        }

        return methods
    }

    /// Generate a specific method for a parameter type combination
    private static func generateMethodForCombination(
        functionDeclaration: FunctionDeclSyntax,
        parameterSequence: [(FunctionParameterSyntax, Bool, ParameterForm)],
        expectationClassName: String,
        variablePrefix: String
    ) throws -> FunctionDeclSyntax {
        var methodParameters: [String] = []
        var matcherInitializers: [String] = []

        for (parameter, isComparable, form) in parameterSequence {
            let paramName = parameter.secondName?.text ?? parameter.firstName.text
            let paramNameForSignature: String
            if let secondName = parameter.secondName?.text {
                paramNameForSignature = "\(parameter.firstName.text) \(secondName)"
            } else {
                paramNameForSignature = parameter.firstName.text
            }
            let paramType = parameter.type.description
            let isOptional = paramType.hasSuffix("?")
            
            switch form {
            case .range:
                if isOptional {
                    let baseType = String(paramType.dropLast())  // Remove '?'
                    methodParameters.append("\(paramNameForSignature): ClosedRange<\(baseType)>")
                    matcherInitializers.append("\(paramName): .range(\(paramName))")
                } else {
                    methodParameters.append("\(paramNameForSignature): ClosedRange<\(paramType)>")
                    matcherInitializers.append("\(paramName): .range(\(paramName))")
                }
            case .explicitMatcher:
                let typePrefix = isComparable ? "" : "NonComparable"
                if isOptional {
                    let baseType = String(paramType.dropLast())  // Remove '?'
                    methodParameters.append("\(paramNameForSignature): Optional\(typePrefix)ValueMatcher<\(baseType)>")
                    matcherInitializers.append("\(paramName): \(paramName)")
                } else {
                    methodParameters.append("\(paramNameForSignature): \(typePrefix)ValueMatcher<\(paramType)>")
                    matcherInitializers.append("\(paramName): \(paramName)")
                }
            case .exact:
                methodParameters.append("\(paramNameForSignature): \(paramType)")
                matcherInitializers.append("\(paramName): .exact(\(paramName))")
            }
        }

        let methodSignature = methodParameters.joined(separator: ", ")
        let matcherInit = matcherInitializers.joined(separator: ", ")
        let inputMatcherType = "\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher"
        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let functionName = functionDeclaration.name.text

        return try FunctionDeclSyntax(
            """
            public mutating func \(raw: functionName)(\(raw: methodSignature)) -> \(raw: expectationClassName) {
                let matcher = \(raw: inputMatcherType)(\(raw: matcherInit))
                let fieldOptions = \(raw: expectationClassName)()
                _\(raw: variablePrefix).append((fieldOptions, matcher))
                return fieldOptions
            }
            """
        )
    }
}
