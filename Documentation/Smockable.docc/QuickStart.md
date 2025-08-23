# Quick Start

Get up and running with Smockable in minutes.

## Overview

This quick start guide will have you creating and using your first mock in just a few minutes. We'll walk through a simple example that demonstrates the core concepts of Smockable.

## Step 1: Install Smockable

Add Smockable to your project using Swift Package Manager. In Xcode:

1. Go to **File → Add Package Dependencies**
2. Enter: `https://github.com/tachyonics/smockable.git`
3. Add it to your test targets

Or in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/tachyonics/smockable.git", from: "1.0.0")
]
```

## Step 2: Create a Protocol

Create a protocol and annotate it with `@Smock`:

```swift
import Smockable

@Smock
protocol WeatherService {
    func getCurrentTemperature(for city: String) async throws -> Double
    func getForecast(for city: String, days: Int) async throws -> [WeatherDay]
}

struct WeatherDay {
    let date: Date
    let temperature: Double
    let condition: String
}
```

## Step 3: Write Your First Test

Create a test that uses the generated mock:

```swift
import Testing
import Smockable

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
        #expect(receivedInputs[0].city == "London")
}
```

## Step 4: Test Error Scenarios

Test how your code handles errors:

```swift
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
```

## Step 5: Test Multiple Calls

Configure different responses for multiple calls:

```swift
@Test func getForecast_MultipleCalls() async throws {
    let expectations = MockWeatherService.Expectations()
    
    // Configure different responses for different calls
    let londonForecast = [WeatherDay(date: Date(), temperature: 20.0, condition: "Sunny")]
    let parisForecast = [WeatherDay(date: Date(), temperature: 18.0, condition: "Cloudy")]
    
    expectations.getForecast_for_days
        .value(londonForecast)  // First call returns London forecast
        .value(parisForecast)   // Second call returns Paris forecast
    
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

## Step 6: Use Custom Logic

Use closures for dynamic behavior:

```swift
@Test func getTemperature_WithCustomLogic() async throws {
    let expectations = MockWeatherService.Expectations()
    
    // Use a closure to provide custom logic
    expectations.getCurrentTemperature_for.using { city in
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

## Step 7: Test in Real Code

Use the mock in a real service class:

```swift
class WeatherApp {
    private let weatherService: WeatherService
    
    init(weatherService: WeatherService) {
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

// Test the real code with the mock
@Test func weatherApp_DisplaysTemperature() async {
    let expectations = MockWeatherService.Expectations()
    expectations.getCurrentTemperature_for.value(22.5)
    
    let mockWeatherService = MockWeatherService(expectations: expectations)
    let weatherApp = WeatherApp(weatherService: mockWeatherService)
    
    let result = await weatherApp.displayCurrentWeather(for: "London")
    
    #expect(result == "Current temperature in London: 22.5°C")
}

@Test func weatherApp_HandlesError() async {
    let expectations = MockWeatherService.Expectations()
    expectations.getCurrentTemperature_for.error(WeatherError.serviceUnavailable)
    
    let mockWeatherService = MockWeatherService(expectations: expectations)
    let weatherApp = WeatherApp(weatherService: mockWeatherService)
    
    let result = await weatherApp.displayCurrentWeather(for: "London")
    
    #expect(result == "Unable to fetch weather for London")
}
```

## Key Concepts Recap

From this quick start, you've learned:

1. **@Smock annotation**: Applied to protocols to generate mocks
2. **Expectations**: Configure how mocks should behave
3. **Mock creation**: Initialize mocks with expectations
4. **Verification**: Check call counts and received parameters
5. **Error testing**: Configure mocks to throw errors
6. **Multiple calls**: Set up different responses for sequential calls
7. **Custom logic**: Use closures for dynamic behavior

## Next Steps

Now that you have the basics down, explore these topics:

- **<doc:Expectations>**: Learn about advanced expectation patterns
- **<doc:Verification>**: Discover comprehensive verification techniques  
- **<doc:AsyncAndThrowing>**: Master async and throwing function patterns
- **<doc:CommonPatterns>**: See real-world usage examples
- **<doc:BestPractices>**: Learn testing best practices

## Common Issues

### Mock not found
If you get "Cannot find 'MockProtocolName' in scope":
- Ensure you've imported Smockable
- Check that the protocol has the `@Smock` annotation
- Verify Smockable is added to your test target

### Async/await errors
If you get async-related compile errors:
- Mark your test functions as `async` using `@Test func myTest() async`
- Use `await` when accessing verification properties
- Use `try await` when calling throwing async methods

### Expectation errors
If you get runtime errors about expectations:
- Set up all expectations before creating the mock
- Ensure you have expectations for all methods you'll call
- Use `.unboundedTimes()` for methods called multiple times

Ready to dive deeper? Check out the <doc:GettingStarted> guide for more comprehensive coverage!