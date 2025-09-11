import Foundation
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

    static func getComparableAssociatedTypes(
        associatedTypes: [AssociatedTypeDeclSyntax]
    )
        -> [String]
    {
        if !associatedTypes.isEmpty {
            return associatedTypes.filter { associatedType in
                let filteredAssociatedTypes = associatedType.inheritanceClause?.inheritedTypes.filter { syntax in
                    let components = syntax.description.split(separator: "&")
                    let trimmedComponents = components.map {
                        String($0.trimmingCharacters(in: .whitespacesAndNewlines))
                    }

                    return Set(trimmedComponents).contains("Comparable")
                }

                return !(filteredAssociatedTypes ?? []).isEmpty
            }.map { $0.name.description }
        } else {
            return []
        }
    }

    static func createGetterSetterFunctions(for variable: VariableDeclSyntax) throws -> (String, FunctionDeclSyntax, FunctionDeclSyntax) {
        guard let binding = variable.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
              let type = binding.typeAnnotation?.type else {
            throw MacroError.invalidPropertyDeclaration
        }
        
        let propertyName = identifier.text
        let propertyType = type
        
        // Parse accessor block to determine async/throws modifiers
        var isAsync = false
        var isThrowing = false
        var hasGetter = false
        var hasSetter = false
        
        if let accessorBlock = binding.accessorBlock {
            switch accessorBlock.accessors {
            case .accessors(let accessorList):
                for accessor in accessorList {
                    switch accessor.accessorSpecifier.tokenKind {
                    case .keyword(.get):
                        hasGetter = true
                        isAsync = accessor.effectSpecifiers?.asyncSpecifier != nil
                        isThrowing = accessor.effectSpecifiers?.throwsClause != nil
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
        
        // Create getter function: func get() async throws -> PropertyType
        let getterName = "get"
        var getterSignature = "func \(getterName)()"
        
        if isAsync && isThrowing {
            getterSignature += " async throws"
        } else if isAsync {
            getterSignature += " async"
        } else if isThrowing {
            getterSignature += " throws"
        }
        
        getterSignature += " -> \(propertyType)"
        
        let getter = try FunctionDeclSyntax("\(raw: getterSignature) { fatalError(\"Not implemented\") }")
        
        // Create setter function: func set(_ value: PropertyType) async throws
        let setterName = "set"
        var setterSignature = "func \(setterName)(_ value: \(propertyType))"
        
        if isAsync && isThrowing {
            setterSignature += " async throws"
        } else if isAsync {
            setterSignature += " async"
        } else if isThrowing {
            setterSignature += " throws"
        }
        
        let setter = try FunctionDeclSyntax("\(raw: setterSignature) { fatalError(\"Not implemented\") }")
        
        return (propertyName, getter, setter)
    }

    // swiftlint:disable function_body_length
    static func declaration(for protocolDeclaration: ProtocolDeclSyntax) throws -> StructDeclSyntax {
        let identifier = TokenSyntax.identifier("Mock" + protocolDeclaration.name.text)

        let propertyDeclarations = try protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(VariableDeclSyntax.self) }
            .map { variable in
                let (name, getter, setter) = try createGetterSetterFunctions(for: variable)
                let typePrefix = "\(name.capitalizingComponentsFirstLetter())_"
                return PropertyDeclaration(name: name, typePrefix: typePrefix, variable: variable, getterFunction: getter, setterFunction: setter)
            }

        let functionDeclarations = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(FunctionDeclSyntax.self) }

        let associatedTypes = protocolDeclaration.memberBlock.members
            .compactMap { $0.decl.as(AssociatedTypeDeclSyntax.self) }

        let genericParameterClause = getGenericParameterClause(associatedTypes: associatedTypes)
        let comparableAssociatedTypes = getComparableAssociatedTypes(associatedTypes: associatedTypes)

        func isComparableProvider(baseType: String) -> Bool {
            let builtInComparableTypes = [
                "String", "Int", "Int8", "Int16", "Int32", "Int64", "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
                "Float", "Double", "Character", "Date",
            ]
            let comparableTypes = Set(comparableAssociatedTypes + builtInComparableTypes)
            return comparableTypes.contains(baseType)
        }

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
                    let getterVariablePrefix = VariablePrefixGenerator.text(for: propertyDeclaration.getterFunction)
                    let setterVariablePrefix = VariablePrefixGenerator.text(for: propertyDeclaration.setterFunction)
                    let setterParameterList = propertyDeclaration.setterFunction.signature.parameterClause.parameters
                    
                    let propertyFunctionDeclarations = [propertyDeclaration.getterFunction, propertyDeclaration.setterFunction]
                    
                    try StorageGenerator.expectationsDeclaration(
                        functionDeclarations: propertyFunctionDeclarations,
                        typePrefix: propertyDeclaration.typePrefix,
                        isComparableProvider: isComparableProvider
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
                        storagePrefix: "\(propertyDeclaration.name).",
                        isComparableProvider: isComparableProvider
                    )
                    
                    try FieldOptionsGenerator.fieldOptionsClassDeclaration(
                        variablePrefix: getterVariablePrefix,
                        functionSignature: propertyDeclaration.getterFunction.signature,
                        typePrefix: propertyDeclaration.typePrefix
                    )
                    try FieldOptionsGenerator.fieldOptionsClassDeclaration(
                        variablePrefix: setterVariablePrefix,
                        functionSignature: propertyDeclaration.setterFunction.signature,
                        typePrefix: propertyDeclaration.typePrefix
                    )
                    
                    try ExpectedResponseGenerator.expectedResponseEnumDeclaration(
                        typePrefix: propertyDeclaration.typePrefix,
                        variablePrefix: getterVariablePrefix,
                        functionSignature: propertyDeclaration.getterFunction.signature
                    )
                    try ExpectedResponseGenerator.expectedResponseEnumDeclaration(
                        typePrefix: propertyDeclaration.typePrefix,
                        variablePrefix: setterVariablePrefix,
                        functionSignature: propertyDeclaration.setterFunction.signature
                    )
                    
                    if let setterInputMatcherStruct = try InputMatcherGenerator.inputMatcherStructDeclaration(
                        variablePrefix: setterVariablePrefix,
                        parameterList: setterParameterList,
                        typePrefix: propertyDeclaration.typePrefix,
                        isComparableProvider: isComparableProvider
                    ) {
                        setterInputMatcherStruct
                    }
                    
                    try VariablesImplementationGenerator.variablesDeclarations(
                        protocolVariableDeclaration: propertyDeclaration.variable
                    )
                }

                try StorageGenerator.expectationsDeclaration(
                    functionDeclarations: functionDeclarations,
                    propertyDeclarations: propertyDeclarations,
                    isComparableProvider: isComparableProvider
                )
                try StorageGenerator.expectedResponsesDeclaration(
                    functionDeclarations: functionDeclarations,
                    propertyDeclarations: propertyDeclarations,
                )
                try StorageGenerator.receivedInvocationsDeclaration(
                    functionDeclarations: functionDeclarations,
                    propertyDeclarations: propertyDeclarations,
                )
                try StorageGenerator.storageDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.stateDeclaration(functionDeclarations: functionDeclarations)
                try StorageGenerator.variableDeclaration()

                try VerifierGenerator.verifierStructDeclaration(
                    functionDeclarations: functionDeclarations,
                    propertyDeclarations: propertyDeclarations,
                    isComparableProvider: isComparableProvider
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
                        isComparableProvider: isComparableProvider
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
