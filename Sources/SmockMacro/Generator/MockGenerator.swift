import Foundation
import SmockableUtils
import SwiftSyntax
import SwiftSyntaxBuilder

enum MacroError: Error {
    case invalidPropertyDeclaration
}

enum MockGenerator {
    static func getGenericParameterClause(
        associatedTypes: [AssociatedTypeDeclSyntax]
    )
        -> GenericParameterClauseSyntax?
    {
        let genericParameterClause: GenericParameterClauseSyntax?
        if !associatedTypes.isEmpty {
            let rawGenericParameterClause = associatedTypes.map { associatedType in
                if let inheritanceClause = associatedType.inheritanceClause {
                    "\(associatedType.name) \(inheritanceClause)"
                } else {
                    "\(associatedType.name)"
                }
            }.joined(separator: ", ")

            genericParameterClause = GenericParameterClauseSyntax("<\(raw: rawGenericParameterClause)>")
        } else {
            genericParameterClause = nil
        }

        return genericParameterClause
    }

    // swiftlint:disable function_body_length
    static func createGetterSetterPropertyDeclaration(for variable: VariableDeclSyntax) throws -> PropertyDeclaration {
        guard let binding = variable.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
            let type = binding.typeAnnotation?.type
        else {
            throw MacroError.invalidPropertyDeclaration
        }

        let propertyName = identifier.text
        let propertyType = type

        // Parse accessor block to determine async/throws modifiers
        var isAsync = false
        var isThrowing = false
        var hasGetter = false
        var hasSetter = false
        var effectSpecifiers: AccessorEffectSpecifiersSyntax?

        if let accessorBlock = binding.accessorBlock {
            switch accessorBlock.accessors {
            case .accessors(let accessorList):
                for accessor in accessorList {
                    switch accessor.accessorSpecifier.tokenKind {
                    case .keyword(.get):
                        hasGetter = true
                        isAsync = accessor.effectSpecifiers?.asyncSpecifier != nil
                        isThrowing = accessor.effectSpecifiers?.throwsClause != nil

                        effectSpecifiers = accessor.effectSpecifiers
                    case .keyword(.set):
                        hasSetter = true
                    // Setters inherit async/throws from getters in property declarations
                    default:
                        break
                    }
                }
            case .getter:
                hasGetter = true
            // For computed properties with just a getter block
            }
        } else {
            // If no accessor block, it's a stored property (get/set)
            hasGetter = true
            hasSetter = true
        }

        let getter =
            hasGetter
            ? try getPropertyFunction(
                propertyFunctionType: .get,
                propertyType: propertyType,
                isAsync: isAsync,
                isThrowing: isThrowing
            )
            : nil
        let setter =
            hasSetter
            ? try getPropertyFunction(
                propertyFunctionType: .set,
                propertyType: propertyType,
                isAsync: isAsync,
                isThrowing: isThrowing
            )
            : nil

        let typePrefix = "\(propertyName.capitalizingComponentsFirstLetter())_"

        let get: PropertyFunction?
        if let getter {
            let getterVariablePrefix = VariablePrefixGenerator.text(for: getter)
            get = PropertyFunction(
                function: getter,
                variablePrefix: getterVariablePrefix,
                parameterList: [],
                effectSpecifiers: effectSpecifiers
            )
        } else {
            get = nil
        }

        let set: PropertyFunction?
        if let setter {
            let setterVariablePrefix = VariablePrefixGenerator.text(for: setter)
            let setterParameterList = setter.signature.parameterClause.parameters

            set = PropertyFunction(
                function: setter,
                variablePrefix: setterVariablePrefix,
                parameterList: setterParameterList,
                effectSpecifiers: nil
            )
        } else {
            set = nil
        }

        return PropertyDeclaration(
            name: propertyName,
            typePrefix: typePrefix,
            storagePrefix: "\(propertyName).",
            variable: variable,
            get: get,
            set: set
        )
    }

    enum PropertyFunctionType {
        case get
        case set
    }

    private static func getPropertyFunction(
        propertyFunctionType: PropertyFunctionType,
        propertyType: TypeSyntax,
        isAsync: Bool,
        isThrowing: Bool
    ) throws -> FunctionDeclSyntax {
        var signature = "func "

        switch propertyFunctionType {
        case .get:
            signature += "get()"
        case .set:
            signature += "set(_ newValue: \(propertyType)"
        }

        if isAsync {
            signature += " async"
        }
        if isThrowing {
            signature += " throws"
        }

        if case .get = propertyFunctionType {
            signature += " -> \(propertyType)"
        }

        return try FunctionDeclSyntax("\(raw: signature) { fatalError(\"Not implemented\") }")
    }

    // swiftlint:disable function_body_length
    static func declaration(for protocolDeclaration: ProtocolDeclSyntax) throws -> StructDeclSyntax {
        let identifier = TokenSyntax.identifier("Mock" + protocolDeclaration.name.text)

        let propertyDeclarations = try protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .map(createGetterSetterPropertyDeclaration)

        let functionDeclarations = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }

