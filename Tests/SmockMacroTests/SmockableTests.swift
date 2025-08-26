import Foundation
import Smockable
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Smock
public protocol Service1Protocol {
  // mutating func logout() async
  func initialize(name: String, secondName: String?) async -> String
  // func fetchConfig() async throws -> [String: String]
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
    // create an expecations object used to initialise the mock
    // the expectations object is not thread-safe/sendable
    let expectations = MockService1Protocol.Expectations()
    // indicate that the first time `initialize(name: String, secondName: String?) async -> String` is called,
    // `expectedReturnValue1` should be returned
    // Note that setting an expectation with `.value(_ value:)/.error(_ error:)/.using(_ closure:)` without following
    // it with a `.times(_ times:)/.unboundedTimes()` modifier treats it as if there is an implicit `.times(1)` modifier
    expectations.initialize_name_secondName.value(expectedReturnValue1)
      // indicate that the next two times `initialize(name: String, secondName: String?) async -> String` is called,
      // the returned value should be determined by calling this closure.
      .using { name, secondName in
        "\(name)_\(secondName ?? "empty")"
      }.times(2)
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
    let expectations = MockWeatherService.Expectations()

    // 2. Configure what the mock should return
    expectations.getCurrentTemperature_for.value(22.5)

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
    let expectations = MockWeatherService.Expectations()
    expectations.getCurrentTemperature_for.value(22.5)

    let mockWeatherService = MockWeatherService(expectations: expectations)
    let weatherApp = WeatherApp(weatherService: mockWeatherService)

    let result = await weatherApp.displayCurrentWeather(for: "London")

    #expect(result == "Current temperature in London: 22.5°C")
  }

  @Test func getCurrentTemperature_WhenServiceFails_ThrowsError() async {
    // Configure mock to throw an error
    let expectations = MockWeatherService.Expectations()
    expectations.getCurrentTemperature_for.error(WeatherError.serviceUnavailable)

    let mockWeatherService = MockWeatherService(expectations: expectations)

    // Verify error is thrown
    await #expect(throws: WeatherError.self) {
      try await mockWeatherService.getCurrentTemperature(for: "London")
    }
  }

  @Test func getForecast_MultipleCalls() async throws {
    let expectations = MockWeatherService.Expectations()

    // Configure different responses for different calls
    let londonForecast = [WeatherDay(date: Date(), temperature: 20.0, condition: "Sunny")]
    let parisForecast = [WeatherDay(date: Date(), temperature: 18.0, condition: "Cloudy")]

    expectations.getForecast_for_days
      .value(londonForecast)  // First call returns London forecast
      .value(parisForecast)  // Second call returns Paris forecast

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
    let expectations = MockWeatherService.Expectations()

    // Use a closure to provide custom logic
    let lastCity = LastCity()
    expectations.getCurrentTemperature_for.using { city in
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
    }.unboundedTimes()

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

  struct AccountDetails: Equatable {
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
    let expectations = MockBank.Expectations()
    let accountDetails = AccountDetails(name: "MyAccount")

    // Use a closure to provide custom logic
    let logic = MockBankLogic()
    expectations.withdraw_amount.using(logic.withdraw).unboundedTimes()
    expectations.getBalance.using(logic.getBalance).unboundedTimes()
    expectations.setAccountDetails_details.success()

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
}
