//
//  HydrationCalculator.swift
//  Fitness Hydration Tracker
//
//  Created by Claude on 3/6/26.
//

import Foundation

// MARK: - Data Models

struct WeatherData {
    let temperatureCelsius: Double
    let humidity: Double // 0–100
    let weatherCode: Int
    let cityName: String
}

struct HydrationResult {
    let totalML: Double
    let baseML: Double
    let stepsAdditionML: Double
    let temperatureAdditionML: Double
    let humidityAdditionML: Double

    var totalLiters: String {
        String(format: "%.1fL", totalML / 1000.0)
    }
}

// MARK: - Calculator

enum HydrationCalculator {

    /// Calculates daily water intake in millilitres.
    ///
    /// Formula:
    ///  - Base:        35 ml × bodyweight (kg)
    ///  - Steps:       +250 ml per 5 000 active steps (above a 2 000-step sedentary baseline)
    ///  - Temperature: +150 ml per 5 °C above 20 °C
    ///  - Humidity:    +150 ml (max) when humidity is above 60 %
    static func calculate(steps: Int, weather: WeatherData, weightKg: Double = 70) -> HydrationResult {
        let base = weightKg * 35

        let activeSteps = max(0, steps - 2_000)
        let stepAddition = Double(activeSteps) / 5_000.0 * 250.0

        let tempAddition = max(0, (weather.temperatureCelsius - 20.0) / 5.0 * 150.0)

        let humidityAddition = weather.humidity > 60
            ? (weather.humidity - 60.0) / 40.0 * 150.0
            : 0.0

        return HydrationResult(
            totalML: base + stepAddition + tempAddition + humidityAddition,
            baseML: base,
            stepsAdditionML: stepAddition,
            temperatureAdditionML: tempAddition,
            humidityAdditionML: humidityAddition
        )
    }

    // MARK: - Weather helpers

    static func weatherIcon(for code: Int) -> String {
        switch code {
        case 0:            return "sun.max.fill"
        case 1, 2:         return "cloud.sun.fill"
        case 3:            return "cloud.fill"
        case 45, 48:       return "cloud.fog.fill"
        case 51, 53, 55:   return "cloud.drizzle.fill"
        case 61, 63, 65:   return "cloud.rain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82:   return "cloud.heavyrain.fill"
        case 85, 86:       return "cloud.snow.fill"
        case 95, 96, 99:   return "cloud.bolt.rain.fill"
        default:           return "cloud.fill"
        }
    }

    static func weatherDescription(for code: Int) -> String {
        switch code {
        case 0:            return "Clear Sky"
        case 1:            return "Mainly Clear"
        case 2:            return "Partly Cloudy"
        case 3:            return "Overcast"
        case 45, 48:       return "Foggy"
        case 51, 53, 55:   return "Drizzle"
        case 61, 63, 65:   return "Rain"
        case 71, 73, 75:   return "Snow"
        case 77:           return "Snow Grains"
        case 80, 81, 82:   return "Rain Showers"
        case 85, 86:       return "Snow Showers"
        case 95:           return "Thunderstorm"
        case 96, 99:       return "Thunderstorm + Hail"
        default:           return "Cloudy"
        }
    }
}
