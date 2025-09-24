import SwiftParser
import SwiftSyntax
import Testing

@testable import SmockableUtils

struct MacroParameterTests {

    // Helper function for creating AttributeSyntax from strings
    private func createAttribute(_ attributeString: String) -> AttributeSyntax {
        let sourceCode = """
            \(attributeString)                                                                                      
            protocol TestProtocol {}                                                                                
            """

        let sourceFile = Parser.parse(source: sourceCode)

        guard let protocolDecl = sourceFile.statements.first?.item.as(ProtocolDeclSyntax.self),
            let attribute = protocolDecl.attributes.first?.as(AttributeSyntax.self)
        else {
            fatalError("Attribute Not Found")
        }

        return attribute
    }

    @Test("Default parameters are returned when no arguments provided")
    func testDefaultParameters() throws {
        let attribute = createAttribute("@Smock")
        let parameters = try MacroParameterParser.parse(from: attribute)

        #expect(parameters.accessLevel == .default)
        #expect(parameters.preprocessorFlag == nil)
        #expect(parameters.additionalComparableTypes.isEmpty)
        #expect(parameters.additionalEquatableTypes.isEmpty)
    }

    @Test("Single additionalComparableTypes parameter is parsed correctly")
    func testSingleAdditionalComparableTypes() throws {
        let attribute = createAttribute(
            """
            @Smock(additionalComparableTypes: [CustomType.self])
            """
        )
        let parameters = try MacroParameterParser.parse(from: attribute)

        #expect(parameters.additionalComparableTypes.count == 1)
        #expect(
            parameters.additionalComparableTypes.first?.description.trimmingCharacters(in: .whitespaces) == "CustomType"
        )
        #expect(parameters.additionalEquatableTypes.isEmpty)
    }

    @Test("Multiple additionalComparableTypes are parsed correctly")
    func testMultipleAdditionalComparableTypes() throws {
        let attribute = createAttribute(
            """
            @Smock(additionalComparableTypes: [CustomType.self, AnotherType.self, ThirdType.self])
            """
        )
        let parameters = try MacroParameterParser.parse(from: attribute)

        #expect(parameters.additionalComparableTypes.count == 3)
        let typeNames = parameters.additionalComparableTypes.map { $0.description.trimmingCharacters(in: .whitespaces) }
        #expect(typeNames == ["CustomType", "AnotherType", "ThirdType"])
        #expect(parameters.additionalEquatableTypes.isEmpty)
    }

    @Test("Single additionalEquatableTypes parameter is parsed correctly")
    func testSingleAdditionalEquatableTypes() throws {
        let attribute = createAttribute(
            """
            @Smock(additionalEquatableTypes: [CustomType.self])
            """
        )
        let parameters = try MacroParameterParser.parse(from: attribute)

        #expect(parameters.additionalComparableTypes.isEmpty)
        #expect(parameters.additionalEquatableTypes.count == 1)
        #expect(
            parameters.additionalEquatableTypes.first?.description.trimmingCharacters(in: .whitespaces) == "CustomType"
        )
    }

    @Test("Multiple additionalEquatableTypes are parsed correctly")
    func testMultipleAdditionalEquatableTypes() throws {
        let attribute = createAttribute(
            """
            @Smock(additionalEquatableTypes: [CustomType.self, AnotherType.self])
            """
        )
        let parameters = try MacroParameterParser.parse(from: attribute)

        #expect(parameters.additionalComparableTypes.isEmpty)
        #expect(parameters.additionalEquatableTypes.count == 2)
        let typeNames = parameters.additionalEquatableTypes.map { $0.description.trimmingCharacters(in: .whitespaces) }
        #expect(typeNames == ["CustomType", "AnotherType"])
    }

    @Test("Both additional type parameters are parsed correctly")
    func testBothAdditionalTypeParameters() throws {
        let attribute = createAttribute(
            """
            @Smock(
                additionalComparableTypes: [ComparableType1.self, ComparableType2.self],
                additionalEquatableTypes: [EquatableType1.self, EquatableType2.self]
            )
            """
        )
        let parameters = try MacroParameterParser.parse(from: attribute)

        #expect(parameters.additionalComparableTypes.count == 2)
        #expect(parameters.additionalEquatableTypes.count == 2)
        let comparableTypeNames = parameters.additionalComparableTypes.map {
            $0.description.trimmingCharacters(in: .whitespaces)
        }
        let equatableTypeNames = parameters.additionalEquatableTypes.map {
            $0.description.trimmingCharacters(in: .whitespaces)
        }
        #expect(comparableTypeNames == ["ComparableType1", "ComparableType2"])
        #expect(equatableTypeNames == ["EquatableType1", "EquatableType2"])
    }

    @Test("All parameters together are parsed correctly")
    func testAllParametersTogether() throws {
        let attribute = createAttribute(
            """
            @Smock(
                accessLevel: .internal,
                preprocessorFlag: "DEBUG",
                additionalComparableTypes: [CustomID.self],
                additionalEquatableTypes: [UserProfile.self]
            )
            """
        )
        let parameters = try MacroParameterParser.parse(from: attribute)

        #expect(parameters.accessLevel == .internal)
        #expect(parameters.preprocessorFlag == "DEBUG")
        #expect(parameters.additionalComparableTypes.count == 1)
        #expect(parameters.additionalEquatableTypes.count == 1)
        #expect(
            parameters.additionalComparableTypes.first?.description.trimmingCharacters(in: .whitespaces) == "CustomID"
        )
        #expect(
            parameters.additionalEquatableTypes.first?.description.trimmingCharacters(in: .whitespaces) == "UserProfile"
        )
    }

    @Test("Empty arrays are parsed correctly")
    func testEmptyArrays() throws {
        let attribute = createAttribute(
            """
            @Smock(
                additionalComparableTypes: [],
                additionalEquatableTypes: []
            )
            """
        )
        let parameters = try MacroParameterParser.parse(from: attribute)

        #expect(parameters.additionalComparableTypes.isEmpty)
        #expect(parameters.additionalEquatableTypes.isEmpty)
    }

    @Test("Invalid array syntax throws error")
    func testInvalidArraySyntax() throws {
        let attribute = createAttribute(
            """
            @Smock(additionalComparableTypes: "NotAnArray")
            """
        )

        #expect(throws: SmockDiagnostic.invalidMacroArguments) {
            try MacroParameterParser.parse(from: attribute)
        }
    }

    @Test("Non-type array elements throw error")
    func testNonTypeArrayElements() throws {
        let attribute = createAttribute(
            """
            @Smock(additionalComparableTypes: [123, CustomType.self])
            """
        )

        #expect(throws: SmockDiagnostic.invalidMacroArguments) {
            try MacroParameterParser.parse(from: attribute)
        }
    }

    @Test("Complex type names are parsed correctly")
    func testComplexTypeNames() throws {
        let attribute = createAttribute(
            """
            @Smock(
                additionalComparableTypes: [MyModule.CustomType.self, ThirdParty.SomeType.self],
                additionalEquatableTypes: [Foundation.CustomStruct.self]
            )
            """
        )
        let parameters = try MacroParameterParser.parse(from: attribute)

        #expect(parameters.additionalComparableTypes.count == 2)
        #expect(parameters.additionalEquatableTypes.count == 1)
        let comparableTypeNames = parameters.additionalComparableTypes.map {
            $0.description.trimmingCharacters(in: .whitespaces)
        }
        let equatableTypeNames = parameters.additionalEquatableTypes.map {
            $0.description.trimmingCharacters(in: .whitespaces)
        }
        #expect(comparableTypeNames == ["MyModule.CustomType", "ThirdParty.SomeType"])
        #expect(equatableTypeNames == ["Foundation.CustomStruct"])
    }
}
