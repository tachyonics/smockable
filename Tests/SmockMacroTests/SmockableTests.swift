
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

import Smockable
@testable import SmockMacro

@Smock
public protocol Service1Protocol {
    mutating func logout() async
    func initialize(name: String, secondName: String?) async -> String
    func fetchConfig() async throws -> [String: String]
}

struct CompariableInput: Equatable {
    let name: String
    let secondName: String?
}

final class SmockableTests: XCTestCase {
    func testMacro() async {
        let expectedReturnValue1 = "ReturnValue1"
        let expectedReturnValue2 = "ReturnValue2"
        let expectations = MockService1Protocol.Expectations()
        expectations.initialize_name_secondName.value(expectedReturnValue1)
            .value(expectedReturnValue2).times(2)
        let mock = MockService1Protocol(expectations: expectations)

        let returnValue1 = await mock.initialize(name: "Name1", secondName: "SecondName1")
        let returnValue2 = await mock.initialize(name: "Name2", secondName: "SecondName2")
        let returnValue3 = await mock.initialize(name: "Name3", secondName: "SecondName3")
        let callCount = await mock.__verify.initialize_name_secondName.callCount
        let inputs: [CompariableInput] = await mock.__verify.initialize_name_secondName.receivedInputs.map { .init(name: $0.name, secondName: $0.secondName) }

        XCTAssertEqual(expectedReturnValue1, returnValue1)
        XCTAssertEqual(expectedReturnValue2, returnValue2)
        XCTAssertEqual(expectedReturnValue2, returnValue3)
        XCTAssertEqual(3, callCount)
        XCTAssertEqual(inputs, [
            .init(name: "Name1", secondName: "SecondName1"),
            .init(name: "Name2", secondName: "SecondName2"),
            .init(name: "Name3", secondName: "SecondName3")
        ])
    }
}
