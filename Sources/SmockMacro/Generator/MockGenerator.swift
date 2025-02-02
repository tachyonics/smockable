import SwiftSyntax
import SwiftSyntaxBuilder

enum MockGenerator {
    static func declaration(for protocolDeclaration: ProtocolDeclSyntax) throws -> StructDeclSyntax {
        let identifier = TokenSyntax.identifier("Mock" + protocolDeclaration.name.text)

        let variableDeclarations = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }

        let functionDeclarations = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }

        let associatedTypes = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(AssociatedTypeDeclSyntax.self) }

        let genericParameterClause: GenericParameterClauseSyntax?
        if !associatedTypes.isEmpty {
            let rawGenericParameterClause = associatedTypes.map { associatedType in
                if let inheritanceClause = associatedType.inheritanceClause {
                    return "\(associatedType.name) \(inheritanceClause)"
                } else {
                    return "\(associatedType.name)"
                }
            }.joined(separator: ", ")

            genericParameterClause = GenericParameterClauseSyntax("<\(raw: rawGenericParameterClause)>")
        } else {
            genericParameterClause = nil
        }

        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: identifier,
            genericParameterClause: genericParameterClause,
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: protocolDeclaration.name))
            },
            memberBlockBuilder: {
                try InitializerDeclSyntax("public init(expectations: consuming Expectations = .init()) { ") {                    
                    ExprSyntax("""
                    self.storage = .init(expectedResponses: .init(expectations: expectations))
                    """)

                    ExprSyntax("""
                    self.__verify = .init(storage: self.storage)
                    """)
                }

                for variableDeclaration in variableDeclarations {
                    try VariablesImplementationGenerator.variablesDeclarations(
                        protocolVariableDeclaration: variableDeclaration)
                }

                try StorageGenerator.expectationsDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.expectedResponsesDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.callCountDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.receivedInvocationsDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.actorDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.variableDeclaration()

                try FunctionPropertiesGenerator.allVerificationsDeclaration(functionDeclarations: functionDeclarations)
                try FunctionPropertiesGenerator.allVerificationsVariableDeclaration()

                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                    let parameterList = functionDeclaration.signature.parameterClause.parameters

                    try FunctionPropertiesGenerator.expectedResponseEnumDeclaration(variablePrefix: variablePrefix,
                                                                                    functionSignature: functionDeclaration.signature)
                    try FunctionPropertiesGenerator.verificationsStructDeclaration(variablePrefix: variablePrefix, parameterList: parameterList)
                    try FunctionPropertiesGenerator.expectationsClassDeclaration(variablePrefix: variablePrefix,
                                                                                 functionSignature: functionDeclaration.signature)

                    FunctionImplementationGenerator.declaration(
                        variablePrefix: variablePrefix, accessModifier: "public",
                        protocolFunctionDeclaration: functionDeclaration)
                }
            })
    }
}
