import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public enum SmockMacro: PeerMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws
        -> [DeclSyntax]
    {
        let protocolDeclaration = try Extractor.extractProtocolDeclaration(from: declaration)
        let parameters = try MacroParameterParser.parse(from: attribute)

        let mockDeclaration = try MockGenerator.declaration(
            for: protocolDeclaration,
            parameters: parameters
        )

        // Wrap in conditional compilation if preprocessor flag is provided
        if let preprocessorFlag = parameters.preprocessorFlag {
            let conditionalDeclaration = IfConfigDeclSyntax(
                clauses: IfConfigClauseListSyntax {
                    IfConfigClauseSyntax(
                        poundKeyword: .poundIfToken(),
                        condition: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(preprocessorFlag))),
                        elements: .decls(mockDeclarationDecls(mockDeclaration: mockDeclaration))
                    )
                }
            )
            return [DeclSyntax(conditionalDeclaration)]
        } else {
            return [DeclSyntax(mockDeclaration)]
        }
    }
    
    @MemberBlockItemListBuilder
    private static func mockDeclarationDecls(
        mockDeclaration: StructDeclSyntax
    ) -> MemberBlockItemListSyntax {
        mockDeclaration
    }
}
