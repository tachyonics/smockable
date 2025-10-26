import SwiftDiagnostics

/// `SmockDiagnostic` is an enumeration defining specific error messages related to the Smock system.
///
/// It conforms to the `DiagnosticMessage` and `Error` protocols to provide comprehensive error information
/// and integrate smoothly with error handling mechanisms.
///
/// - Note: The `SmockDiagnostic` enum can be expanded to include more diagnostic cases as
///         the Smock system grows and needs to handle more error types.
package enum SmockDiagnostic: String, DiagnosticMessage, Error {
    case onlyApplicableToProtocol
    case variableDeclInProtocolWithNotSingleBinding
    case variableDeclInProtocolWithNotIdentifierPattern
    case invalidMacroArguments
    case unknownMacroParameter
    case invalidAccessLevel
    case invalidPreprocessorFlag

    package var message: String {
        switch self {
        case .onlyApplicableToProtocol:
            "'@Smock' can only be applied to a 'protocol'"
        case .variableDeclInProtocolWithNotSingleBinding:
            "Variable declaration in a 'protocol' with the '@Smock' attribute must have exactly one binding"
        case .variableDeclInProtocolWithNotIdentifierPattern:
            "Variable declaration in a 'protocol' with the '@Smock' attribute must have identifier pattern"
        case .invalidMacroArguments:
            "Invalid arguments provided to '@Smock' macro"
        case .unknownMacroParameter:
            "Unknown parameter provided to '@Smock' macro. Valid parameters are: accessLevel, preprocessorFlag, additionalComparableTypes, additionalEquatableTypes"
        case .invalidAccessLevel:
            "Invalid access level. Valid values are: .public, .package, .internal, .fileprivate, .private"
        case .invalidPreprocessorFlag:
            "Preprocessor flag must be a string literal"
        }
    }

    package var severity: DiagnosticSeverity {
        switch self {
        case .onlyApplicableToProtocol: .error
        case .variableDeclInProtocolWithNotSingleBinding: .error
        case .variableDeclInProtocolWithNotIdentifierPattern: .error
        case .invalidMacroArguments: .error
        case .unknownMacroParameter: .error
        case .invalidAccessLevel: .error
        case .invalidPreprocessorFlag: .error
        }
    }

    package var diagnosticID: MessageID {
        MessageID(domain: "SmockMacro", id: rawValue)
    }
}
