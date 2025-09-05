import Foundation
import Smockable
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Smock
public protocol Service1Protocol {
  func initialize(name: String, secondName: String?) async -> String
}

struct CompariableInput: Equatable {
  let name: String
  let secondName: String?
}

struct SmockableTests {
  @Test
  func testMacro() async {
    let expectedReturnValue1 = "ReturnValue1"
    let expectedReturnValue2 = "ReturnValue2"

    var expectations = MockService1Protocol.Expectations()
    // expectation for first call
    when(expectations.initialize(name: .any, secondName: .any), useValue: expectedReturnValue1)
    // expectation for next two calls
    when(expectations.initialize(name: .any, secondName: .any), times: 2) { name, secondName in
      "\(name)_\(secondName ?? "empty")"
    }
    // expectation for final two calls
    when(
      expectations.initialize(name: .any, secondName: .any), times: 2,
      useValue: expectedReturnValue2)

    // create the mock; no more expectations can be added to the mock
    let mock = MockService1Protocol(expectations: expectations)

    // perform some operations on the mock
    let returnValue1 = await mock.initialize(name: "Name1", secondName: "SecondName1")
    let returnValue2 = await mock.initialize(name: "Name2", secondName: "SecondName2")
    let returnValue3 = await mock.initialize(name: "Name3", secondName: "SecondName3")
    let returnValue4 = await mock.initialize(name: "Name3", secondName: "SecondName3")
    let returnValue5 = await mock.initialize(name: "Name3", secondName: "SecondName3")

    // query the current state of the mock
    let callCount = await mock.__verify.initialize_name_secondName.callCount
    let inputs: [CompariableInput] = await mock.__verify.initialize_name_secondName.receivedInputs
      .map { .init(name: $0.name, secondName: $0.secondName) }

    // verify that the current state of the mock is as expected
    #expect(expectedReturnValue1 == returnValue1)
    #expect("Name2_SecondName2" == returnValue2)
    #expect("Name3_SecondName3" == returnValue3)
    #expect(expectedReturnValue2 == returnValue4)
    #expect(expectedReturnValue2 == returnValue5)
    #expect(5 == callCount)
    #expect(
      inputs == [
        .init(name: "Name1", secondName: "SecondName1"),
        .init(name: "Name2", secondName: "SecondName2"),
        .init(name: "Name3", secondName: "SecondName3"),
        .init(name: "Name3", secondName: "SecondName3"),
        .init(name: "Name3", secondName: "SecondName3"),
      ])
  }

  @Smock
  protocol WeatherService {
    func getCurrentTemperature(for city: String) async throws -> Double
    func getForecast(for city: String, days: Int) async throws -> [WeatherDay]
  }

  enum WeatherError: Error {
    case serviceUnavailable
    case cityNotFound
  }

  struct WeatherDay {
    let date: Date
    let temperature: Double
    let condition: String
  }

  @Test func getCurrentTemperature() async throws {
    // 1. Create expectations
    var expectations = MockWeatherService.Expectations()

    // 2. Configure what the mock should return
    when(expectations.getCurrentTemperature(for: .any), useValue: 22.5)

    // 3. Create the mock
    let mockWeatherService = MockWeatherService(expectations: expectations)

    // 4. Use the mock in your code
    let temperature = try await mockWeatherService.getCurrentTemperature(for: "London")

    // 5. Verify the result
    #expect(temperature == 22.5)

    // 6. Verify the mock was called correctly
    let callCount = await mockWeatherService.__verify.getCurrentTemperature_for.callCount
    let receivedInputs = await mockWeatherService.__verify.getCurrentTemperature_for.receivedInputs

    #expect(callCount == 1)
    #expect(receivedInputs[0] == "London")
  }

  struct WeatherApp<Service: WeatherService> {
    private let weatherService: Service

    init(weatherService: Service) {
      self.weatherService = weatherService
    }

    func displayCurrentWeather(for city: String) async -> String {
      do {
        let temperature = try await weatherService.getCurrentTemperature(for: city)
        return "Current temperature in \(city): \(temperature)°C"
      } catch {
        return "Unable to fetch weather for \(city)"
      }
    }
  }

  @Test func weatherApp_DisplaysTemperature() async {
    var expectations = MockWeatherService.Expectations()
    when(expectations.getCurrentTemperature(for: .any), useValue: 22.5)

    let mockWeatherService = MockWeatherService(expectations: expectations)
    let weatherApp = WeatherApp(weatherService: mockWeatherService)

    let result = await weatherApp.displayCurrentWeather(for: "London")

    #expect(result == "Current temperature in London: 22.5°C")
  }

  @Test func getCurrentTemperature_WhenServiceFails_ThrowsError() async {
    // Configure mock to throw an error
    var expectations = MockWeatherService.Expectations()
    when(expectations.getCurrentTemperature(for: .any), useError: WeatherError.serviceUnavailable)

    let mockWeatherService = MockWeatherService(expectations: expectations)

    // Verify error is thrown
    await #expect(throws: WeatherError.self) {
      try await mockWeatherService.getCurrentTemperature(for: "London")
    }
  }

  @Test func getForecast_MultipleCalls() async throws {
    var expectations = MockWeatherService.Expectations()

    // Configure different responses for different calls
    let londonForecast = [WeatherDay(date: Date(), temperature: 20.0, condition: "Sunny")]
    let parisForecast = [WeatherDay(date: Date(), temperature: 18.0, condition: "Cloudy")]

    when(expectations.getForecast(for: .any, days: .any), useValue: londonForecast)  // First call returns London forecast
    when(expectations.getForecast(for: .any, days: .any), useValue: parisForecast)  // Second call returns Paris forecast

    let mockWeatherService = MockWeatherService(expectations: expectations)

    // Make multiple calls
    let forecast1 = try await mockWeatherService.getForecast(for: "London", days: 5)
    let forecast2 = try await mockWeatherService.getForecast(for: "Paris", days: 3)

    // Verify results
    #expect(forecast1.count == 1)
    #expect(forecast1[0].temperature == 20.0)

    #expect(forecast2.count == 1)
    #expect(forecast2[0].temperature == 18.0)

    // Verify both calls were made
    let callCount = await mockWeatherService.__verify.getForecast_for_days.callCount
    #expect(callCount == 2)
  }

  actor LastCity {
    var value: String?

    func set(_ value: String) {
      self.value = value
    }
  }

  @Test func getTemperature_WithCustomLogic() async throws {
    var expectations = MockWeatherService.Expectations()

    // Use a closure to provide custom logic
    let lastCity = LastCity()
    when(expectations.getCurrentTemperature(for: .any), times: .unbounded) { city in
      await lastCity.set(city)

      switch city {
      case "London":
        return 15.0
      case "Paris":
        return 18.0
      case "New York":
        return 25.0
      default:
        throw WeatherError.cityNotFound
      }
    }

    let mockWeatherService = MockWeatherService(expectations: expectations)

    // Test different cities
    let londonTemp = try await mockWeatherService.getCurrentTemperature(for: "London")
    let parisTemp = try await mockWeatherService.getCurrentTemperature(for: "Paris")

    #expect(londonTemp == 15.0)
    #expect(parisTemp == 18.0)
    await #expect(lastCity.value == "Paris")

    // Test error case
    await #expect(throws: WeatherError.cityNotFound) {
      try await mockWeatherService.getCurrentTemperature(for: "Unknown City")
    }
  }

  struct AccountBalance {
    let value: Double
  }

  struct AccountDetails: Equatable, Hashable, Comparable {
    static func < (lhs: SmockableTests.AccountDetails, rhs: SmockableTests.AccountDetails) -> Bool {
      return lhs.name < rhs.name
    }

    let name: String
  }

  @Smock
  protocol Bank {
    func withdraw(amount: Double) async throws -> AccountBalance
    func getBalance() async -> AccountBalance
    func setAccountDetails(details: AccountDetails) async
  }

  enum BankError: Error {
    case insufficientFunds
  }

  actor MockBankLogic {
    var balance: Double = 1000

    func withdraw(amount: Double) async throws -> AccountBalance {
      guard balance >= amount else {
        throw BankError.insufficientFunds
      }
      balance -= amount
      return AccountBalance(value: balance)
    }

    func getBalance() async -> AccountBalance {
      return AccountBalance(value: balance)
    }
  }

  @Test func getTemperature_WithActorAsLogic() async throws {
    var expectations = MockBank.Expectations()
    let accountDetails = AccountDetails(name: "MyAccount")

    // Use a closure to provide custom logic
    let logic = MockBankLogic()
    when(expectations.withdraw(amount: .any), times: .unbounded, use: logic.withdraw)
    when(expectations.getBalance(), times: .unbounded, use: logic.getBalance)
    successWhen(expectations.setAccountDetails(details: .any))

    let mockBank = MockBank(expectations: expectations)

    // Withdraw some amounts
    await mockBank.setAccountDetails(details: accountDetails)
    let balance1 = try await mockBank.withdraw(amount: 500)
    let balance2 = try await mockBank.withdraw(amount: 200)
    let balance3 = await mockBank.getBalance()

    #expect(balance1.value == 500)
    #expect(balance2.value == 300)
    #expect(balance3.value == 300)

    let receivedInputs = await mockBank.__verify.setAccountDetails_details.receivedInputs
    #expect(receivedInputs[0] == accountDetails)

    // Test error case
    await #expect(throws: BankError.insufficientFunds) {
      try await mockBank.withdraw(amount: 500)
    }
  }

  @Test func setAccountDetails_ConcurrentCalls() async throws {
    var expectations = MockBank.Expectations()

    // Configure the mock to succeed for all setAccountDetails calls
    successWhen(expectations.setAccountDetails(details: .any), times: .unbounded)

    let mockBank = MockBank(expectations: expectations)

    // Create multiple AccountDetails instances
    let accountDetails1 = AccountDetails(name: "Account1")
    let accountDetails2 = AccountDetails(name: "Account2")
    let accountDetails3 = AccountDetails(name: "Account3")
    let accountDetails4 = AccountDetails(name: "Account4")
    let accountDetails5 = AccountDetails(name: "Account5")

    // Make concurrent calls to setAccountDetails
    await withTaskGroup(of: Void.self) { group in
      group.addTask { await mockBank.setAccountDetails(details: accountDetails1) }
      group.addTask { await mockBank.setAccountDetails(details: accountDetails2) }
      group.addTask { await mockBank.setAccountDetails(details: accountDetails3) }
      group.addTask { await mockBank.setAccountDetails(details: accountDetails4) }
      group.addTask { await mockBank.setAccountDetails(details: accountDetails5) }
    }

    // Verify call count
    let callCount = await mockBank.__verify.setAccountDetails_details.callCount
    #expect(callCount == 5)

    // Verify received inputs (order may vary due to concurrency)
    let receivedInputs = await mockBank.__verify.setAccountDetails_details.receivedInputs
    #expect(receivedInputs.count == 5)

    // Create expected set of account details for comparison
    let expectedAccountDetails = Set([
      accountDetails1, accountDetails2, accountDetails3, accountDetails4, accountDetails5,
    ])
    let receivedAccountDetailsSet = Set(receivedInputs)

    // Verify that all expected account details were received (regardless of order)
    #expect(receivedAccountDetailsSet == expectedAccountDetails)

    // Verify each expected account detail appears exactly once
    for expectedDetail in expectedAccountDetails {
      let count = receivedInputs.filter { $0 == expectedDetail }.count
      #expect(
        count == 1,
        "Account detail \(expectedDetail.name) should appear exactly once, but appeared \(count) times"
      )
    }
  }
}
