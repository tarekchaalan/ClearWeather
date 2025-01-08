import Foundation

struct WeatherData: Codable, Identifiable {
    let id = UUID()
    let current: Current
    let hourly: [Hourly]
    let daily: [Daily]
    let timezone: String
    let timezoneOffset: Int

    enum CodingKeys: String, CodingKey {
        case current, hourly, daily, timezone
        case timezoneOffset = "timezone_offset"
    }

    struct Current: Codable {
        let dt: TimeInterval
        let sunrise: TimeInterval
        let sunset: TimeInterval
        let temp: Double
        let feelsLike: Double
        let humidity: Int
        let uvi: Double
        let windSpeed: Double
        let weather: [Weather]

        enum CodingKeys: String, CodingKey {
            case dt, sunrise, sunset, temp, humidity, uvi
            case feelsLike = "feels_like"
            case windSpeed = "wind_speed"
            case weather
        }
    }

    struct Hourly: Codable {
        let dt: TimeInterval
        let temp: Double
        let weather: [Weather]
    }

    struct Daily: Codable {
        let dt: TimeInterval
        let temp: DayTemp
        let weather: [Weather]
        let sunrise: TimeInterval
        let sunset: TimeInterval
    }

    struct DayTemp: Codable {
        let min: Double
        let max: Double
    }

    struct Weather: Codable {
        let id: Int
        let main: String
        let description: String
        let icon: String
    }
}