//
//  HydrationViewModel.swift
//  Fitness Hydration Tracker
//

import Combine
import Foundation

// Switch to ObservableObject + @Published so Combine drives view updates.
// @Observable + didSet has known issues in Swift 6 / Xcode 26 where the
// observation registrar and property observers can conflict, silently skipping
// change notifications. @Published is guaranteed to fire objectWillChange.

@MainActor
final class HydrationViewModel: ObservableObject {

    // MARK: - Services (remain @Observable internally)

    let weather = WeatherService()
    let health  = HealthKitService()

    // MARK: - Published state — any write triggers an immediate view refresh

    @Published var weightLbs: Double = 154 {
        didSet { UserDefaults.standard.set(weightLbs, forKey: "weightLbs") }
    }

    @Published var hydrationLevel: HydrationLevel = .moderate {
        didSet { UserDefaults.standard.set(hydrationLevel.rawValue, forKey: "hydrationLevel") }
    }

    @Published var loggedML: Double = 0 {
        didSet { UserDefaults.standard.set(loggedML, forKey: todayKey) }
    }

    // MARK: - Init

    init() {
        let storedWeight = UserDefaults.standard.double(forKey: "weightLbs")
        if storedWeight > 0 { weightLbs = storedWeight }

        if let raw   = UserDefaults.standard.string(forKey: "hydrationLevel"),
           let level = HydrationLevel(rawValue: raw) {
            hydrationLevel = level
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        loggedML = UserDefaults.standard.double(forKey: "logged_\(fmt.string(from: Date()))")
    }

    // MARK: - Derived

    var weightKg:     Double { weightLbs * 0.453592 }
    var loggedCups:   Double { loggedML / HydrationResult.mlPerCup }
    var remainingML:  Double { max(result.totalML - loggedML, 0) }
    var remainingCups: Double { remainingML / HydrationResult.mlPerCup }
    var goalReached:  Bool   { loggedML >= result.totalML }

    var progress: Double {
        guard result.totalML > 0 else { return 0 }
        return min(loggedML / result.totalML, 1.0)
    }

    var result: HydrationResult {
        let w = weather.weather ?? WeatherData(
            temperatureCelsius: 20, humidity: 50, weatherCode: 0, cityName: ""
        )
        return HydrationCalculator.calculate(
            steps: health.steps, weather: w, weightKg: weightKg, level: hydrationLevel
        )
    }

    private var todayKey: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return "logged_\(fmt.string(from: Date()))"
    }

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
        objectWillChange.send()          // bridge @Observable service → @Published vm
        await health.requestAuthorizationAndFetch()
        objectWillChange.send()
    }

    func refresh() async {
        await weather.refresh()
        await health.fetchTodaySteps()
        objectWillChange.send()
    }
}
