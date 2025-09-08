# Overview

This overview will demonstrate the core capabilities of Smockable by creating a mocked protocol and using it in some tests.
Note that these are not tests that you would write yourself as they are only testing the functionality of the mock
implementation and not helping to test your own code.

## Create a Protocol

Create a protocol and annotate it with `@Smock`:

```swift
import Smockable

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
```

## Verifying basic behaviour

```swift
import Testing
import Smockable

@Test func getCurrentTemperature() async throws {
        // 1. Create expectations
        var expectations = MockWeatherService.Expectations()
        
        // 2. Configure what the mock should return
        when(expectations.getCurrentTemperature(for: .any), return: 22.5)
        
        // Or use exact value matching for specific cities
        when(expectations.getCurrentTemperature(for: "London"), return: 15.0)
        
        // 3. Create the mock
        let mockWeatherService = MockWeatherService(expectations: expectations)
        
        // 4. Use the mock in your code
        let temperature = try await mockWeatherService.getCurrentTemperature(for: "London")
        
        // 5. Verify the result
        #expect(temperature == 22.5)
        
        // 6. Verify the mock was called correctly
        let callCount = await mockWeatherService.__verify.getCurrentTemperature_for.callCount
        let receivedInvocations = await mockWeatherService.__verify.getCurrentTemperature_for.receivedInvocations
        
        #expect(callCount == 1)
        #expect(receivedInvocations[0].city == "London")
}
```

In this simply example we an see that we-
1. Set an *expectation* that the `getCurrentTemperature(:for)` method would return a value of 22.5 when called
2. Used the mock; in this case by directly calling its method but in a more complex example you could pass it to 
whatever is under test that expects an instance conforming to the `WeatherService` protocol
3. Was able to `verify` that the mock method was called once
4. Was able to `verify` that when the mock method was called it was called with "London" as the city.
5. `receivedInvocations` will be an array of tuples with elements labelled according to the function's inputs

## Test Error Scenarios

Building on our previous example, you can also set expectations that are errors, allowing you to test error scenarios.

**Note:** The error expectation will only be available if the method or property can throw.

```swift
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
```

## Test Multiple Calls

Smockable allows you to build up complexing testing scenarios by setting different expectations for different
invocations of the same mocked function for property.

```swift
@Test func getForecast_MultipleCalls() async throws {
    var expectations = MockWeatherService.Expectations()
    
    // Configure different responses for different calls
    let londonForecast = [WeatherDay(date: Date(), temperature: 20.0, condition: "Sunny")]
    let parisForecast = [WeatherDay(date: Date(), temperature: 18.0, condition: "Cloudy")]
    
    when(expectations.getForecast(for: .any, days: .any), return: londonForecast)  // First call returns London forecast
    when(expectations.getForecast(for: .any, days: .any), return: parisForecast)   // Second call returns Paris forecast
    
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
```

## Use Custom Logic

In certain testing scenarios, the use of static expectations that either return a single value or throw a single error
may be insufficient or unwieldy. In these cases we can use a closure to provide more complex expectation logic. Here we
are also using the `.unboundedTimes()` modifier to indicate that the expectation should be used every time the mocked
function is called.

```swift
@Test func getTemperature_WithCustomLogic() async throws {
    var expectations = MockWeatherService.Expectations()
    
    // Use a closure to provide custom logic
    when(expectations.getCurrentTemperature(for: .any), times: .unbounded) { city in
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
    
    // Test error case
    await #expect(throws: WeatherError.cityNotFound) {
        try await mockWeatherService.getCurrentTemperature(for: "Unknown City")
    }
}
```

## Next Steps

- <doc:GettingStarted> for installing and using Smockable
