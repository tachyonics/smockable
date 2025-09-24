import SwiftSyntax
import Testing

@testable import SmockableUtils

struct TypeConformanceProviderTests {

    // Helper function to create TypeSyntax from string
    private func createTypeSyntax(_ typeString: String) -> TypeSyntax {
        if typeString.contains(".") {
            let components = typeString.split(separator: ".")
            if components.count == 2 {
                let memberType = MemberTypeSyntax(
                    baseType: TypeSyntax(IdentifierTypeSyntax(name: .identifier(String(components[0])))),
                    name: .identifier(String(components[1]))
                )
                return TypeSyntax(memberType)
            }
        }
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier(typeString)))
    }

    // MARK: - Basic Type Tests

    @Test
    func testBuiltInComparableTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("String") == .comparableAndEquatable)
        #expect(provider("Int") == .comparableAndEquatable)
        #expect(provider("Double") == .comparableAndEquatable)
        #expect(provider("Date") == .comparableAndEquatable)
    }

    @Test
    func testBuiltInEquatableOnlyTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Bool") == .onlyEquatable)
        #expect(provider("UUID") == .onlyEquatable)
        #expect(provider("URL") == .onlyEquatable)
        #expect(provider("Data") == .onlyEquatable)
    }

    @Test
    func testUnknownTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("CustomType") == .neitherComparableNorEquatable)
        #expect(provider("SomeUnknownClass") == .neitherComparableNorEquatable)
    }

    // MARK: - Optional Type Tests

    @Test
    func testOptionalTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("String?") == .comparableAndEquatable)
        #expect(provider("Int?") == .comparableAndEquatable)
        #expect(provider("Bool?") == .onlyEquatable)
        #expect(provider("UUID?") == .onlyEquatable)
        #expect(provider("CustomType?") == .neitherComparableNorEquatable)
    }

    // MARK: - Array Type Tests - Shorthand Syntax [T]

    @Test
    func testArrayShorthandSyntaxComparable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[String]") == .onlyEquatable)
        #expect(provider("[Int]") == .onlyEquatable)
        #expect(provider("[Double]") == .onlyEquatable)
    }

    @Test
    func testArrayShorthandSyntaxEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[Bool]") == .onlyEquatable)
        #expect(provider("[UUID]") == .onlyEquatable)
    }

    @Test
    func testArrayShorthandSyntaxNonEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[CustomType]") == .neitherComparableNorEquatable)
    }

    @Test
    func testOptionalArrayShorthandSyntax() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[String]?") == .onlyEquatable)
        #expect(provider("[Bool]?") == .onlyEquatable)
        #expect(provider("[CustomType]?") == .neitherComparableNorEquatable)
    }

    // MARK: - Array Type Tests - Full Syntax Array<T>

    @Test
    func testArrayFullSyntaxComparable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Array<String>") == .onlyEquatable)
        #expect(provider("Array<Int>") == .onlyEquatable)
        #expect(provider("Array<Double>") == .onlyEquatable)
    }

    @Test
    func testArrayFullSyntaxEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Array<Bool>") == .onlyEquatable)
        #expect(provider("Array<UUID>") == .onlyEquatable)
    }

    @Test
    func testArrayFullSyntaxNonEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Array<CustomType>") == .neitherComparableNorEquatable)
    }

    @Test
    func testOptionalArrayFullSyntax() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Array<String>?") == .onlyEquatable)
        #expect(provider("Array<Bool>?") == .onlyEquatable)
        #expect(provider("Array<CustomType>?") == .neitherComparableNorEquatable)
    }

    // MARK: - Dictionary Type Tests - Shorthand Syntax [K: V]

    @Test
    func testDictionaryShorthandSyntaxBothEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[String: String]") == .onlyEquatable)
        #expect(provider("[String: Int]") == .onlyEquatable)
        #expect(provider("[Int: Bool]") == .onlyEquatable)
        #expect(provider("[String: UUID]") == .onlyEquatable)
    }

    @Test
    func testDictionaryShorthandSyntaxKeyNotEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[CustomType: String]") == .neitherComparableNorEquatable)
        #expect(provider("[CustomType: Bool]") == .neitherComparableNorEquatable)
    }

    @Test
    func testDictionaryShorthandSyntaxValueNotEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[String: CustomType]") == .neitherComparableNorEquatable)
        #expect(provider("[Int: CustomType]") == .neitherComparableNorEquatable)
    }

    @Test
    func testOptionalDictionaryShorthandSyntax() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[String: String]?") == .onlyEquatable)
        #expect(provider("[String: CustomType]?") == .neitherComparableNorEquatable)
    }

    // MARK: - Dictionary Type Tests - Full Syntax Dictionary<K, V>

    @Test
    func testDictionaryFullSyntaxBothEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Dictionary<String, String>") == .onlyEquatable)
        #expect(provider("Dictionary<String, Int>") == .onlyEquatable)
        #expect(provider("Dictionary<Int, Bool>") == .onlyEquatable)
        #expect(provider("Dictionary<String, UUID>") == .onlyEquatable)
    }

    @Test
    func testDictionaryFullSyntaxKeyNotEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Dictionary<CustomType, String>") == .neitherComparableNorEquatable)
        #expect(provider("Dictionary<CustomType, Bool>") == .neitherComparableNorEquatable)
    }

    @Test
    func testDictionaryFullSyntaxValueNotEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Dictionary<String, CustomType>") == .neitherComparableNorEquatable)
        #expect(provider("Dictionary<Int, CustomType>") == .neitherComparableNorEquatable)
    }

    @Test
    func testOptionalDictionaryFullSyntax() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Dictionary<String, String>?") == .onlyEquatable)
        #expect(provider("Dictionary<String, CustomType>?") == .neitherComparableNorEquatable)
    }

    // MARK: - Set Type Tests

    @Test
    func testSetTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Set<String>") == .onlyEquatable)
        #expect(provider("Set<Int>") == .onlyEquatable)
        #expect(provider("Set<Bool>") == .onlyEquatable)
        #expect(provider("Set<UUID>") == .onlyEquatable)
        #expect(provider("Set<CustomType>") == .neitherComparableNorEquatable)
    }

    @Test
    func testOptionalSetTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Set<String>?") == .onlyEquatable)
        #expect(provider("Set<CustomType>?") == .neitherComparableNorEquatable)
    }

    // MARK: - Nested Collection Tests

    @Test
    func testNestedArraysShorthand() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[[String]]") == .onlyEquatable)
        #expect(provider("[[Int]]") == .onlyEquatable)
        #expect(provider("[[CustomType]]") == .neitherComparableNorEquatable)
    }

    @Test
    func testArrayOfDictionariesShorthandStackBasedParsing() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        // This test specifically verifies the stack-based parsing fix
        // Previously failed because the simple .contains(":") check would
        // incorrectly identify "[[String: String]]" as a dictionary
        #expect(provider("[[String: String]]") == .onlyEquatable)
        #expect(provider("[[String: Int]]") == .onlyEquatable)
        #expect(provider("[[Int: Bool]]") == .onlyEquatable)
        #expect(provider("[[String: CustomType]]") == .neitherComparableNorEquatable)

        // Test more complex nested cases
        #expect(provider("[[[String: String]]]") == .onlyEquatable)
        #expect(provider("[[String: [String: String]]]") == .onlyEquatable)
    }

    @Test
    func testNestedArraysFullSyntax() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Array<Array<String>>") == .onlyEquatable)
        #expect(provider("Array<Array<Int>>") == .onlyEquatable)
        #expect(provider("Array<Array<CustomType>>") == .neitherComparableNorEquatable)
    }

    @Test
    func testArrayOfDictionariesShorthand() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[[String: String]]") == .onlyEquatable)
        #expect(provider("[[String: Int]]") == .onlyEquatable)
        #expect(provider("[[String: CustomType]]") == .neitherComparableNorEquatable)
    }

    @Test
    func testArrayOfDictionariesFullSyntax() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Array<Dictionary<String, String>>") == .onlyEquatable)
        #expect(provider("Array<Dictionary<String, Int>>") == .onlyEquatable)
        #expect(provider("Array<Dictionary<String, CustomType>>") == .neitherComparableNorEquatable)
    }

    @Test
    func testDictionaryOfArraysShorthand() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("[String: [String]]") == .onlyEquatable)
        #expect(provider("[String: [Int]]") == .onlyEquatable)
        #expect(provider("[String: [CustomType]]") == .neitherComparableNorEquatable)
    }

    @Test
    func testDictionaryOfArraysFullSyntax() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider("Dictionary<String, Array<String>>") == .onlyEquatable)
        #expect(provider("Dictionary<String, Array<Int>>") == .onlyEquatable)
        #expect(provider("Dictionary<String, Array<CustomType>>") == .neitherComparableNorEquatable)
    }

    // MARK: - Mixed Syntax Tests

    @Test
    func testMixedSyntaxCombinations() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        // Array shorthand with Dictionary full syntax
        #expect(provider("[Dictionary<String, String>]") == .onlyEquatable)
        #expect(provider("[Dictionary<String, CustomType>]") == .neitherComparableNorEquatable)

        // Dictionary shorthand with Array full syntax
        #expect(provider("[String: Array<String>]") == .onlyEquatable)
        #expect(provider("[String: Array<CustomType>]") == .neitherComparableNorEquatable)

        // Full syntax combinations
        #expect(provider("Array<Dictionary<String, Array<String>>>") == .onlyEquatable)
        #expect(provider("Dictionary<String, Array<Dictionary<String, String>>>") == .onlyEquatable)
    }

    // MARK: - Associated Types Tests

    @Test
    func testAssociatedTypesComparable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: ["MyComparableType", "AnotherComparableType"],
            equatableAssociatedTypes: []
        )

        #expect(provider("MyComparableType") == .comparableAndEquatable)
        #expect(provider("AnotherComparableType") == .comparableAndEquatable)
        #expect(provider("[MyComparableType]") == .onlyEquatable)
        #expect(provider("Array<AnotherComparableType>") == .onlyEquatable)
    }

    @Test
    func testAssociatedTypesEquatable() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: ["MyEquatableType", "AnotherEquatableType"]
        )

        #expect(provider("MyEquatableType") == .onlyEquatable)
        #expect(provider("AnotherEquatableType") == .onlyEquatable)
        #expect(provider("[MyEquatableType]") == .onlyEquatable)
        #expect(provider("Dictionary<String, AnotherEquatableType>") == .onlyEquatable)
    }

    @Test
    func testAssociatedTypesCombined() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: ["MyComparableType"],
            equatableAssociatedTypes: ["MyEquatableType"]
        )

        #expect(provider("MyComparableType") == .comparableAndEquatable)
        #expect(provider("MyEquatableType") == .onlyEquatable)
        #expect(provider("[MyComparableType: MyEquatableType]") == .onlyEquatable)
        #expect(provider("Dictionary<MyComparableType, MyEquatableType>") == .onlyEquatable)
    }

    // MARK: - Edge Cases and Whitespace Tests

    @Test
    func testWhitespaceHandling() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        #expect(provider(" String ") == .comparableAndEquatable)
        #expect(provider(" [String] ") == .onlyEquatable)
        #expect(provider(" Array<String> ") == .onlyEquatable)
        #expect(provider(" [String: Int] ") == .onlyEquatable)
        #expect(provider(" Dictionary<String, Int> ") == .onlyEquatable)
        #expect(provider(" Set<String> ") == .onlyEquatable)
    }

    @Test
    func testComplexNestedGenericsParsing() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: []
        )

        // Test complex generic parsing doesn't break
        #expect(provider("Dictionary<Array<String>, Dictionary<String, Int>>") == .onlyEquatable)
        #expect(provider("Array<Dictionary<String, Array<String>>>") == .onlyEquatable)
        #expect(provider("Dictionary<String, Array<Dictionary<String, String>>>") == .onlyEquatable)
    }

    // MARK: - Additional Types Tests

    @Test
    func testAdditionalComparableTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: [],
            additionalComparableTypes: [createTypeSyntax("CustomID"), createTypeSyntax("Timestamp")],
            additionalEquatableTypes: []
        )

        #expect(provider("CustomID") == .comparableAndEquatable)
        #expect(provider("Timestamp") == .comparableAndEquatable)
    }

    @Test
    func testAdditionalEquatableTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: [],
            additionalComparableTypes: [],
            additionalEquatableTypes: [createTypeSyntax("UserProfile"), createTypeSyntax("Settings")]
        )

        #expect(provider("UserProfile") == .onlyEquatable)
        #expect(provider("Settings") == .onlyEquatable)
    }

    @Test
    func testAdditionalTypesWithBuiltInTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: [],
            additionalComparableTypes: [createTypeSyntax("CustomID")],
            additionalEquatableTypes: [createTypeSyntax("UserProfile")]
        )

        // Built-in comparable types still work
        #expect(provider("String") == .comparableAndEquatable)
        #expect(provider("Int") == .comparableAndEquatable)

        // Built-in equatable-only types still work
        #expect(provider("Bool") == .onlyEquatable)
        #expect(provider("UUID") == .onlyEquatable)

        // Additional types work as expected
        #expect(provider("CustomID") == .comparableAndEquatable)
        #expect(provider("UserProfile") == .onlyEquatable)
    }

    @Test
    func testAdditionalTypesWithAssociatedTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: ["AssociatedComparable"],
            equatableAssociatedTypes: ["AssociatedEquatable"],
            additionalComparableTypes: [createTypeSyntax("CustomID")],
            additionalEquatableTypes: [createTypeSyntax("UserProfile")]
        )

        // Associated types work
        #expect(provider("AssociatedComparable") == .comparableAndEquatable)
        #expect(provider("AssociatedEquatable") == .onlyEquatable)

        // Additional types work
        #expect(provider("CustomID") == .comparableAndEquatable)
        #expect(provider("UserProfile") == .onlyEquatable)
    }

    @Test
    func testAdditionalComparableTypesOverrideBuiltIn() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: [],
            additionalComparableTypes: [createTypeSyntax("Bool")],  // Bool is normally equatable-only
            additionalEquatableTypes: []
        )

        // Bool should now be comparable and equatable due to additionalComparableTypes
        #expect(provider("Bool") == .comparableAndEquatable)
    }

    @Test
    func testCollectionsWithAdditionalTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: [],
            additionalComparableTypes: [createTypeSyntax("CustomID")],
            additionalEquatableTypes: [createTypeSyntax("UserProfile")]
        )

        // Arrays with additional types
        #expect(provider("Array<CustomID>") == .onlyEquatable)
        #expect(provider("Array<UserProfile>") == .onlyEquatable)
        #expect(provider("[CustomID]") == .onlyEquatable)
        #expect(provider("[UserProfile]") == .onlyEquatable)

        // Sets with additional types
        #expect(provider("Set<CustomID>") == .onlyEquatable)
        #expect(provider("Set<UserProfile>") == .onlyEquatable)

        // Dictionaries with additional types
        #expect(provider("Dictionary<CustomID, UserProfile>") == .onlyEquatable)
        #expect(provider("[CustomID: UserProfile]") == .onlyEquatable)
    }

    @Test
    func testComplexNestedTypesWithAdditionalTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: [],
            additionalComparableTypes: [createTypeSyntax("CustomID")],
            additionalEquatableTypes: [createTypeSyntax("UserProfile")]
        )

        // Nested collections
        #expect(provider("Array<Array<CustomID>>") == .onlyEquatable)
        #expect(provider("[[CustomID]]") == .onlyEquatable)
        #expect(provider("Dictionary<CustomID, Array<UserProfile>>") == .onlyEquatable)
        #expect(provider("[CustomID: [UserProfile]]") == .onlyEquatable)

        // Optional types
        #expect(provider("CustomID?") == .comparableAndEquatable)
        #expect(provider("UserProfile?") == .onlyEquatable)
        #expect(provider("Array<CustomID>?") == .onlyEquatable)
    }

    @Test
    func testModuleQualifiedTypeNames() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: [],
            additionalComparableTypes: [
                createTypeSyntax("MyModule.CustomID"), createTypeSyntax("ThirdParty.SomeType"),
            ],
            additionalEquatableTypes: [createTypeSyntax("Foundation.CustomStruct")]
        )

        #expect(provider("MyModule.CustomID") == .comparableAndEquatable)
        #expect(provider("ThirdParty.SomeType") == .comparableAndEquatable)
        #expect(provider("Foundation.CustomStruct") == .onlyEquatable)

        // Collections with module-qualified types
        #expect(provider("Array<MyModule.CustomID>") == .onlyEquatable)
        #expect(provider("[ThirdParty.SomeType: Foundation.CustomStruct]") == .onlyEquatable)
    }

    @Test
    func testUnknownTypesRemainUnchangedWithAdditionalTypes() {
        let provider = TypeConformanceProvider.get(
            comparableAssociatedTypes: [],
            equatableAssociatedTypes: [],
            additionalComparableTypes: [createTypeSyntax("CustomID")],
            additionalEquatableTypes: [createTypeSyntax("UserProfile")]
        )

        // Unknown types should still be neither comparable nor equatable
        #expect(provider("UnknownType") == .neitherComparableNorEquatable)
        #expect(provider("SomeRandomType") == .neitherComparableNorEquatable)

        // Collections of unknown types
        #expect(provider("Array<UnknownType>") == .neitherComparableNorEquatable)
        #expect(provider("[String: UnknownType]") == .neitherComparableNorEquatable)
    }
}
