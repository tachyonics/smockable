import SwiftDiagnostics

/// `SmockDiagnostic` is an enumeration defining specific error messages related to the Smock system.
///
/// It conforms to the `DiagnosticMessage` and `Error` protocols to provide comprehensive error information
/// and integrate smoothly with error handling mechanisms.
///
/// - Note: The `SmockDiagnostic` enum can be expanded to include more diagnostic cases as
///         the Smock system grows and needs to handle more error types.
enum SmockDiagnostic: String, DiagnosticMessage, Error {
    case onlyApplicableToProtocol
    case variableDeclInProtocolWithNotSingleBinding
    case variableDeclInProtocolWithNotIdentifierPattern

    var message: String {
        switch self {
        case .onlyApplicableToProtocol:
            "'@Smock' can only be applied to a 'protocol'"
        case .variableDeclInProtocolWithNotSingleBinding:
            "Variable declaration in a 'protocol' with the '@Smock' attribute must have exactly one binding"
        case .variableDeclInProtocolWithNotIdentifierPattern:
            "Variable declaration in a 'protocol' with the '@Smock' attribute must have identifier pattern"
        }
    }

    var severity: DiagnosticSeverity {
        switch self {
        case .onlyApplicableToProtocol: .error
        case .variableDeclInProtocolWithNotSingleBinding: .error
        case .variableDeclInProtocolWithNotIdentifierPattern: .error
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SmockMacro", id: rawValue)
    }
}
