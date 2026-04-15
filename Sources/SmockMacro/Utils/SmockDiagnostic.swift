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
//  SmockDiagnostic.swift
//  SmockMacro
//

import SwiftDiagnostics
import SwiftSyntax

/// Diagnostic messages emitted by the `@Smock` macro during expansion.
package enum SmockDiagnostic: DiagnosticMessage, Error {
    case onlyApplicableToProtocol
    case variableDeclInProtocolWithNotSingleBinding
    case variableDeclInProtocolWithNotIdentifierPattern
    case invalidMacroArguments
    case unknownMacroParameter
    case invalidAccessLevel
    case invalidPreprocessorFlag
    case genericParameterMissingSendable(parameterName: String, functionName: String)
    case missingArgumentLabel
    case typeArrayExpected(parameterName: String)
    case invalidTypeArrayElement(parameterName: String, element: String)
    case unparseableTypeString(typeString: String)

    package var message: String {
        switch self {
        case .onlyApplicableToProtocol:
            "'@Smock' can only be applied to a 'protocol'"
        case .variableDeclInProtocolWithNotSingleBinding:
            "Variable declaration in a 'protocol' with the '@Smock' attribute must have exactly one binding"
        case .variableDeclInProtocolWithNotIdentifierPattern:
            "Variable declaration in a 'protocol' with the '@Smock' attribute must have identifier pattern"
        case .invalidMacroArguments:
            "Invalid arguments provided to '@Smock' macro"
        case .unknownMacroParameter:
            "Unknown parameter provided to '@Smock' macro. Valid parameters are: accessLevel, preprocessorFlag, additionalComparableTypes, additionalEquatableTypes"
        case .invalidAccessLevel:
            "Invalid access level. Valid values are: .public, .package, .internal, .fileprivate, .private"
        case .invalidPreprocessorFlag:
            "Preprocessor flag must be a string literal"
        case .genericParameterMissingSendable(let parameterName, let functionName):
            "Generic parameter '\(parameterName)' on '\(functionName)' must include 'Sendable' in its constraints. Mock state lives behind a Mutex and requires all stored types to be Sendable."
        case .missingArgumentLabel:
            "All arguments to '@Smock' must use labeled syntax (e.g. accessLevel: .public)"
        case .typeArrayExpected(let parameterName):
            "'\(parameterName)' expects an array of types (e.g. [\(parameterName == "additionalComparableTypes" ? "MyType.self, OtherType.self" : "MyType.self")])"
        case .invalidTypeArrayElement(let parameterName, let element):
            "Invalid element '\(element)' in '\(parameterName)'. Each element must be a type reference (e.g. MyType.self or Module.MyType.self)"
        case .unparseableTypeString(let typeString):
            "Could not determine conformance for '\(typeString)'. Convenience overloads (shorthand exact and range matching) will not be generated for parameters of this type."
        }
    }

    package var severity: DiagnosticSeverity {
        switch self {
        case .unparseableTypeString:
            .warning
        default:
            .error
        }
    }

    package var diagnosticID: MessageID {
        let id: String
        switch self {
        case .onlyApplicableToProtocol: id = "onlyApplicableToProtocol"
        case .variableDeclInProtocolWithNotSingleBinding: id = "variableDeclInProtocolWithNotSingleBinding"
        case .variableDeclInProtocolWithNotIdentifierPattern: id = "variableDeclInProtocolWithNotIdentifierPattern"
        case .invalidMacroArguments: id = "invalidMacroArguments"
        case .unknownMacroParameter: id = "unknownMacroParameter"
        case .invalidAccessLevel: id = "invalidAccessLevel"
        case .invalidPreprocessorFlag: id = "invalidPreprocessorFlag"
        case .genericParameterMissingSendable: id = "genericParameterMissingSendable"
        case .missingArgumentLabel: id = "missingArgumentLabel"
        case .typeArrayExpected: id = "typeArrayExpected"
        case .invalidTypeArrayElement: id = "invalidTypeArrayElement"
        case .unparseableTypeString: id = "unparseableTypeString"
        }
        return MessageID(domain: "SmockMacro", id: id)
    }

    /// Creates a `Diagnostic` suitable for `MacroExpansionContext.diagnose()`.
    /// Uses an empty syntax node since the warning applies to the macro as a
    /// whole rather than a specific source location.
    package var asDiagnostic: Diagnostic {
        Diagnostic(node: TokenSyntax(.unknown(""), presence: .missing), message: self)
    }
}
