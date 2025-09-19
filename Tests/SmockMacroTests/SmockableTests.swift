import Foundation
import Smockable
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@Smock
public protocol Service1Protocol {
    func initialize(name: String, secondName: String?) async -> String
}

@Smock
public protocol Service2Protocol {
    func initialize(name: String, secondName: String?) -> String
}

struct CompariableInput: Equatable {
    let name: String
    let secondName: String?
}

struct SmockableTests {
    @Test
    func protocolWithAsyncFunction() async {
        let expectedReturnValue1 = "ReturnValue1"
        let expectedReturnValue2 = "ReturnValue2"

        var expectations = MockService1Protocol.Expectations()
        // expectation for first call
        when(expectations.initialize(name: .any, secondName: .any), return: expectedReturnValue1)
        // expectation for next two calls
        when(expectations.initialize(name: .any, secondName: .any), times: 2) { name, secondName in
            "\(name)_\(secondName ?? "empty")"
        }
        // expectation for final two calls
        when(
            expectations.initialize(name: .any, secondName: .any),
            times: 2,
            return: expectedReturnValue2
        )

        // create the mock; no more expectations can be added to the mock
        let mock = MockService1Protocol(expectations: expectations)

        // perform some operations on the mock
        let returnValue1 = await mock.initialize(name: "Name1", secondName: "SecondName1")
        let returnValue2 = await mock.initialize(name: "Name2", secondName: "SecondName2")
        let returnValue3 = await mock.initialize(name: "Name3", secondName: "SecondName3")
        let returnValue4 = await mock.initialize(name: "Name3", secondName: "SecondName3")
        let returnValue5 = await mock.initialize(name: "Name3", secondName: "SecondName3")

        // query the current state of the mock
        verify(mock, times: 5).initialize(name: .any, secondName: .any)
        verify(mock, times: 1).initialize(name: "Name1", secondName: "SecondName1")
        verify(mock, times: 1).initialize(name: "Name2", secondName: "SecondName2")
        verify(mock, times: 3).initialize(name: "Name3", secondName: "SecondName3")

        // verify that the current state of the mock is as expected
        #expect(expectedReturnValue1 == returnValue1)
        #expect("Name2_SecondName2" == returnValue2)
        #expect("Name3_SecondName3" == returnValue3)
        #expect(expectedReturnValue2 == returnValue4)
        #expect(expectedReturnValue2 == returnValue5)
    }

    @Test
    func protocolWithSyncFunction() {
        let expectedReturnValue1 = "ReturnValue1"
        let expectedReturnValue2 = "ReturnValue2"

        var expectations = MockService2Protocol.Expectations()
        // expectation for first call
        when(expectations.initialize(name: .any, secondName: .any), return: expectedReturnValue1)
        // expectation for next two calls
        when(expectations.initialize(name: .any, secondName: .any), times: 2) { name, secondName in
            "\(name)_\(secondName ?? "empty")"
        }
        // expectation for final two calls
        when(
            expectations.initialize(name: .any, secondName: .any),
            times: 2,
            return: expectedReturnValue2
        )

        // create the mock; no more expectations can be added to the mock
        let mock = MockService2Protocol(expectations: expectations)

        // perform some operations on the mock
        let returnValue1 = mock.initialize(name: "Name1", secondName: "SecondName1")
        let returnValue2 = mock.initialize(name: "Name2", secondName: "SecondName2")
        let returnValue3 = mock.initialize(name: "Name3", secondName: "SecondName3")
        let returnValue4 = mock.initialize(name: "Name3", secondName: "SecondName3")
        let returnValue5 = mock.initialize(name: "Name3", secondName: "SecondName3")

        // query the current state of the mock
        verify(mock, times: 5).initialize(name: .any, secondName: .any)
        verify(mock, times: 1).initialize(name: "Name1", secondName: "SecondName1")
        verify(mock, times: 1).initialize(name: "Name2", secondName: "SecondName2")
        verify(mock, times: 3).initialize(name: "Name3", secondName: "SecondName3")

        // verify that the current state of the mock is as expected
        #expect(expectedReturnValue1 == returnValue1)
        #expect("Name2_SecondName2" == returnValue2)
        #expect("Name3_SecondName3" == returnValue3)
        #expect(expectedReturnValue2 == returnValue4)
        #expect(expectedReturnValue2 == returnValue5)
    }

