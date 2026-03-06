//
//  HydrationCalculator.swift
//  Fitness Hydration Tracker
//

import Foundation

// MARK: - Hydration Level

enum HydrationLevel: String, CaseIterable, Codable {
    case sedentary = "Sedentary"
    case moderate  = "Moderate"
    case active    = "Active"
    case athlete   = "Athlete"

    var emoji: String {
        switch self {
        case .sedentary: return "🛋️"
        case .moderate:  return "🚶"
        case .active:    return "🏃"
        case .athlete:   return "⚡️"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Desk job, light walking"
        case .moderate:  return "Regular daily movement"
        case .active:    return "Daily workouts & active job"
        case .athlete:   return "Intense training or competition"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.0
        case .moderate:  return 1.1
        case .active:    return 1.2
        case .athlete:   return 1.35
        }
    }
}

// MARK: - Data Models

struct WeatherData {
    let temperatureCelsius: Double
    let humidity: Double          // 0–100
    let weatherCode: Int
    let cityName: String

    var temperatureFahrenheit: Double { temperatureCelsius * 9 / 5 + 32 }
}

struct HydrationResult {
    let totalML: Double
    let baseML: Double
    let stepsAdditionML: Double
    let temperatureAdditionML: Double
    let humidityAdditionML: Double

    // 1 US cup = 236.588 mL
    static let mlPerCup: Double = 236.588

    var totalCups: Double        { totalML                / Self.mlPerCup }
    var baseCups: Double         { baseML                 / Self.mlPerCup }
    var stepsCups: Double        { stepsAdditionML        / Self.mlPerCup }
    var tempCups: Double         { temperatureAdditionML  / Self.mlPerCup }
    var humidityCups: Double     { humidityAdditionML     / Self.mlPerCup }

    static func mlToCups(_ ml: Double) -> Double { ml / mlPerCup }
    static func cupsToML(_ cups: Double) -> Double { cups * mlPerCup }
    static func formatCups(_ ml: Double) -> String {
        let c = mlToCups(ml)
        return String(format: "%.1f", c)
    }
}

// MARK: - Calculator

enum HydrationCalculator {

    /// Calculates daily water intake in millilitres.
    /// - Base:        35 ml × bodyweight (kg)
    /// - Steps:       +250 ml per 5 000 active steps above 2 000-step baseline
    /// - Temperature: +150 ml per 5 °C above 20 °C
    /// - Humidity:    up to +150 ml when humidity > 60 %
    /// - Level:       multiplier applied to total
    static func calculate(
        steps: Int,
        weather: WeatherData,
        weightKg: Double = 70,
        level: HydrationLevel = .moderate
    ) -> HydrationResult {
        let base         = weightKg * 35
        let activeSteps  = max(0, steps - 2_000)
        let stepAdd      = Double(activeSteps) / 5_000.0 * 250.0
        let tempAdd      = max(0, (weather.temperatureCelsius - 20.0) / 5.0 * 150.0)
        let humidAdd     = weather.humidity > 60
                            ? (weather.humidity - 60.0) / 40.0 * 150.0
                            : 0.0
        let m            = level.multiplier

        return HydrationResult(
            totalML:                (base + stepAdd + tempAdd + humidAdd) * m,
            baseML:                 base     * m,
            stepsAdditionML:        stepAdd  * m,
            temperatureAdditionML:  tempAdd  * m,
            humidityAdditionML:     humidAdd * m
        )
    }

    // MARK: - Weather helpers

    static func weatherIcon(for code: Int) -> String {
        switch code {
        case 0:              return "sun.max.fill"
        case 1, 2:           return "cloud.sun.fill"
        case 3:              return "cloud.fill"
        case 45, 48:         return "cloud.fog.fill"
        case 51, 53, 55:     return "cloud.drizzle.fill"
        case 61, 63, 65:     return "cloud.rain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82:     return "cloud.heavyrain.fill"
        case 85, 86:         return "cloud.snow.fill"
        case 95, 96, 99:     return "cloud.bolt.rain.fill"
        default:             return "cloud.fill"
        }
    }

    static func weatherDescription(for code: Int) -> String {
        switch code {
        case 0:          return "Clear Sky"
        case 1:          return "Mainly Clear"
        case 2:          return "Partly Cloudy"
        case 3:          return "Overcast"
        case 45, 48:     return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 77:         return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86:     return "Snow Showers"
        case 95:         return "Thunderstorm"
        case 96, 99:     return "Thunderstorm + Hail"
        default:         return "Cloudy"
        }
    }
}
