import SwiftSyntax
import SwiftSyntaxMacros

public enum SmockMacro: PeerMacro {
    public static func expansion(
        of _: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws
        -> [DeclSyntax]
    {
        let protocolDeclaration = try Extractor.extractProtocolDeclaration(from: declaration)

        let mockDeclaration = try MockGenerator.declaration(for: protocolDeclaration)

        return [DeclSyntax(mockDeclaration)]
    }
}
