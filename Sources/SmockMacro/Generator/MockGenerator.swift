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
                    "\(associatedType.name) \(inheritanceClause)"
                } else {
                    "\(associatedType.name)"
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
                
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "Sendable"))
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

                try fieldExpectations()

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
    
    static func fieldExpectations() throws -> ClassDeclSyntax {
        try ClassDeclSyntax("""
        public class FieldExpectations<ExpectedResponseType> {
            var expectedResponses: [(Int?, ExpectedResponseType)] = []
            private func add(_ expected: ExpectedResponseType) {
                self.expectedResponses.append((1, expected))
            }
            private func updateLastExpectation(count: Int) {
                guard let last = self.expectedResponses.last else {
                    fatalError("Must have added expectation to update its count.")
                }

                guard let currentCount = last.0 else {
                    fatalError("Cannot add expectations after a previous unbounded expectation.")
                }

                self.expectedResponses.removeLast()
                self.expectedResponses.append((currentCount + count, last.1))
            }
            @discardableResult
            public func unboundedTimes() -> Self {
                guard let last = self.expectedResponses.last else {
                    fatalError("Must have added expectation to update its count.")
                }

                self.expectedResponses.removeLast()
                self.expectedResponses.append((nil, last.1))

                return self
            }
            @discardableResult
            public func times(_ count: Int) -> Self {
                guard let last = self.expectedResponses.last else {
                    fatalError("Must have added expectation to update its count.")
                }

                self.expectedResponses.removeLast()
                self.expectedResponses.append((count, last.1))

                return self
            }
        }
        """)
    }
}
