import Testing
@testable import SmockableUtils

struct TypeConformanceProviderTests {
    
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
}
