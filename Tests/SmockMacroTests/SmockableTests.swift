
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
        // create an expecations object used to initialise the mock
        // the expectations object is not thread-safe/sendable
        let expectations = MockService1Protocol.Expectations()
        // indicate that the first time `initialize(name: String, secondName: String?) async -> String` is called,
        // `expectedReturnValue1` should be returned
        // Note that setting an expectation with `.value(_ value:)/.error(_ error:)/.using(_ closure:)` without following
        // it with a `.times(_ times:)/.unboundedTimes()` modifier treats it as if there is an implicit `.times(1)` modifer
        expectations.initialize_name_secondName.value(expectedReturnValue1)
        // indicate that the next two times `initialize(name: String, secondName: String?) async -> String` is called,
        // `expectedReturnValue2` should be returned
            .value(expectedReturnValue2).times(2)
        // create the mock; no more expectations can be added to the mock
        // and the created mock is thread-safe/sendable
        let mock = MockService1Protocol(expectations: expectations)

        // perform some operations on the mock
        let returnValue1 = await mock.initialize(name: "Name1", secondName: "SecondName1")
        let returnValue2 = await mock.initialize(name: "Name2", secondName: "SecondName2")
        let returnValue3 = await mock.initialize(name: "Name3", secondName: "SecondName3")
        
        // query the current state of the mock
        let callCount = await mock.__verify.initialize_name_secondName.callCount
        let inputs: [CompariableInput] = await mock.__verify.initialize_name_secondName.receivedInputs.map { .init(name: $0.name, secondName: $0.secondName) }

        // verify that the current state of the mock is as expected
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
