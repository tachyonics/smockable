import SwiftSyntax
import SwiftSyntaxBuilder

enum FieldOptionsGenerator {
    static func fieldOptionsClassDeclaration(
        variablePrefix: String,
        functionSignature: FunctionSignatureSyntax,
        typePrefix: String = ""
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
            name: "\(raw: typePrefix)\(raw: variablePrefix.capitalizingComponentsFirstLetter())_FieldOptions",
            genericParameterClause: genericParameterClauseElements.count > 0
                ? ": \(raw: genericParameterClauseElements.joined(separator: ", ")) " : nil,
            memberBlockBuilder: {
                try VariableDeclSyntax(
                    """
                    var expectedResponse: \(raw: typePrefix)\(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse?
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
}
