import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionPropertiesGenerator {
    static func expectedResponseEnumDeclaration(variablePrefix: String,
                                                functionSignature: FunctionSignatureSyntax) throws -> EnumDeclSyntax {
        return try EnumDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "fileprivate")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())ExpectedResponse",
            memberBlockBuilder: {
                try EnumCaseDeclSyntax("""
                case closure(\(ClosureGenerator.closureElements(functionSignature: functionSignature)))
                """)

                if functionSignature.effectSpecifiers?.throwsSpecifier != nil {
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
                                                    accessModifier: String) throws -> VariableDeclSyntax {
        try VariableDeclSyntax(
            """
            \(raw: accessModifier)var \(raw: variablePrefix)_ExpectedResponses: [(Int?,\(raw: variablePrefix.capitalizingComponentsFirstLetter())ExpectedResponse)] = []
            """)
    }

    static func expectationsClassDeclaration(variablePrefix: String,
                                             functionSignature: FunctionSignatureSyntax) throws -> ClassDeclSyntax {
        return try ClassDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_Expectations",
            memberBlockBuilder: {
                try self.expectedResponseVariableDeclaration(variablePrefix: variablePrefix, accessModifier: "fileprivate ")

                try FunctionDeclSyntax("""
                private func add\(raw: variablePrefix.capitalizingComponentsFirstLetter())Expectation(_ expected: \(
                    raw: variablePrefix
                        .capitalizingComponentsFirstLetter())ExpectedResponse) {
                    self.\(raw: variablePrefix)_ExpectedResponses.append((1, expected))
                }
                """)

                try FunctionDeclSyntax("""
                private func updateLast\(raw: variablePrefix.capitalizingComponentsFirstLetter())Expectation(count: Int) {
                    guard let last = self.\(raw: variablePrefix)_ExpectedResponses.last else {
                        fatalError("Must have added expectation to update its count.")
                    }

                    guard let currentCount = last.0 else {
                        fatalError("Cannot add expectations after a previous unbounded expectation.")
                    }

                    self.\(raw: variablePrefix)_ExpectedResponses.removeLast()
                    self.\(raw: variablePrefix)_ExpectedResponses.append((currentCount + count, last.1))
                }
                """)

                try FunctionDeclSyntax("""
                @discardableResult
                public func unboundedTimes() -> Self {
                    guard let last = self.\(raw: variablePrefix)_ExpectedResponses.last else {
                        fatalError("Must have added expectation to update its count.")
                    }

                    self.\(raw: variablePrefix)_ExpectedResponses.removeLast()
                    self.\(raw: variablePrefix)_ExpectedResponses.append((nil, last.1))

                    return self
                }
                """)

                try FunctionDeclSyntax("""
                @discardableResult
                public func times(_ count: Int) -> Self {
                    guard let last = self.\(raw: variablePrefix)_ExpectedResponses.last else {
                        fatalError("Must have added expectation to update its count.")
                    }

                    self.\(raw: variablePrefix)_ExpectedResponses.removeLast()
                    self.\(raw: variablePrefix)_ExpectedResponses.append((count, last.1))

                    return self
                }
                """)

                try FunctionDeclSyntax("""
                @discardableResult
                public func using(_ closure: @escaping \(ClosureGenerator.closureElements(functionSignature: functionSignature))) -> Self {
                  add\(raw: variablePrefix.capitalizingComponentsFirstLetter())Expectation(.closure(closure))

                  return self
                }
                """)

                if functionSignature.effectSpecifiers?.throwsSpecifier != nil {
                    try FunctionDeclSyntax("""
                    @discardableResult
                    public func error(_ error: Swift.Error) -> Self {
                      add\(raw: variablePrefix.capitalizingComponentsFirstLetter())Expectation(.error(error))

                      return self
                    }
                    """)
                }

                if let returnType = functionSignature.returnClause?.type {
                    try FunctionDeclSyntax("""
                    public func value(_ value: \(returnType)) -> Self {
                      add\(raw: variablePrefix.capitalizingComponentsFirstLetter())Expectation(.value(value))

                      return self
                    }
                    """)
                }
            })
    }

    static func verificationsStructDeclaration(variablePrefix: String,
                                               parameterList: FunctionParameterListSyntax) throws -> StructDeclSyntax {
        let elementType = ReceivedInvocationsGenerator.arrayElementType(parameterList: parameterList)

        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "\(raw: variablePrefix.capitalizingComponentsFirstLetter())_Verifications",
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    fileprivate let storage: Storage
                    """)

                DeclSyntax("""
                public var wasCalled: Bool {
                    get async {
                        return await self.storage.\(raw: variablePrefix)_CallsCount > 0
                    }
                }
                """)

                DeclSyntax("""
                public var callCount: Int {
                    get async {
                        return await self.storage.\(raw: variablePrefix)_CallsCount
                    }
                }
                """)

                if !parameterList.isEmpty {
                    DeclSyntax("""
                    public var receivedInputs: [\(elementType)] {
                        get async {
                            return await self.storage.\(raw: variablePrefix)_ReceivedInvocations
                        }
                    }
                    """)
                }
            })
    }

    static func allVerificationsDeclaration(functionDeclarations: [FunctionDeclSyntax]) throws -> StructDeclSyntax {
        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: "Verifications",
            memberBlockBuilder: {
                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)

                    try VariableDeclSyntax(
                        """
                        public let \(raw: variablePrefix): \(raw: variablePrefix.capitalizingComponentsFirstLetter())_Verifications
                        """)
                }

                try InitializerDeclSyntax("fileprivate init(storage: Storage) {") {
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
        return prefix(1).uppercased() + dropFirst()
    }

    func capitalizingComponentsFirstLetter() -> String {
        let components = self.split(separator: "_").map { String($0).capitalizingFirstLetter() }

        return components.joined(separator: "_")
    }
}
