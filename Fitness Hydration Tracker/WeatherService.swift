//
//  WeatherService.swift
//  Fitness Hydration Tracker
//
//  Created by Claude on 3/6/26.
//

import CoreLocation
import Foundation
import Observation

// MARK: - Open-Meteo response models

private struct OpenMeteoResponse: Decodable {
    let current: CurrentWeatherResponse
}

private struct CurrentWeatherResponse: Decodable {
    let temperature_2m: Double
    let relative_humidity_2m: Double
    let weather_code: Int
}

// MARK: - Location helper (wraps CLLocationManager in an async continuation)

enum LocationError: Error {
    case denied
    case failed
}

/// Handles a single one-shot location request via async/await.
@MainActor
final class LocationFetcher: NSObject {
    static let shared = LocationFetcher()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func fetchOnce() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let status = manager.authorizationStatus
            switch status {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                cont.resume(throwing: LocationError.denied)
                self.continuation = nil
            }
        }
    }

    private func resume(with result: Result<CLLocation, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

extension LocationFetcher: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in self.resume(with: .success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.resume(with: .failure(error)) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.resume(with: .failure(LocationError.denied))
            default:
                break
            }
        }
    }
}

// MARK: - Weather service

@Observable
@MainActor
final class WeatherService {
    var weather: WeatherData?
    var isLoading = false
    var usingDefaultLocation = false

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let location = try await LocationFetcher.shared.fetchOnce()
            let cityName = await reverseGeocode(location)
            try await fetchWeather(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude,
                cityName: cityName
            )
            usingDefaultLocation = false
        } catch {
            // Fall back to London so the app still works without location
            usingDefaultLocation = true
            try? await fetchWeather(lat: 51.5074, lon: -0.1278, cityName: "London")
        }
    }

    // MARK: Private

    private func fetchWeather(lat: Double, lon: Double, cityName: String) async throws {
        let urlString =
            "https://api.open-meteo.com/v1/forecast" +
            "?latitude=\(lat)&longitude=\(lon)" +
            "&current=temperature_2m,relative_humidity_2m,weather_code" +
            "&temperature_unit=celsius"

        guard let url = URL(string: urlString) else { return }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

        weather = WeatherData(
            temperatureCelsius: decoded.current.temperature_2m,
            humidity: decoded.current.relative_humidity_2m,
            weatherCode: decoded.current.weather_code,
            cityName: cityName
        )
    }

    private func reverseGeocode(_ location: CLLocation) async -> String {
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            return placemark.locality ?? placemark.administrativeArea ?? "Your Location"
        }
        return "Your Location"
    }
}
