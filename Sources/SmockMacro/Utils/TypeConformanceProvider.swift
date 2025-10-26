import Foundation
import SwiftSyntax

private let arrayStart = "Array<"
private let setStart = "Set<"
private let dictionaryStart = "Dictionary<"
private let tokenStart = "["

/// Type conformance provider that supports transitive conformance rules for collections
package enum TypeConformanceProvider {

    /// Type conformance provider that handles collections, optionals, and nested types
    package static func get(
        comparableAssociatedTypes: [String],
        equatableAssociatedTypes: [String],
        additionalComparableTypes: [TypeSyntax] = [],
        additionalEquatableTypes: [TypeSyntax] = []
    ) -> (String) -> TypeConformance {

        let builtInComparableTypes = [
            "String", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
            "Float", "Double", "Character", "Date",
        ]

        let builtInEquatableOnlyTypes = [
            "Bool", "UUID", "URL", "Data", "URLComponents",
            "CGPoint", "CGSize", "CGRect", "CGVector",
        ]

        // Convert TypeSyntax arrays to string arrays for internal processing
        let additionalComparableTypeStrings = additionalComparableTypes.map {
            $0.description.trimmingCharacters(in: .whitespaces)
        }
        let additionalEquatableTypeStrings = additionalEquatableTypes.map {
            $0.description.trimmingCharacters(in: .whitespaces)
        }

        let comparableTypes = Set(comparableAssociatedTypes + builtInComparableTypes + additionalComparableTypeStrings)
        let equatableTypes = Set(equatableAssociatedTypes + builtInEquatableOnlyTypes + additionalEquatableTypeStrings)

        return { baseType in
            return determineTypeConformance(
                baseType: baseType,
                comparableTypes: comparableTypes,
                equatableTypes: equatableTypes
            )
        }
    }

    private enum StackElements {
        case arrayStart
        case setStart
        case dictionaryStart
        case tokenStart
        case confirmedConformance(TypeConformance)

        func isDictionaryStartToken(canBeLiteralToken: Bool) -> Bool {
            switch self {
            case .dictionaryStart:
                return true
            case .tokenStart:
                return canBeLiteralToken
            case .confirmedConformance, .setStart, .arrayStart:
                return false
            }
        }
    }

    /// Recursively determine type conformance for complex types including collections
    private static func determineTypeConformance(
        baseType: String,
        comparableTypes: Set<String>,
        equatableTypes: Set<String>
    ) -> TypeConformance {
        func getConformance(currentType: String) -> TypeConformance {
            if comparableTypes.contains(currentType) {
                return .comparableAndEquatable
            } else if equatableTypes.contains(currentType) {
                return .onlyEquatable
            }

            return .neitherComparableNorEquatable
        }

        var remainingInput = baseType[...]
        var startOfToken = true
        var stack: [StackElements] = []
        var currentToken = ""

        while let first = remainingInput.first {
            // If the is potentially the start of a token, check if it is one
            if handleTokenStart(stack: &stack, startOfToken: startOfToken, remainingInput: &remainingInput) {
                continue
            }

            // if this is an end token of some kind
            let isEndToken = first == "]"
            let isSeperatorToken = first == ":"
            if first == ">" || isEndToken {
                handleEndToken(
                    baseType: baseType,
                    isEndToken: isEndToken,
                    stack: &stack,
                    currentToken: &currentToken,
                    getConformance: getConformance
                )

                remainingInput = remainingInput.dropFirst()
                currentToken = ""
                startOfToken = true
                continue
                // if the element is a dictionary seperator
            } else if first == "," || first == ":" {
                // this a part of a dictionary
                if let secondLastElement = stack.last,
                    secondLastElement.isDictionaryStartToken(canBeLiteralToken: isSeperatorToken)
                {
                    if !currentToken.isEmpty {
                        let typeConformance = getConformance(currentType: currentToken)
                        stack.append(.confirmedConformance(typeConformance))
                    } else {
                        fatalError("Unable to parse type \(baseType)")
                    }
                }
                remainingInput = remainingInput.dropFirst()
                currentToken = ""
                startOfToken = true
                continue
            }

            // T? has same conformance as T and so can be ignored
            if first != " " && first != "?" {
                currentToken.append(first)
                startOfToken = false
            }

            remainingInput = remainingInput.dropFirst()
        }

        // if the type is not a top level collection
        if stack.count == 0 && !currentToken.isEmpty {
            return getConformance(currentType: currentToken)
            // if the type
        } else if case let .confirmedConformance(conformance) = stack.popLast(), stack.isEmpty {
            return conformance
        }

        fatalError("Unable to parse type \(baseType)")
    }

    private static func handleTokenStart(
        stack: inout [StackElements],
        startOfToken: Bool,
        remainingInput: inout Substring
    ) -> Bool {
        if startOfToken {
            if remainingInput.hasPrefix(arrayStart) {
                stack.append(.arrayStart)
                remainingInput = remainingInput.dropFirst(arrayStart.count)
                return true
            } else if remainingInput.hasPrefix(setStart) {
                stack.append(.setStart)
                remainingInput = remainingInput.dropFirst(setStart.count)
                return true
            } else if remainingInput.hasPrefix(dictionaryStart) {
                stack.append(.dictionaryStart)
                remainingInput = remainingInput.dropFirst(dictionaryStart.count)
                return true
            } else if remainingInput.hasPrefix(tokenStart) {
                stack.append(.tokenStart)
                remainingInput = remainingInput.dropFirst(tokenStart.count)
                return true

            }
        }

        return false
    }

    private static func handleEndToken(
        baseType: String,
        isEndToken: Bool,
        stack: inout [StackElements],
        currentToken: inout String,
        getConformance: (String) -> TypeConformance
    ) {
        // get the last element on the stack
        if let lastElement = stack.popLast() {
            let typeConformance: TypeConformance
            let adjustedLastElement: StackElements
            // if the last type of this collection is not itself a collection
            // this type will come from the cbuilt current token
            if !currentToken.isEmpty {
                typeConformance = getConformance(currentToken)
                adjustedLastElement = lastElement
                // otherwise if the last type of this collection is a collection itself,
                // it will be on the stack. Get this conformance and pop another element off
                // the stack
            } else if case let .confirmedConformance(lastTypeConformance) = lastElement {
                typeConformance = lastTypeConformance
                guard let secondLastElement = stack.popLast() else {
                    fatalError("Unable to parse type \(baseType)")
                }
                adjustedLastElement = secondLastElement
            } else {
                fatalError("Unable to parse type \(baseType)")
            }

            switch adjustedLastElement {
            // if the element starting this collection is a set or array
            case .setStart, .arrayStart, .tokenStart:
                let collectionConformance = getArrayOrSetConformance(elementConformance: typeConformance)
                stack.append(.confirmedConformance(collectionConformance))
            // otherwise if it is another confirmed conformance, potentially the key type for a dictionary
            case .confirmedConformance(let possibleKeyConformance):
                if let secondLastElement = stack.last,
                    secondLastElement.isDictionaryStartToken(canBeLiteralToken: isEndToken)
                {
                    _ = stack.popLast()
                    let collectionConformance = getDictionaryConformance(
                        keyConformance: possibleKeyConformance,
                        valueConformance: typeConformance
                    )
                    stack.append(.confirmedConformance(collectionConformance))
                }
            // a dictionary must have two types (key and value) so is not a valid element here
            case .dictionaryStart:
                fatalError("Unable to parse type \(baseType)")
            }

        } else {
            fatalError("Unable to parse type \(baseType)")
        }
    }

    /// Helper method to determine array  or set conformance
    private static func getArrayOrSetConformance(
        elementConformance: TypeConformance
    ) -> TypeConformance {
        // Arrays are Equatable if elements are Equatable
        switch elementConformance {
        case .comparableAndEquatable, .onlyEquatable:
            return .onlyEquatable
        case .neitherComparableNorEquatable:
            return .neitherComparableNorEquatable
        }
    }

    /// Helper method to determine dictionary conformance
    private static func getDictionaryConformance(
        keyConformance: TypeConformance,
        valueConformance: TypeConformance
    ) -> TypeConformance {
        // Dictionaries are Equatable if both key and value are at least Equatable
        if (keyConformance == .comparableAndEquatable || keyConformance == .onlyEquatable)
            && (valueConformance == .comparableAndEquatable || valueConformance == .onlyEquatable)
        {
            return .onlyEquatable
        } else {
            return .neitherComparableNorEquatable
        }
    }
}