    @Test
    func verifyNoInteractionsOnMock() {
        let mock = MockService1Protocol(expectations: .init())

        verifyNoInteractions(mock)
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
        when(expectations.getCurrentTemperature(for: .any), return: 22.5)

        // 3. Create the mock
        let mockWeatherService = MockWeatherService(expectations: expectations)

        // 4. Use the mock in your code
        let temperature = try await mockWeatherService.getCurrentTemperature(for: "London")

        // 5. Verify the result
        #expect(temperature == 22.5)

        // 6. Verify the mock was called correctly
        verify(mockWeatherService, times: 1).getCurrentTemperature(for: .any)
        verify(mockWeatherService, times: 1).getCurrentTemperature(for: "London")
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
        when(expectations.getCurrentTemperature(for: .any), return: 22.5)

        let mockWeatherService = MockWeatherService(expectations: expectations)
        let weatherApp = WeatherApp(weatherService: mockWeatherService)

        let result = await weatherApp.displayCurrentWeather(for: "London")

        #expect(result == "Current temperature in London: 22.5°C")
    }

    @Test func getCurrentTemperature_WhenServiceFails_ThrowsError() async {
        // Configure mock to throw an error
        var expectations = MockWeatherService.Expectations()
        when(expectations.getCurrentTemperature(for: .any), throw: WeatherError.serviceUnavailable)

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

        when(expectations.getForecast(for: .any, days: .any), return: londonForecast)  // First call returns London forecast
        when(expectations.getForecast(for: .any, days: .any), return: parisForecast)  // Second call returns Paris forecast

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
        verify(mockWeatherService, times: 2).getForecast(for: .any, days: .any)
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

    @Smock
    protocol Bank {
        func withdraw(amount: Double) async throws -> Double
        func getBalance() async -> Double
        func setAccountName(_ name: String) async
    }

    enum BankError: Error {
        case insufficientFunds
    }

    actor MockBankLogic {
        var balance: Double = 1000

        func withdraw(amount: Double) async throws -> Double {
            guard balance >= amount else {
                throw BankError.insufficientFunds
            }
            balance -= amount
            return balance
        }

        func getBalance() async -> Double {
            return balance
        }
    }

    @Test func getTemperature_WithActorAsLogic() async throws {
        var expectations = MockBank.Expectations()

        // Use a closure to provide custom logic
        let logic = MockBankLogic()
        when(expectations.withdraw(amount: .any), times: .unbounded, use: logic.withdraw)
        when(expectations.getBalance(), times: .unbounded, use: logic.getBalance)
        when(expectations.setAccountName(.any), complete: .withSuccess)

        let mockBank = MockBank(expectations: expectations)

        // Withdraw some amounts
        await mockBank.setAccountName("MyAccount")
        let balance1 = try await mockBank.withdraw(amount: 500)
        let balance2 = try await mockBank.withdraw(amount: 200)
        let balance3 = await mockBank.getBalance()

        #expect(balance1 == 500)
        #expect(balance2 == 300)
        #expect(balance3 == 300)

        verify(mockBank, times: 1).setAccountName("MyAccount")
        verify(mockBank, times: 1).withdraw(amount: 500)
        verify(mockBank, times: 1).withdraw(amount: 200)
        verify(mockBank, times: 1).getBalance()

        // Test error case
        await #expect(throws: BankError.insufficientFunds) {
            try await mockBank.withdraw(amount: 500)
        }
    }

