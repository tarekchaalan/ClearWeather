import Foundation
import CoreLocation
import SwiftUI
import CoreHaptics

@Observable
class WeatherViewModel: ObservableObject {
    var useCelsius: Bool {
        didSet {
            UserDefaults.standard.set(useCelsius, forKey: "useCelsius")
            objectWillChange.send()
        }
    }

    private let weatherService: WeatherService
    private let locationManager = CLLocationManager()
    private var locationDelegate: LocationDelegate?
    private var hapticEngine: CHHapticEngine?

    var currentLocation: Location?
    var savedLocations: [Location] = []
    var currentWeather: WeatherData?
    var isLoading = false
    var error: Error?

    init() {
        self.useCelsius = UserDefaults.standard.bool(forKey: "useCelsius")
        if !UserDefaults.standard.contains(key: "useCelsius") {
            self.useCelsius = true
            UserDefaults.standard.set(true, forKey: "useCelsius")
        }
        self.weatherService = WeatherService.shared
        loadSavedLocations()
        prepareHaptics()
    }

    func loadSavedLocations() {
        if let data = UserDefaults.standard.data(forKey: "savedLocations"),
           let locations = try? JSONDecoder().decode([Location].self, from: data) {
            savedLocations = locations
            if let first = locations.first {
                currentLocation = first
                Task {
                    await fetchWeather(for: first)
                }
            }
        }
    }

    func saveLocations() {
        if let encoded = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(encoded, forKey: "savedLocations")
        }
    }

    func fetchWeather(for location: Location) async {
        isLoading = true
        error = nil

        do {
            let weather = try await weatherService.fetchWeather(
                lat: location.latitude,
                lon: location.longitude
            )
            await MainActor.run {
                self.currentWeather = weather
                self.isLoading = false
            }
        } catch let weatherError as WeatherService.WeatherServiceError {
            await MainActor.run {
                switch weatherError {
                case .weatherKitAuthenticationFailed:
                    print("WeatherKit authentication failed. Please check your Apple Developer account settings and ensure WeatherKit is properly configured.")
                case .weatherDataFetchFailed:
                    print("Failed to fetch weather data. Please try again.")
                case .locationError:
                    print("Location error. Please check location permissions.")
                case .unknown:
                    print("An unknown error occurred.")
                }
                self.error = weatherError
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                print("Unexpected error: \(error.localizedDescription)")
                self.error = error
                self.isLoading = false
            }
        }
    }

    func requestLocation(completion: @escaping (Location?) -> Void) {
        // Create the delegate before checking status to ensure it's retained
        locationDelegate = LocationDelegate(completion: { [weak self] coordinates in
            self?.handleLocationUpdate(coordinates, completion: completion)
        })
        locationManager.delegate = locationDelegate

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // The delegate will handle the location request after authorization

        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()

        case .denied, .restricted:
            completion(nil)
            print("Location access denied")

        @unknown default:
            completion(nil)
            print("Unknown authorization status")
        }
    }

    private func handleLocationUpdate(_ coordinates: CLLocation, completion: @escaping (Location?) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(coordinates) { places, error in
            guard let place = places?.first,
                  let name = place.locality ?? place.name else {
                completion(nil)
                return
            }

            let location = Location(
                name: name,
                latitude: coordinates.coordinate.latitude,
                longitude: coordinates.coordinate.longitude
            )
            completion(location)
        }
    }

    func convertTemp(_ celsius: Double) -> Double {
        useCelsius ? celsius : (celsius * 9/5 + 32)
    }

    func toggleTemperatureUnit() {
        useCelsius.toggle()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptics error: \(error.localizedDescription)")
        }
    }

    func playHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private class LocationDelegate: NSObject, CLLocationManagerDelegate {
        private let completion: (CLLocation) -> Void

        init(completion: @escaping (CLLocation) -> Void) {
            self.completion = completion
            super.init()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.first else { return }
            completion(location)
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("Location manager failed with error: \(error.localizedDescription)")
        }

        // Add authorization status change handling
        func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
