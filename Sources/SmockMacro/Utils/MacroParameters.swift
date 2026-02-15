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
//  MacroParameters.swift
//  SmockMacro
//

import SwiftSyntax

/// Represents the parameters that can be passed to the @Smock macro
package struct MacroParameters {
    package let accessLevel: AccessLevel
    package let preprocessorFlag: String?
    package let additionalComparableTypes: [TypeSyntax]
    package let additionalEquatableTypes: [TypeSyntax]

    package init(
        accessLevel: AccessLevel,
        preprocessorFlag: String?,
        additionalComparableTypes: [TypeSyntax],
        additionalEquatableTypes: [TypeSyntax]
    ) {
        self.accessLevel = accessLevel
        self.preprocessorFlag = preprocessorFlag
        self.additionalComparableTypes = additionalComparableTypes
        self.additionalEquatableTypes = additionalEquatableTypes
    }

    /// Default parameters for the macro
    package static let `default` = MacroParameters(
        accessLevel: .default,
        preprocessorFlag: nil,
        additionalComparableTypes: [],
        additionalEquatableTypes: []
    )
}

/// Utility for parsing macro parameters from AttributeSyntax
package enum MacroParameterParser {

    /// Parses macro parameters from the attribute syntax
    /// - Parameter attribute: The @Smock attribute syntax
    /// - Returns: Parsed parameters or default if no parameters provided
    /// - Throws: SmockDiagnostic if parameters are invalid
    package static func parse(from attribute: AttributeSyntax) throws -> MacroParameters {
        // If no arguments provided, return defaults
        guard let arguments = attribute.arguments else {
            return .default
        }

        guard case .argumentList(let argumentList) = arguments else {
            throw SmockDiagnostic.invalidMacroArguments
        }

        var accessLevel: AccessLevel = .default
        var preprocessorFlag: String? = nil
        var additionalComparableTypes: [TypeSyntax] = []
        var additionalEquatableTypes: [TypeSyntax] = []

        for argument in argumentList {
            guard let label = argument.label?.text else {
                throw SmockDiagnostic.invalidMacroArguments
            }

            switch label {
            case "accessLevel":
                accessLevel = try parseAccessLevel(from: argument.expression)
            case "preprocessorFlag":
                preprocessorFlag = try parsePreprocessorFlag(from: argument.expression)
            case "additionalComparableTypes":
                additionalComparableTypes = try parseTypeArray(from: argument.expression)
            case "additionalEquatableTypes":
                additionalEquatableTypes = try parseTypeArray(from: argument.expression)
            default:
                throw SmockDiagnostic.unknownMacroParameter
            }
        }

        return MacroParameters(
            accessLevel: accessLevel,
            preprocessorFlag: preprocessorFlag,
            additionalComparableTypes: additionalComparableTypes,
            additionalEquatableTypes: additionalEquatableTypes
        )
    }

    /// Parses access level from expression syntax
    private static func parseAccessLevel(from expression: ExprSyntax) throws -> AccessLevel {
        // Handle member access like .public, .internal, etc.
        if let memberAccess = expression.as(MemberAccessExprSyntax.self),
            memberAccess.base == nil,
            let accessLevel = AccessLevel(rawValue: memberAccess.declName.baseName.text)
        {
            return accessLevel
        }

        // Handle direct identifier like public, internal, etc.
        if let identifier = expression.as(DeclReferenceExprSyntax.self),
            let accessLevel = AccessLevel(rawValue: identifier.baseName.text)
        {
            return accessLevel
        }

        throw SmockDiagnostic.invalidAccessLevel
    }

    /// Parses preprocessor flag from expression syntax
    private static func parsePreprocessorFlag(from expression: ExprSyntax) throws -> String {
        if let stringLiteral = expression.as(StringLiteralExprSyntax.self),
            stringLiteral.segments.count == 1,
            case .stringSegment(let segment) = stringLiteral.segments.first
        {
            return segment.content.text
        }

        throw SmockDiagnostic.invalidPreprocessorFlag
    }

    /// Parses array of types from expression syntax
    private static func parseTypeArray(from expression: ExprSyntax) throws -> [TypeSyntax] {
        guard let arrayExpr = expression.as(ArrayExprSyntax.self) else {
            throw SmockDiagnostic.invalidMacroArguments
        }

        var types: [TypeSyntax] = []
        for element in arrayExpr.elements {
            // Handle Type.self syntax (e.g., CustomType.self)
            if let memberAccess = element.expression.as(MemberAccessExprSyntax.self),
                memberAccess.declName.baseName.text == "self",
                let baseType = memberAccess.base?.as(DeclReferenceExprSyntax.self)
            {
                let typeName = baseType.baseName.text
                let typeIdentifier = IdentifierTypeSyntax(name: .identifier(typeName))
                types.append(TypeSyntax(typeIdentifier))
            }
            // Handle module-qualified Type.self syntax (e.g., Foundation.Date.self)
            else if let memberAccess = element.expression.as(MemberAccessExprSyntax.self),
                memberAccess.declName.baseName.text == "self",
                let qualifiedType = memberAccess.base?.as(MemberAccessExprSyntax.self)
            {
                let memberType = MemberTypeSyntax(
                    baseType: TypeSyntax(
                        IdentifierTypeSyntax(
                            name: .identifier(
                                qualifiedType.base?.description.trimmingCharacters(in: .whitespaces) ?? ""
                            )
                        )
                    ),
                    name: .identifier(qualifiedType.declName.baseName.text)
                )
                types.append(TypeSyntax(memberType))
            }
            // Handle direct type references without .self
            else if let declRef = element.expression.as(DeclReferenceExprSyntax.self) {
                let typeIdentifier = IdentifierTypeSyntax(name: .identifier(declRef.baseName.text))
                types.append(TypeSyntax(typeIdentifier))
            }
            // Handle member access for module-qualified types without .self
            else if let memberAccess = element.expression.as(MemberAccessExprSyntax.self) {
                let memberType = MemberTypeSyntax(
                    baseType: TypeSyntax(
                        IdentifierTypeSyntax(
                            name: .identifier(memberAccess.base?.description.trimmingCharacters(in: .whitespaces) ?? "")
                        )
                    ),
                    name: .identifier(memberAccess.declName.baseName.text)
                )
                types.append(TypeSyntax(memberType))
            } else {
                throw SmockDiagnostic.invalidMacroArguments
            }
        }

        return types
    }

    /// Parses array of strings from expression syntax
    private static func parseStringArray(from expression: ExprSyntax) throws -> [String] {
        guard let arrayExpr = expression.as(ArrayExprSyntax.self) else {
            throw SmockDiagnostic.invalidMacroArguments
        }

        var strings: [String] = []
        for element in arrayExpr.elements {
            if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
                stringLiteral.segments.count == 1,
                case .stringSegment(let segment) = stringLiteral.segments.first
            {
                strings.append(segment.content.text)
            } else {
                throw SmockDiagnostic.invalidMacroArguments
            }
        }

        return strings
    }
}
