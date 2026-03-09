//
//  HydrationViewModel.swift
//  Fitness Hydration Tracker
//

import Foundation
import Observation

@Observable
@MainActor
final class HydrationViewModel {

    // MARK: - Services

    let weather = WeatherService()
    let health  = HealthKitService()

    // MARK: - Stored properties
    // Using plain stored vars — @Observable instruments these directly.
    // didSet keeps UserDefaults in sync after init (didSet is NOT called
    // for assignments made during init, which is correct behavior here).

    var weightLbs: Double = 154 {
        didSet { UserDefaults.standard.set(weightLbs, forKey: "weightLbs") }
    }

    var hydrationLevel: HydrationLevel = .moderate {
        didSet { UserDefaults.standard.set(hydrationLevel.rawValue, forKey: "hydrationLevel") }
    }

    var loggedML: Double = 0 {
        didSet { UserDefaults.standard.set(loggedML, forKey: todayKey) }
    }

    // MARK: - Init

    init() {
        let storedWeight = UserDefaults.standard.double(forKey: "weightLbs")
        if storedWeight > 0 { weightLbs = storedWeight }

        if let raw = UserDefaults.standard.string(forKey: "hydrationLevel"),
           let level = HydrationLevel(rawValue: raw) {
            hydrationLevel = level
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        loggedML = UserDefaults.standard.double(forKey: "logged_\(fmt.string(from: Date()))")
    }

    // MARK: - Derived

    var weightKg: Double { weightLbs * 0.453592 }
    var loggedCups: Double { loggedML / HydrationResult.mlPerCup }

    private var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "logged_\(fmt.string(from: Date()))"
    }

    var result: HydrationResult {
        let w = weather.weather ?? WeatherData(
            temperatureCelsius: 20, humidity: 50, weatherCode: 0, cityName: ""
        )
        return HydrationCalculator.calculate(
            steps: health.steps,
            weather: w,
            weightKg: weightKg,
            level: hydrationLevel
        )
    }

    var progress: Double {
        guard result.totalML > 0 else { return 0 }
        return min(loggedML / result.totalML, 1.0)
    }

    var remainingML: Double    { max(result.totalML - loggedML, 0) }
    var remainingCups: Double  { remainingML / HydrationResult.mlPerCup }
    var goalReached: Bool      { loggedML >= result.totalML }

    // MARK: - Actions

    func logWater(cups: Double) {
        loggedML += cups * HydrationResult.mlPerCup
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
