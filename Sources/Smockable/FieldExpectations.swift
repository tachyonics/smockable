//
//  FieldExpectations.swift
//  smockable
//

public protocol ErrorableFieldOptionsProtocol: FieldOptionsProtocol {
  func update(error: Swift.Error)
}

public protocol ReturnableFieldOptionsProtocol: FieldOptionsProtocol {
  associatedtype ReturnType

  func update(value: ReturnType)
}

public protocol VoidReturnableFieldOptionsProtocol: FieldOptionsProtocol {

  func success()
}

public protocol FieldOptionsProtocol {
  associatedtype UsingFunctionType

  func update(times: Int?)
  func update(using: UsingFunctionType)
}

public class FieldExpectation<ExpectationsType, ExpectedResponseType, InputMatcherType> {
  let expectedResponse: ExpectedResponseType
  let inputMatcher: InputMatcherType?
  var count: Int?

  init(expectedResponse: ExpectedResponseType, inputMatcher: InputMatcherType?, count: Int? = 1) {
    self.expectedResponse = expectedResponse
    self.inputMatcher = inputMatcher
    self.count = count
  }

  @discardableResult
  public func unboundedTimes() -> Self {
    self.count = nil

    return self
  }

  @discardableResult
  public func times(_ count: Int) -> Self {
    self.count = count

    return self
  }
}
