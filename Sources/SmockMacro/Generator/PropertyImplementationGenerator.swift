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
//  PropertyImplementationGenerator.swift
//  SmockMacro
//

import SwiftSyntax
import SwiftSyntaxBuilder

struct PropertyFunction {
    let function: FunctionDeclSyntax
    let variablePrefix: String
    let parameterList: FunctionParameterListSyntax
    let effectSpecifiers: AccessorEffectSpecifiersSyntax?
}

struct PropertyDeclaration {
    let name: String
    let typePrefix: String
    let storagePrefix: String
    let variable: VariableDeclSyntax
    let get: PropertyFunction?
    let set: PropertyFunction?
}

enum PropertyImplementationGenerator {
    @MemberBlockItemListBuilder
    static func propertyDeclaration(
        propertyDeclaration: PropertyDeclaration,
        accessLevel: AccessLevel
    ) throws
        -> MemberBlockItemListSyntax
    {
        let bindings = propertyDeclaration.variable.bindings
        if let binding = bindings.first, bindings.count == 1 {
            try self.propertyDeclarationWithGetterAndSetter(
                binding: binding,
                propertyDeclaration: propertyDeclaration,
                accessLevel: accessLevel
            )
        } else {
            // As far as I know variable declaration in a protocol should have exactly one binding.
            throw SmockDiagnostic.variableDeclInProtocolWithNotSingleBinding
        }
    }

    private static func propertyDeclarationWithGetterAndSetter(
        binding: PatternBindingSyntax,
        propertyDeclaration: PropertyDeclaration,
        accessLevel: AccessLevel
    )
        throws -> VariableDeclSyntax
    {
        var accessors: AccessorDeclListSyntax = []
        if let get = propertyDeclaration.get {
            accessors.append(
                AccessorDeclSyntax(
                    accessorSpecifier: .keyword(.get),
                    effectSpecifiers: get.effectSpecifiers,
                    body: try FunctionImplementationGenerator.getFunctionBody(
                        variablePrefix: get.variablePrefix,
                        typePrefix: propertyDeclaration.typePrefix,
                        storagePrefix: propertyDeclaration.storagePrefix,
                        functionDeclaration: get.function,
                        parameterList: get.parameterList
                    )
                )
            )
        }
        if let set = propertyDeclaration.set {
            accessors.append(
                AccessorDeclSyntax(
                    accessorSpecifier: .keyword(.set),
                    effectSpecifiers: set.effectSpecifiers,
                    body: try FunctionImplementationGenerator.getFunctionBody(
                        variablePrefix: set.variablePrefix,
                        typePrefix: propertyDeclaration.typePrefix,
                        storagePrefix: propertyDeclaration.storagePrefix,
                        functionDeclaration: set.function,
                        parameterList: set.parameterList
                    )
                )
            )
        }

        return VariableDeclSyntax(
            modifiers: [accessLevel.declModifier],
            bindingSpecifier: .keyword(.var),
            bindings: [
                PatternBindingSyntax(
                    pattern: binding.pattern,
                    typeAnnotation: binding.typeAnnotation,
                    accessorBlock: AccessorBlockSyntax(
                        accessors: .accessors(accessors)
                    )
                )
            ]
        )
    }
}
