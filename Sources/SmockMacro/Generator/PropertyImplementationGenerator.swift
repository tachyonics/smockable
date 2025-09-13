import SwiftSyntax
import SwiftSyntaxBuilder

struct PropertyFunction {
    let function: FunctionDeclSyntax
    let variablePrefix: String
    let parameterList: FunctionParameterListSyntax
    let effectSpecifiers: AccessorEffectSpecifiersSyntax?
}

struct PropertyDeclaration {
    let name: String
    let typePrefix: String
    let storagePrefix: String
    let variable: VariableDeclSyntax
    let get: PropertyFunction?
    let set: PropertyFunction?
}

enum PropertyImplementationGenerator {
    @MemberBlockItemListBuilder
    static func propertyDeclaration(
        propertyDeclaration: PropertyDeclaration
    ) throws
        -> MemberBlockItemListSyntax
    {
        let bindings = propertyDeclaration.variable.bindings
        if let binding = bindings.first, bindings.count == 1 {
            //if binding.typeAnnotation?.type.is(OptionalTypeSyntax.self) == true {
            //    let accessorRemovalVisitor = AccessorRemovalVisitor()

            //   accessorRemovalVisitor.visit(propertyDeclaration.variable)
            //} else {
            try self.propertyDeclarationWithGetterAndSetter(
                binding: binding,
                propertyDeclaration: propertyDeclaration
            )
            //}
        } else {
            // As far as I know variable declaration in a protocol should have exactly one binding.
            throw SmockDiagnostic.variableDeclInProtocolWithNotSingleBinding
        }
    }

    private static func propertyDeclarationWithGetterAndSetter(
        binding: PatternBindingSyntax,
        propertyDeclaration: PropertyDeclaration
    )
        throws -> VariableDeclSyntax
    {
        var accessors: AccessorDeclListSyntax = []
        if let get = propertyDeclaration.get {
            accessors.append(
                AccessorDeclSyntax(
                    accessorSpecifier: .keyword(.get),
                    effectSpecifiers: get.effectSpecifiers,
                    body: try FunctionImplementationGenerator.getFunctionBody(
                        variablePrefix: get.variablePrefix,
                        typePrefix: propertyDeclaration.typePrefix,
                        storagePrefix: propertyDeclaration.storagePrefix,
                        functionDeclaration: get.function,
                        parameterList: get.parameterList
                    )
                )
            )
        }
        if let set = propertyDeclaration.set {
            accessors.append(
                AccessorDeclSyntax(
                    accessorSpecifier: .keyword(.set),
                    effectSpecifiers: set.effectSpecifiers,
                    body: try FunctionImplementationGenerator.getFunctionBody(
                        variablePrefix: set.variablePrefix,
                        typePrefix: propertyDeclaration.typePrefix,
                        storagePrefix: propertyDeclaration.storagePrefix,
                        functionDeclaration: set.function,
                        parameterList: set.parameterList
                    )
                )
            )
        }

        return VariableDeclSyntax(
            modifiers: [DeclModifierSyntax(name: "public")],
            bindingSpecifier: .keyword(.var),
            bindings: [
                PatternBindingSyntax(
                    pattern: binding.pattern,
                    typeAnnotation: binding.typeAnnotation,
                    accessorBlock: AccessorBlockSyntax(
                        accessors: .accessors(accessors)
                    )
                )
            ]
        )
    }
}

private class AccessorRemovalVisitor: SyntaxRewriter {
    override func visit(_ node: PatternBindingSyntax) -> PatternBindingSyntax {
        let superResult = super.visit(node)
        return superResult.with(\.accessorBlock, nil)
    }
}
