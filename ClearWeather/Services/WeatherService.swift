import Foundation
import WeatherKit
import CoreLocation

actor WeatherService {
    static let shared = WeatherService()
    private let weatherService = WeatherKit.WeatherService.shared

    enum WeatherServiceError: Error {
        case weatherKitAuthenticationFailed
        case weatherDataFetchFailed
        case locationError
        case unknown
    }

    private init() {}

    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherData {
        let location = CLLocation(latitude: lat, longitude: lon)

        do {
            // Get the location's timezone
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let timezone = placemarks.first?.timeZone ?? TimeZone.current

            // Create calendar in location's timezone
            var calendar = Calendar.current
            calendar.timeZone = timezone

            // Get start of day in location's timezone
            let now = Date()
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            // Fetch weather data
            let weather = try await weatherService.weather(for: location)

            // Convert WeatherKit data to our WeatherData model
            let currentData = WeatherData.Current(
                dt: weather.currentWeather.date.timeIntervalSince1970,
                sunrise: weather.dailyForecast.first?.sun.sunrise?.timeIntervalSince1970 ?? 0,
                sunset: weather.dailyForecast.first?.sun.sunset?.timeIntervalSince1970 ?? 0,
                temp: weather.currentWeather.temperature.value,
                feelsLike: weather.currentWeather.apparentTemperature.value,
                humidity: Int(weather.currentWeather.humidity * 100),
                uvi: Double(weather.currentWeather.uvIndex.value),
                windSpeed: weather.currentWeather.wind.speed.value,
                weather: [WeatherData.Weather(
                    id: 0,
                    main: weather.currentWeather.condition.rawValue,
                    description: weather.currentWeather.condition.description,
                    icon: mapConditionToIcon(weather.currentWeather.condition)
                )]
            )

            // Convert hourly forecast - get all hours for today in location's timezone
            let hourlyData = weather.hourlyForecast.forecast
                .filter { hour in
                    let date = hour.date
                    return date >= startOfDay && date < endOfDay
                }
                .map { hour in
                    WeatherData.Hourly(
                        dt: hour.date.timeIntervalSince1970,
                        temp: hour.temperature.value,
                        weather: [WeatherData.Weather(
                            id: 0,
                            main: hour.condition.rawValue,
                            description: hour.condition.description,
                            icon: mapConditionToIcon(hour.condition)
                        )]
                    )
                }

            // Convert daily forecast - get up to 10 days of data
            let dailyData = weather.dailyForecast.forecast.prefix(10).map { day in
                WeatherData.Daily(
                    dt: day.date.timeIntervalSince1970,
                    temp: WeatherData.DayTemp(
                        min: day.lowTemperature.value,
                        max: day.highTemperature.value
                    ),
                    weather: [WeatherData.Weather(
                        id: 0,
                        main: day.condition.rawValue,
                        description: day.condition.description,
                        icon: mapConditionToIcon(day.condition)
                    )],
                    sunrise: day.sun.sunrise?.timeIntervalSince1970 ?? 0,
                    sunset: day.sun.sunset?.timeIntervalSince1970 ?? 0
                )
            }

            return WeatherData(
                current: currentData,
                hourly: Array(hourlyData),
                daily: Array(dailyData),
                timezone: timezone.identifier,
                timezoneOffset: timezone.secondsFromGMT()
            )
        } catch is WeatherKit.WeatherError {
            print("WeatherKit error occurred")
            throw WeatherServiceError.weatherDataFetchFailed
        } catch {
            print("Unknown error: \(error)")
            if let nsError = error as NSError? {
                print("Error domain: \(nsError.domain), code: \(nsError.code)")
                if nsError.domain == "WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors" {
                    throw WeatherServiceError.weatherKitAuthenticationFailed
                }
            }
            throw WeatherServiceError.unknown
        }
    }

    private func mapConditionToIcon(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear:
            return "sun.max"
        case .mostlyClear:
            return "cloud.sun"
        case .partlyCloudy:
            return "cloud.sun"
        case .mostlyCloudy:
            return "cloud"
        case .cloudy:
            return "cloud"
        case .drizzle:
            return "cloud.drizzle"
        case .heavyRain, .rain:
            return "cloud.rain"
        case .freezingRain:
            return "cloud.sleet"
        case .sleet:
            return "cloud.sleet"
        case .snow, .heavySnow:
            return "cloud.snow"
        case .thunderstorms:
            return "cloud.bolt.rain"
        case .windy:
            return "wind"
        case .blowingDust:
            return "cloud.fog"
        case .blizzard:
            return "cloud.snow"
        case .tropicalStorm:
            return "tropicalstorm"
        case .hurricane:
            return "hurricane"
        default:
            return "sun.max"
        }
    }
}

// Extension to get weather condition description
extension WeatherCondition {
    var description: String {
        switch self {
        case .clear:
            return "Clear sky"
        case .mostlyClear:
            return "Mostly clear"
        case .partlyCloudy:
            return "Partly cloudy"
        case .mostlyCloudy:
            return "Mostly cloudy"
        case .cloudy:
            return "Cloudy"
        case .drizzle:
            return "Light rain"
        case .rain:
            return "Rain"
        case .heavyRain:
            return "Heavy rain"
        case .freezingRain:
            return "Freezing rain"
        case .sleet:
            return "Sleet"
        case .snow:
            return "Snow"
        case .heavySnow:
            return "Heavy snow"
        case .thunderstorms:
            return "Thunderstorms"
        case .blowingDust:
            return "Blowing dust"
        case .windy:
            return "Windy"
        case .blizzard:
            return "Blizzard"
        case .tropicalStorm:
            return "Tropical storm"
        case .hurricane:
            return "Hurricane"
        default:
            return "Unknown condition"
        }
    }
}
