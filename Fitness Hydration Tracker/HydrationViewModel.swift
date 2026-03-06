//
//  HydrationViewModel.swift
//  Fitness Hydration Tracker
//
//  Created by Claude on 3/6/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class HydrationViewModel {

    // MARK: - Services

    let weather = WeatherService()
    let health = HealthKitService()

    // MARK: - Persisted user settings

    var weightKg: Double {
        get { UserDefaults.standard.double(forKey: "weightKg").positiveOrDefault(70) }
        set { UserDefaults.standard.set(newValue, forKey: "weightKg") }
    }

    // MARK: - Today's logged water (persisted by calendar day)

    var loggedML: Double {
        get { UserDefaults.standard.double(forKey: todayKey) }
        set { UserDefaults.standard.set(newValue, forKey: todayKey) }
    }

    private var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "logged_\(fmt.string(from: Date()))"
    }

    // MARK: - Computed hydration values

    var result: HydrationResult {
        let w = weather.weather ?? WeatherData(
            temperatureCelsius: 20, humidity: 50, weatherCode: 0, cityName: ""
        )
        return HydrationCalculator.calculate(steps: health.steps, weather: w, weightKg: weightKg)
    }

    var progress: Double {
        guard result.totalML > 0 else { return 0 }
        return min(loggedML / result.totalML, 1.0)
    }

    var remainingML: Double {
        max(result.totalML - loggedML, 0)
    }

    var goalReached: Bool { loggedML >= result.totalML }

    // MARK: - Actions

    func logWater(_ ml: Double) {
        loggedML += ml
    }

    func resetToday() {
        loggedML = 0
    }

    // MARK: - Lifecycle

    func onAppear() async {
        await weather.refresh()
        await health.requestAuthorizationAndFetch()
    }

    func refresh() async {
        await weather.refresh()
        await health.fetchTodaySteps()
    }
}

// MARK: - Helpers

private extension Double {
    func positiveOrDefault(_ fallback: Double) -> Double {
        self > 0 ? self : fallback
    }
}
