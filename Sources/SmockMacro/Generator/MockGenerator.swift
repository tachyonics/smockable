import Foundation
import SwiftSyntax
import SwiftSyntaxBuilder

enum MockGenerator {
    static func getGenericParameterClause(
        associatedTypes: [AssociatedTypeDeclSyntax]
    )
        -> GenericParameterClauseSyntax?
    {
        let genericParameterClause: GenericParameterClauseSyntax?
        if !associatedTypes.isEmpty {
            let rawGenericParameterClause = associatedTypes.map { associatedType in
                if let inheritanceClause = associatedType.inheritanceClause {
                    "\(associatedType.name) \(inheritanceClause)"
                } else {
                    "\(associatedType.name)"
                }
            }.joined(separator: ", ")

            genericParameterClause = GenericParameterClauseSyntax("<\(raw: rawGenericParameterClause)>")
        } else {
            genericParameterClause = nil
        }

        return genericParameterClause
    }

    static func getComparableAssociatedTypes(
        associatedTypes: [AssociatedTypeDeclSyntax]
    )
        -> [String]
    {
        if !associatedTypes.isEmpty {
            return associatedTypes.filter { associatedType in
                let filteredAssociatedTypes = associatedType.inheritanceClause?.inheritedTypes.filter { syntax in
                    let components = syntax.description.split(separator: "&")
                    let trimmedComponents = components.map {
                        String($0.trimmingCharacters(in: .whitespacesAndNewlines))
                    }

                    return Set(trimmedComponents).contains("Comparable")
                }

                return !(filteredAssociatedTypes ?? []).isEmpty
            }.map { $0.name.description }
        } else {
            return []
        }
    }

    // swiftlint:disable function_body_length
    static func declaration(for protocolDeclaration: ProtocolDeclSyntax) throws -> StructDeclSyntax {
        let identifier = TokenSyntax.identifier("Mock" + protocolDeclaration.name.text)

        let variableDeclarations = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }

        let functionDeclarations = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }

        let associatedTypes = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(AssociatedTypeDeclSyntax.self) }

        let genericParameterClause = getGenericParameterClause(associatedTypes: associatedTypes)
        let comparableAssociatedTypes = getComparableAssociatedTypes(associatedTypes: associatedTypes)

        func isComparableProvider(baseType: String) -> Bool {
            let builtInComparableTypes = [
                "String", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
                "Float", "Double", "Character", "Date",
            ]
            let comparableTypes = Set(comparableAssociatedTypes + builtInComparableTypes)
            return comparableTypes.contains(baseType)
        }

        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: identifier,
            genericParameterClause: genericParameterClause,
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: protocolDeclaration.name)
                )

                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "Sendable")
                )
            },
            memberBlockBuilder: {
                try InitializerDeclSyntax("public init(expectations: consuming Expectations = .init()) { ") {
                    ExprSyntax(
                        """
                        self.storage = .init(expectedResponses: .init(expectations: expectations))
                        """
                    )

                    ExprSyntax(
                        """
                        self.__verify = .init(storage: self.storage)
                        """
                    )
                }

                for variableDeclaration in variableDeclarations {
                    try VariablesImplementationGenerator.variablesDeclarations(
                        protocolVariableDeclaration: variableDeclaration
                    )
                }

                try StorageGenerator.expectationsDeclaration(
                    functionDeclarations: functionDeclarations,
                    isComparableProvider: isComparableProvider
                )
                try StorageGenerator.expectedResponsesDeclaration(
                    functionDeclarations: functionDeclarations
                )
                try StorageGenerator.expectationMatchersDeclaration(
                    functionDeclarations: functionDeclarations
                )
                try StorageGenerator.callCountDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.receivedInvocationsDeclaration(
                    functionDeclarations: functionDeclarations
                )
                try StorageGenerator.actorDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.variableDeclaration()

                try FunctionPropertiesGenerator.allVerificationsDeclaration(
                    functionDeclarations: functionDeclarations
                )
                try FunctionPropertiesGenerator.allVerificationsVariableDeclaration()

                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                    let parameterList = functionDeclaration.signature.parameterClause.parameters

                    try FunctionPropertiesGenerator.expectationsOptionsClassDeclaration(
                        variablePrefix: variablePrefix,
                        functionSignature: functionDeclaration.signature
                    )
                    try FunctionPropertiesGenerator.expectedResponseEnumDeclaration(
                        variablePrefix: variablePrefix,
                        functionSignature: functionDeclaration.signature
                    )
                    try FunctionPropertiesGenerator.verificationsStructDeclaration(
                        variablePrefix: variablePrefix,
                        parameterList: parameterList
                    )

                    // Generate input matcher struct for functions with parameters
                    if let inputMatcherStruct = try InputMatcherGenerator.inputMatcherStructDeclaration(
                        variablePrefix: variablePrefix,
                        parameterList: parameterList,
                        isComparableProvider: isComparableProvider
                    ) {
                        inputMatcherStruct
                    }

                    FunctionImplementationGenerator.declaration(
                        variablePrefix: variablePrefix,
                        accessModifier: "public",
                        protocolFunctionDeclaration: functionDeclaration
                    )
                }
            }
        )
    }
    // swiftlint:enable function_body_length
}