    @Test func setAccountDetails_ConcurrentCalls() async throws {
        var expectations = MockBank.Expectations()

        // Configure the mock to succeed for all setAccountDetails calls
        when(expectations.setAccountName(.any), times: .unbounded, complete: .withSuccess)

        let mockBank = MockBank(expectations: expectations)

        // Make concurrent calls to setAccountDetails
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await mockBank.setAccountName("Account1") }
            group.addTask { await mockBank.setAccountName("Account2") }
            group.addTask { await mockBank.setAccountName("Account3") }
            group.addTask { await mockBank.setAccountName("Account4") }
            group.addTask { await mockBank.setAccountName("Account5") }
        }

        // Verify received inputs (order may vary due to concurrency)
        verify(mockBank, times: 5).setAccountName(.any)
        verify(mockBank, times: 1).setAccountName("Account1")
        verify(mockBank, times: 1).setAccountName("Account2")
        verify(mockBank, times: 1).setAccountName("Account3")
        verify(mockBank, times: 1).setAccountName("Account4")
        verify(mockBank, times: 1).setAccountName("Account5")
    }

    @Test
    func testVerifyFunction() async throws {
        // Create expectations
        var expectations = MockService1Protocol.Expectations()
        when(expectations.initialize(name: .any, secondName: .any), return: "test data")

        // Create mock
        let mock = MockService1Protocol(expectations: expectations)

        // Use the mock
        let result = await mock.initialize(name: "123", secondName: "test")

        // Test the new verify function
        verify(mock, times: 1).initialize(name: .any, secondName: .any)
        verify(mock, times: 1).initialize(name: "123", secondName: "test")

        // Verify results
        #expect(result == "test data")
    }

    // MARK: - Unhappy Path Tests

    #if SMOCKABLE_UNHAPPY_PATH_TESTING
    @Test
    func testVerifyNoInteractionsFailsWhenThereWereInteractions() async {
        await expectVerificationFailures(messages: [
            "Expected MockService1Protocol to have no interactions but was called 1 time"
        ]) {
            var expectations = MockService1Protocol.Expectations()
            when(expectations.initialize(name: .any, secondName: .any), return: "test")

            let mock = MockService1Protocol(expectations: expectations)

            // Call it but verify no interactions - should fail
            let result = await mock.initialize(name: "test", secondName: "test")

            #expect(result == "test")
            verifyNoInteractions(mock)
        }
    }

    @Test
    func testWeatherServiceVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected getCurrentTemperature(for city: any) to be called exactly 2 times, but was called 1 time"
        ]) {
            var expectations = MockWeatherService.Expectations()
            when(expectations.getCurrentTemperature(for: .any), return: 22.5)

            let mockWeatherService = MockWeatherService(expectations: expectations)

            // Call once but verify for 2 times - should fail
            _ = try await mockWeatherService.getCurrentTemperature(for: "London")
            verify(mockWeatherService, times: 2).getCurrentTemperature(for: .any)
        }
    }

    @Test
    func testWeatherServiceNeverCalledFailure() async throws {
        try await expectVerificationFailures(messages: [
            "Expected getCurrentTemperature(for city: any) to never be called, but was called 1 time"
        ]) {
            var expectations = MockWeatherService.Expectations()
            when(expectations.getCurrentTemperature(for: .any), return: 22.5)

            let mockWeatherService = MockWeatherService(expectations: expectations)

            // Call it but verify never called - should fail
            _ = try await mockWeatherService.getCurrentTemperature(for: "London")
            verify(mockWeatherService, .never).getCurrentTemperature(for: .any)
        }
    }

    @Test
    func testBankServiceVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected withdraw(amount: any) to be called at least 3 times, but was called 2 times"
        ]) {
            var expectations = MockBank.Expectations()
            when(expectations.withdraw(amount: .any), times: .unbounded, return: 500.0)

            let mockBank = MockBank(expectations: expectations)

            // Call twice but verify at least 3 times - should fail
            _ = try await mockBank.withdraw(amount: 100)
            _ = try await mockBank.withdraw(amount: 200)
            verify(mockBank, atLeast: 3).withdraw(amount: .any)
        }
    }

    @Test
    func testMultipleMockVerificationFailures() async throws {
        try await expectVerificationFailures(messages: [
            "Expected getCurrentTemperature(for city: any) to be called exactly 2 times, but was called 1 time",
            "Expected getBalance() to never be called, but was called 1 time",
        ]) {
            // Test multiple mocks with failures
            var weatherExpectations = MockWeatherService.Expectations()
            when(weatherExpectations.getCurrentTemperature(for: .any), return: 22.5)

            var bankExpectations = MockBank.Expectations()
            when(bankExpectations.getBalance(), return: 1000.0)

            let weatherMock = MockWeatherService(expectations: weatherExpectations)
            let bankMock = MockBank(expectations: bankExpectations)

            // Call each once
            _ = try await weatherMock.getCurrentTemperature(for: "London")
            _ = await bankMock.getBalance()

            // Two failing verifications
            verify(weatherMock, times: 2).getCurrentTemperature(for: .any)  // Fail 1
            verify(bankMock, .never).getBalance()  // Fail 2
        }
    }

    @Test
    func testSyncServiceVerificationFailures() {
        expectVerificationFailures(messages: [
            "Expected initialize(name: any, secondName: any) to be called at most 1 time, but was called 3 times"
        ]) {
            var expectations = MockService2Protocol.Expectations()
            when(expectations.initialize(name: .any, secondName: .any), times: .unbounded, return: "result")

            let mock = MockService2Protocol(expectations: expectations)

            // Call 3 times but verify at most 1 time - should fail
            _ = mock.initialize(name: "test1", secondName: "value1")
            _ = mock.initialize(name: "test2", secondName: "value2")
            _ = mock.initialize(name: "test3", secondName: "value3")
            verify(mock, atMost: 1).initialize(name: .any, secondName: .any)
        }
    }
    #endif
}
