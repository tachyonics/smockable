import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionPropertiesGenerator {
    static func expectedResponseEnumDeclaration(variablePrefix: String,
                                                functionSignature: FunctionSignatureSyntax) throws -> EnumDeclSyntax
    {
        try EnumDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())ExpectedResponse",
            genericParameterClause: ": Sendable",
            memberBlockBuilder: {
                try EnumCaseDeclSyntax("""
                case closure(@Sendable \(ClosureGenerator.closureElements(functionSignature: functionSignature)))
                """)

                if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
                    try EnumCaseDeclSyntax("""
                    case error(Swift.Error)
                    """)
                }

                if let returnType = functionSignature.returnClause?.type {
                    try EnumCaseDeclSyntax("""
                    case value(\(returnType))
                    """)
                }
            })
    }

    static func expectedResponseVariableDeclaration(variablePrefix: String,
                                                    accessModifier: String,
                                                    staticName: Bool) throws -> VariableDeclSyntax
    {
        try VariableDeclSyntax(
            """
            \(raw: accessModifier)var \(raw: staticName ? "expectedResponses" : variablePrefix): [(Int?,\(raw: variablePrefix
                .capitalizingComponentsFirstLetter())ExpectedResponse)] = []
            """)
    }

    static func expectationsClassDeclaration(variablePrefix: String,
                                             functionSignature: FunctionSignatureSyntax) throws -> ClassDeclSyntax
    {
        try ClassDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_Expectations",
            genericParameterClause: ": FieldExpectations<\(raw: variablePrefix.capitalizingComponentsFirstLetter())ExpectedResponse>",
            memberBlockBuilder: {
                try FunctionDeclSyntax("""
                @discardableResult
                public func using(_ closure: @Sendable @escaping \(ClosureGenerator.closureElements(functionSignature: functionSignature))) -> Self {
                  self.expectedResponses.append((1, .closure(closure)))

                  return self
                }
                """)

                if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
                    try FunctionDeclSyntax("""
                    @discardableResult
                    public func error(_ error: Swift.Error) -> Self {
                      self.expectedResponses.append((1, .error(error)))

                      return self
                    }
                    """)
                }

                if let returnType = functionSignature.returnClause?.type {
                    try FunctionDeclSyntax("""
                    @discardableResult
                    public func value(_ value: \(returnType)) -> Self {
                      self.expectedResponses.append((1, .value(value)))

                      return self
                    }
                    """)
                }
            })
    }

    static func verificationsStructDeclaration(variablePrefix: String,
                                               parameterList: FunctionParameterListSyntax) throws -> StructDeclSyntax
    {
        let elementType = ReceivedInvocationsGenerator.arrayElementType(parameterList: parameterList)

        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_Verifications",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "Sendable"))
            },
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    let storage: Storage
                    """)

                try VariableDeclSyntax("""
                public var wasCalled: Bool {
                    get async {
                        return await self.storage.callCounts.\(raw: variablePrefix) > 0
                    }
                }
                """)

                try VariableDeclSyntax("""
                public var callCount: Int {
                    get async {
                        return await self.storage.callCounts.\(raw: variablePrefix)
                    }
                }
                """)

                if !parameterList.isEmpty {
                    try VariableDeclSyntax("""
                    public var receivedInputs: [\(elementType)] {
                        get async {
                            return await self.storage.receivedInvocations.\(raw: variablePrefix)
                        }
                    }
                    """)
                }
            })
    }

    static func allVerificationsDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> StructDeclSyntax {
        try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "Verifications",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "Sendable"))
            },
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try VariableDeclSyntax(
                        """
                        public let \(raw: variablePrefix): \(raw: variablePrefix.capitalizingComponentsFirstLetter())_Verifications
                        """)
                }

                try InitializerDeclSyntax("init(storage: Storage) {") {
                    for functionDeclaration in functionDeclarations {
                        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                        ExprSyntax("""
                        self.\(raw: variablePrefix) = .init(storage: storage)
                        """)
                    }
                }
            })
    }

    static func allVerificationsVariableDeclaration() throws -> VariableDeclSyntax {
        try VariableDeclSyntax(
            """
            public let __verify: Verifications
            """)
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        prefix(1).uppercased() + dropFirst()
    }

    func capitalizingComponentsFirstLetter() -> String {
        let components = self.split(separator: "_").map { String($0).capitalizingFirstLetter() }

        return components.joined(separator: "_")
    }
}
