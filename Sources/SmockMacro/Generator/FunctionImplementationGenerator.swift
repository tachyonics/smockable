import SwiftSyntax
import SwiftSyntaxBuilder

enum FunctionImplementationGenerator {
  static func declaration(
    variablePrefix: String,
    accessModifier: String?,
    protocolFunctionDeclaration: FunctionDeclSyntax
  ) -> FunctionDeclSyntax {
    var mockFunctionDeclaration = protocolFunctionDeclaration

    mockFunctionDeclaration.modifiers =
      protocolFunctionDeclaration.modifiers.removingMutatingKeyword
    mockFunctionDeclaration.leadingTrivia = .init(pieces: [])

    if let accessModifier {
      mockFunctionDeclaration.modifiers += [DeclModifierSyntax(name: "\(raw: accessModifier)")]
    }

    mockFunctionDeclaration.body = CodeBlockSyntax {
      ClosureGenerator.callExpression(
        baseName: "self.storage.\(protocolFunctionDeclaration.name.text)",
        variablePrefix: variablePrefix, needsLabels: true,
        functionSignature: protocolFunctionDeclaration.signature)
    }

    return mockFunctionDeclaration
  }

    static func storageDeclaration(
        variablePrefix: String,
        protocolFunctionDeclaration: FunctionDeclSyntax
      ) throws -> FunctionDeclSyntax {
        var mockFunctionDeclaration = protocolFunctionDeclaration

        mockFunctionDeclaration.modifiers =
          protocolFunctionDeclaration.modifiers.removingMutatingKeyword
          mockFunctionDeclaration.leadingTrivia = .init(pieces: [])
          
          let parameterList = protocolFunctionDeclaration.signature.parameterClause.parameters
          let parameters = Array(parameterList)
          let matcherCall = generateMatcherCall(parameters: parameters)

        mockFunctionDeclaration.body = try CodeBlockSyntax {
          let parameterList = protocolFunctionDeclaration.signature.parameterClause.parameters

          CallsCountGenerator.incrementVariableExpression(variablePrefix: variablePrefix)

          if !parameterList.isEmpty {
            ReceivedInvocationsGenerator.appendValueToVariableExpression(
              variablePrefix: variablePrefix,
              parameterList: parameterList)
          }
            
            try VariableDeclSyntax("""
                var responseProvider: \(raw: variablePrefix.capitalizingComponentsFirstLetter())_ExpectedResponse?
                """)
            
            try ForStmtSyntax("for (index, expectedResponse) in self.expectedResponses.\(raw: variablePrefix).enumerated()") {
                ExprSyntax(
                    """
                    if expectedResponse.2.matches(\(raw: matcherCall)) {
                      if expectedResponse.0 == 1 {
                        self.expectedResponses.\(raw: variablePrefix).remove(at: index)
                      } else if let currentCount = expectedResponse.0 {
                        self.expectedResponses.\(raw: variablePrefix)[index] = (currentCount - 1, expectedResponse.1, expectedResponse.2)
                      }
                      
                      responseProvider = expectedResponse.1
                      break
                    }
                    """)
            }
            
            self.switchExpression(variablePrefix: variablePrefix, protocolFunctionDeclaration: protocolFunctionDeclaration)
        }

        return mockFunctionDeclaration
      }
    
    private static func generateMatcherCall(parameters: [FunctionParameterSyntax]) -> String {
        return parameters.map { parameter in
          let paramName = parameter.secondName?.text ?? parameter.firstName.text
          let firstName = parameter.firstName.text
          return "\(firstName): \(paramName)"
        }.joined(separator: ", ")
      }

    private static func switchExpression(
        variablePrefix: String,
        protocolFunctionDeclaration: FunctionDeclSyntax,
      ) -> SwitchExprSyntax {
        SwitchExprSyntax(
          subject: ExprSyntax(stringLiteral: "responseProvider"),
          casesBuilder: {
            SwitchCaseSyntax(
              SyntaxNodeString("case .closure(let closure):"),
              statementsBuilder: {
                ReturnStmtSyntax(
                  expression:
                    ClosureGenerator.callExpression(
                      baseName: "closure", variablePrefix: variablePrefix,
                      needsLabels: false, functionSignature: protocolFunctionDeclaration.signature))
              })

            if protocolFunctionDeclaration.signature.effectSpecifiers?.throwsClause?.throwsSpecifier
              != nil
            {
              SwitchCaseSyntax(
                """
                case .error(let error):
                    throw error
                """)
            }

            if (protocolFunctionDeclaration.signature.returnClause?.type) != nil {
              SwitchCaseSyntax(
                """
                case .value(let value):
                    return value
                """)
            } else {
              SwitchCaseSyntax(
                """
                case .success:
                    return
                """)
            }
              
              SwitchCaseSyntax(
                """
                case nil:
                    fatalError("\(raw: variablePrefix) without a matching expectation.")
                """)
          })
      }
    }

extension DeclModifierListSyntax {
  fileprivate var removingMutatingKeyword: Self {
    filter { $0.name.text != TokenSyntax.keyword(.mutating).text }
  }
}
