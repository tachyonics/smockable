import SwiftSyntax

/// Represents the parameters that can be passed to the @Smock macro
struct MacroParameters {
    let accessLevel: AccessLevel
    let preprocessorFlag: String?
    
    /// Default parameters for the macro
    static let `default` = MacroParameters(
        accessLevel: .default,
        preprocessorFlag: nil
    )
}

/// Utility for parsing macro parameters from AttributeSyntax
enum MacroParameterParser {
    
    /// Parses macro parameters from the attribute syntax
    /// - Parameter attribute: The @Smock attribute syntax
    /// - Returns: Parsed parameters or default if no parameters provided
    /// - Throws: SmockDiagnostic if parameters are invalid
    static func parse(from attribute: AttributeSyntax) throws -> MacroParameters {
        // If no arguments provided, return defaults
        guard let arguments = attribute.arguments else {
            return .default
        }
        
        guard case .argumentList(let argumentList) = arguments else {
            throw SmockDiagnostic.invalidMacroArguments
        }
        
        var accessLevel: AccessLevel = .default
        var preprocessorFlag: String? = nil
        
        for argument in argumentList {
            guard let label = argument.label?.text else {
                throw SmockDiagnostic.invalidMacroArguments
            }
            
            switch label {
            case "accessLevel":
                accessLevel = try parseAccessLevel(from: argument.expression)
            case "preprocessorFlag":
                preprocessorFlag = try parsePreprocessorFlag(from: argument.expression)
            default:
                throw SmockDiagnostic.unknownMacroParameter
            }
        }
        
        return MacroParameters(
            accessLevel: accessLevel,
            preprocessorFlag: preprocessorFlag
        )
    }
    
    /// Parses access level from expression syntax
    private static func parseAccessLevel(from expression: ExprSyntax) throws -> AccessLevel {
        // Handle member access like .public, .internal, etc.
        if let memberAccess = expression.as(MemberAccessExprSyntax.self),
           memberAccess.base == nil,
           let accessLevel = AccessLevel(rawValue: memberAccess.declName.baseName.text) {
            return accessLevel
        }
        
        // Handle direct identifier like public, internal, etc.
        if let identifier = expression.as(DeclReferenceExprSyntax.self),
           let accessLevel = AccessLevel(rawValue: identifier.baseName.text) {
            return accessLevel
        }
        
        throw SmockDiagnostic.invalidAccessLevel
    }
    
    /// Parses preprocessor flag from expression syntax
    private static func parsePreprocessorFlag(from expression: ExprSyntax) throws -> String {
        if let stringLiteral = expression.as(StringLiteralExprSyntax.self),
           stringLiteral.segments.count == 1,
           case .stringSegment(let segment) = stringLiteral.segments.first {
            return segment.content.text
        }
        
        throw SmockDiagnostic.invalidPreprocessorFlag
    }
}
