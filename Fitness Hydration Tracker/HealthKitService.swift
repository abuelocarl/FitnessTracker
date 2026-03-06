//
//  HealthKitService.swift
//  Fitness Hydration Tracker
//
//  Created by Claude on 3/6/26.
//

import Foundation
import HealthKit
import Observation

@Observable
@MainActor
final class HealthKitService {
    var steps: Int = 0
    var isAuthorized = false
    var isUnavailable = false

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    func requestAuthorizationAndFetch() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            isUnavailable = true
            return
        }

        do {
            try await store.requestAuthorization(toShare: [], read: [stepType])
            isAuthorized = true
            await fetchTodaySteps()
        } catch {
            // HealthKit denied – steps will stay at 0
        }
    }

    func fetchTodaySteps() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: HKSamplePredicate.quantitySample(type: stepType, predicate: predicate),
            options: .cumulativeSum
        )

        do {
            let result = try await descriptor.result(for: store)
            steps = Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
        } catch {
            // Keep previous value on error
        }
    }
}
