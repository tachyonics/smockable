# Quick Start

Get up and running with Smockable.

## Overview

This getting started guide will walk through installing Smockable and creating an initial mock.

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

## Step 3: Create an implementation that needs to be tested

The point of creating mock implementations is to allow you to easily test your own code and how it uses it an underlying
implementation. To demonstrate this we will create a simple implementation that uses an instance of the `WeatherService`
protocol.

```swift
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
```

## Step 4: Create a test that verifies the happy path

```swift
@Test func weatherApp_DisplaysTemperature() async {
    let expectations = MockWeatherService.Expectations()
    expectations.getCurrentTemperature_for.value(22.5)
    
    let mockWeatherService = MockWeatherService(expectations: expectations)
    let weatherApp = WeatherApp(weatherService: mockWeatherService)
    
    let result = await weatherApp.displayCurrentWeather(for: "London")
    
    #expect(result == "Current temperature in London: 22.5°C")
}

```

## Step 5: Create a test that verifies the unhappy path

```swift
@Test func weatherApp_HandlesError() async {
    let expectations = MockWeatherService.Expectations()
    expectations.getCurrentTemperature_for.error(WeatherError.serviceUnavailable)
    
    let mockWeatherService = MockWeatherService(expectations: expectations)
    let weatherApp = WeatherApp(weatherService: mockWeatherService)
    
    let result = await weatherApp.displayCurrentWeather(for: "London")
    
    #expect(result == "Unable to fetch weather for London")
}
```

## Next Steps

This guide walked through how to test a basic implementation with only a couple of code paths. More complex
implementations will likely have significantly more code paths but can be tested using Smockable in the same way.

- **<doc:Expectations>**: Learn about advanced expectation patterns
- **<doc:Verification>**: Discover comprehensive verification techniques  