        let associatedTypes = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(AssociatedTypeDeclSyntax.self) }

        let genericParameterClause = getGenericParameterClause(associatedTypes: associatedTypes)
        let (comparableAssociatedTypes, equatableAssociatedTypes) =
            AssociatedTypesGenerator.getTypeConformanceAssociatedTypes(
                associatedTypes: associatedTypes
            )

        let typeConformanceProvider = TypeConformanceProvider.get(
            comparableAssociatedTypes: comparableAssociatedTypes,
            equatableAssociatedTypes: equatableAssociatedTypes
        )

        return try StructDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            name: identifier,
            genericParameterClause: genericParameterClause,
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: protocolDeclaration.name)
                )

                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "Sendable")
                )

                InheritedTypeSyntax(
                    type: IdentifierTypeSyntax(name: "VerifiableSmock")
                )
            },
            memberBlockBuilder: {
                // VerifiableSmock conformance
                try TypeAliasDeclSyntax("public typealias VerifierType = Verifier")

                try FunctionDeclSyntax(
                    "public func getVerifier(mode: VerificationMode, sourceLocation: SourceLocation) -> Verifier {"
                ) {
                    ReturnStmtSyntax(
                        expression: ExprSyntax(
                            "Verifier(state: self.state, mode: mode, sourceLocation: sourceLocation)"
                        )
                    )
                }

                try InitializerDeclSyntax("public init(expectations: consuming Expectations = .init()) { ") {
                    ExprSyntax(
                        """
                        self.state = .init(expectedResponses: .init(expectations: expectations))
                        """
                    )
                }

                for propertyDeclaration in propertyDeclarations {
                    let propertyFunctionDeclarations = [
                        propertyDeclaration.get?.function, propertyDeclaration.set?.function,
                    ].compactMap { $0 }

                    try StorageGenerator.expectationsDeclaration(
                        functionDeclarations: propertyFunctionDeclarations,
                        typePrefix: propertyDeclaration.typePrefix,
                        typeConformanceProvider: typeConformanceProvider
                    )

                    try StorageGenerator.expectedResponsesDeclaration(
                        functionDeclarations: propertyFunctionDeclarations,
                        typePrefix: propertyDeclaration.typePrefix
                    )

                    try StorageGenerator.receivedInvocationsDeclaration(
                        functionDeclarations: propertyFunctionDeclarations,
                        typePrefix: propertyDeclaration.typePrefix
                    )

                    try VerifierGenerator.verifierStructDeclaration(
                        functionDeclarations: propertyFunctionDeclarations,
                        typePrefix: propertyDeclaration.typePrefix,
                        storagePrefix: propertyDeclaration.storagePrefix,
                        typeConformanceProvider: typeConformanceProvider
                    )

                    if let get = propertyDeclaration.get {
                        try FieldOptionsGenerator.fieldOptionsClassDeclaration(
                            variablePrefix: get.variablePrefix,
                            functionSignature: get.function.signature,
                            typePrefix: propertyDeclaration.typePrefix
                        )

                        try ExpectedResponseGenerator.expectedResponseEnumDeclaration(
                            typePrefix: propertyDeclaration.typePrefix,
                            variablePrefix: get.variablePrefix,
                            functionSignature: get.function.signature
                        )
                    }

                    if let set = propertyDeclaration.set {
                        try FieldOptionsGenerator.fieldOptionsClassDeclaration(
                            variablePrefix: set.variablePrefix,
                            functionSignature: set.function.signature,
                            typePrefix: propertyDeclaration.typePrefix
                        )

                        try ExpectedResponseGenerator.expectedResponseEnumDeclaration(
                            typePrefix: propertyDeclaration.typePrefix,
                            variablePrefix: set.variablePrefix,
                            functionSignature: set.function.signature
                        )

                        if let setterInputMatcherStruct = try InputMatcherGenerator.inputMatcherStructDeclaration(
                            variablePrefix: set.variablePrefix,
                            parameterList: set.parameterList,
                            typePrefix: propertyDeclaration.typePrefix,
                            typeConformanceProvider: typeConformanceProvider
                        ) {
                            setterInputMatcherStruct
                        }
                    }

                    try PropertyImplementationGenerator.propertyDeclaration(
                        propertyDeclaration: propertyDeclaration
                    )
                }

                try StorageGenerator.expectationsDeclaration(
                    functionDeclarations: functionDeclarations,
                    propertyDeclarations: propertyDeclarations,
                    typeConformanceProvider: typeConformanceProvider
                )
                try StorageGenerator.expectedResponsesDeclaration(
                    functionDeclarations: functionDeclarations,
                    propertyDeclarations: propertyDeclarations
                )
                try StorageGenerator.receivedInvocationsDeclaration(
                    functionDeclarations: functionDeclarations,
                    propertyDeclarations: propertyDeclarations
                )
                try StorageGenerator.storageDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.stateDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.variableDeclaration()

                try VerifierGenerator.verifierStructDeclaration(
                    functionDeclarations: functionDeclarations,
                    propertyDeclarations: propertyDeclarations,
                    typeConformanceProvider: typeConformanceProvider
                )

                for functionDeclaration in functionDeclarations {
                    let variablePrefix = VariablePrefixGenerator.text(for: functionDeclaration)
                    let parameterList = functionDeclaration.signature.parameterClause.parameters

                    try FieldOptionsGenerator.fieldOptionsClassDeclaration(
                        variablePrefix: variablePrefix,
                        functionSignature: functionDeclaration.signature
                    )
                    try ExpectedResponseGenerator.expectedResponseEnumDeclaration(
                        variablePrefix: variablePrefix,
                        functionSignature: functionDeclaration.signature
                    )

                    // Generate input matcher struct for functions with parameters
                    if let inputMatcherStruct = try InputMatcherGenerator.inputMatcherStructDeclaration(
                        variablePrefix: variablePrefix,
                        parameterList: parameterList,
                        typeConformanceProvider: typeConformanceProvider
                    ) {
                        inputMatcherStruct
                    }

                    try FunctionImplementationGenerator.functionDeclaration(
                        variablePrefix: variablePrefix,
                        functionDeclaration: functionDeclaration
                    )
                }
            }
        )
    }
    // swiftlint:enable function_body_length
}
