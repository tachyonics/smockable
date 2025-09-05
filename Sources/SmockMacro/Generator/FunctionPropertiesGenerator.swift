import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionPropertiesGenerator {
    static func expectationsOptionsClassDeclaration(
        variablePrefix: String,
        functionSignature: FunctionSignatureSyntax
    ) throws -> ClassDeclSyntax {

        var genericParameterClauseElements: [String] = []
        if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
            genericParameterClauseElements.append("ErrorableFieldOptionsProtocol")
        }

        if functionSignature.returnClause?.type != nil {
            genericParameterClauseElements.append("ReturnableFieldOptionsProtocol")
        } else {
            genericParameterClauseElements.append("VoidReturnableFieldOptionsProtocol")
        }

        return try ClassDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_FieldOptions",
            genericParameterClause: genericParameterClauseElements.count > 0
                ? ": \(raw: genericParameterClauseElements.joined(separator: ", ")) " : nil,
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    var expectedResponse: \(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse?
                    """
                )

                try VariableDeclSyntax(
                    """
                    var times: Int?
                    """
                )

                try FunctionDeclSyntax(
                    """
                    public func update(using closure: @Sendable @escaping \(ClosureGenerator.closureElements(functionSignature: functionSignature))) {
                      self.expectedResponse = .closure(closure)
                    }
                    """
                )

                if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
                    try FunctionDeclSyntax(
                        """
                        public func update(error: Swift.Error) {
                          self.expectedResponse = .error(error)
                        }
                        """
                    )
                }

                if let returnType = functionSignature.returnClause?.type {
                    try FunctionDeclSyntax(
                        """
                        public func update(value: \(returnType)) {
                          self.expectedResponse = .value(value)
                        }
                        """
                    )
                } else {
                    try FunctionDeclSyntax(
                        """
                        public func success() {
                          self.expectedResponse = .success
                        }
                        """
                    )
                }

                try FunctionDeclSyntax(
                    """
                    public func update(times: Int?) {
                      self.times = times
                    }
                    """
                )
            }
        )
    }

    static func expectedResponseEnumDeclaration(
        variablePrefix: String,
        functionSignature: FunctionSignatureSyntax
    ) throws -> EnumDeclSyntax {
        try EnumDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse",
            genericParameterClause: ": Sendable",
            memberBlockBuilder: {
                try EnumCaseDeclSyntax(
                    """
                    case closure(@Sendable \(ClosureGenerator.closureElements(functionSignature: functionSignature)))
                    """
                )

                if functionSignature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
                    try EnumCaseDeclSyntax(
                        """
                        case error(Swift.Error)
                        """
                    )
                }

                if let returnType = functionSignature.returnClause?.type {
                    try EnumCaseDeclSyntax(
                        """
                        case value(\(returnType))
                        """
                    )
                } else {
                    try EnumCaseDeclSyntax(
                        """
                        case success
                        """
                    )
                }
            }
        )
    }

    static func expectedResponseVariableDeclaration(
        variablePrefix: String,
        functionDeclaration: FunctionDeclSyntax,
        accessModifier: String,
        staticName: Bool
    ) throws -> VariableDeclSyntax {
        let expectedResponseType =
            "\(variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse"
        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
        let parameterList = functionDeclaration.signature.parameterClause.parameters
        let inputMatcherType =
            parameterList.count > 0
            ? "\(variablePrefix.capitalizingComponentsFirstLetter())_InputMatcher" : "AlwaysMatcher"

        return try VariableDeclSyntax(
            """
            \(raw: accessModifier)var \(raw: staticName ? "expectedResponses" : variablePrefix): [(Int?,\(raw: expectedResponseType),\(raw: inputMatcherType))] = []
            """
        )
    }

    static func verificationsStructDeclaration(
        variablePrefix: String,
        parameterList: FunctionParameterListSyntax
    ) throws -> StructDeclSyntax {
        let elementType = ReceivedInvocationsGenerator.arrayElementType(parameterList: parameterList)

        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_Verifications",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "Sendable")
                )
            },
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    let storage: Storage
                    """
                )

                try VariableDeclSyntax(
                    """
                    public var wasCalled: Bool {
                        get async {
                            return await self.storage.callCounts.\(raw: variablePrefix) > 0
                        }
                    }
                    """
                )

                try VariableDeclSyntax(
                    """
                    public var callCount: Int {
                        get async {
                            return await self.storage.callCounts.\(raw: variablePrefix)
                        }
                    }
                    """
                )

                if !parameterList.isEmpty {
                    try VariableDeclSyntax(
                        """
                        public var receivedInputs: [\(elementType)] {
                            get async {
                                return await self.storage.receivedInvocations.\(raw: variablePrefix)
                            }
                        }
                        """
                    )
                }
            }
        )
    }

    static func allVerificationsDeclaration(
        functionDeclarations: [FunctionDeclSyntax]
    ) throws
        -> StructDeclSyntax
    {
        try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "Verifications",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "Sendable")
                )
            },
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try VariableDeclSyntax(
                        """
                        public let \(raw: variablePrefix): \(raw: variablePrefix.capitalizingComponentsFirstLetter())_Verifications
                        """
                    )
                }

                try InitializerDeclSyntax("init(storage: Storage) {") {
                    for functionDeclaration in functionDeclarations {
                        let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                        ExprSyntax(
                            """
                            self.\(raw: variablePrefix) = .init(storage: storage)
                            """
                        )
                    }
                }
            }
        )
    }

    static func allVerificationsVariableDeclaration() throws -> VariableDeclSyntax {
        try VariableDeclSyntax(
            """
            public let __verify: Verifications
            """
        )
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
