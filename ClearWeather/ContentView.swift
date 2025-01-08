//
//  ContentView.swift
//  ClearWeather
//
//  Created by Tarek Chaalan on 12/28/24.
//

import SwiftUI
import CoreLocation
import Charts

struct ContentView: View {
    @State private var weatherVM = WeatherViewModel()
    @State private var showLocationSearch = false
    @State private var showLocationPicker = false
    @State private var isScrolled = false

    var body: some View {
        NavigationStack {
            ScrollView {
        VStack {
                    // Only show this header when not scrolled
                    if !isScrolled {
                        HStack {
                            if !weatherVM.savedLocations.isEmpty {
                                Button(action: { showLocationPicker.toggle() }) {
                                    HStack(spacing: 4) {
                                        Text(weatherVM.currentLocation?.name ?? "Weather")
                                            .font(.largeTitle.bold())
                                        Image(systemName: "chevron.down")
                                            .font(.title2)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(Color(.label))
                                }
                            } else {
                                Text(weatherVM.currentLocation?.name ?? "ClearWeather")
                                    .font(.largeTitle.bold())
                                    .foregroundStyle(Color(.label))
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    if let weather = weatherVM.currentWeather {
                        WeatherView(weather: weather, weatherVM: weatherVM)
                    } else if weatherVM.isLoading {
                        LoadingView()
                    } else if weatherVM.error != nil {
                        WeatherErrorView()
                    } else {
                        EmptyWeatherView()
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.frame(in: .named("scroll")).minY) { _, value in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isScrolled = value < -16
                            }
                        }
                    }
                )
            }
            .refreshable {
                weatherVM.playHapticFeedback()
                if let location = weatherVM.currentLocation {
                    await weatherVM.fetchWeather(for: location)
                }
            }
            .coordinateSpace(name: "scroll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if isScrolled {
                        if !weatherVM.savedLocations.isEmpty {
                            Button(action: { showLocationPicker.toggle() }) {
                                HStack(spacing: 4) {
                                    Text(weatherVM.currentLocation?.name ?? "Weather")
                                        .font(.headline)
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                            }
                        } else {
                            Text(weatherVM.currentLocation?.name ?? "Weather")
                                .font(.headline)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { weatherVM.toggleTemperatureUnit() }) {
                            Text("°\(weatherVM.useCelsius ? "C" : "F")")
                                .font(.headline)
                        }

                        Button(action: { showLocationSearch = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(weatherVM: weatherVM)
            }
            .sheet(isPresented: $showLocationPicker) {
                NavigationStack {
                    LocationPickerView(weatherVM: weatherVM)
                        .navigationTitle("Locations")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showLocationPicker = false
                                }
                            }
                        }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

struct RefreshableWeatherView: View {
    let weather: WeatherData?
    @ObservedObject var weatherVM: WeatherViewModel
    @Binding var isScrolled: Bool

    var body: some View {
        if let weather = weather {
            WeatherView(weather: weather, weatherVM: weatherVM)
                .refreshable {
                    weatherVM.playHapticFeedback()
                    if let location = weatherVM.currentLocation {
                        await weatherVM.fetchWeather(for: location)
                    }
                }
        } else if weatherVM.isLoading {
            LoadingView()
        } else if weatherVM.error != nil {
            WeatherErrorView()
        } else {
            EmptyWeatherView()
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading weather data...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
}

struct WeatherErrorView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.red)
            Text("Unable to load weather data")
                .font(.headline)
            Text("Please try again later")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
}

struct EmptyWeatherView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            Text("Press the  ") + Text("+").foregroundStyle(.blue).font(.system(size: 22)) + Text("  button to get started")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
}

struct WeatherView: View {
    let weather: WeatherData
    @ObservedObject var weatherVM: WeatherViewModel

    private var dailyHighLow: (high: Double, low: Double) {
        let temps = weather.hourly.map { weatherVM.convertTemp($0.temp) }
        return (temps.max() ?? 0, temps.min() ?? 0)
    }

    // Define columns outside the body
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                mainTemperatureCard

                // Graph and hourly forecast grouped together
                VStack(spacing: 32) {
                    TemperatureGraphView(
                        hourlyData: weather.hourly,
                        dailyData: weather.daily,
                        weatherVM: weatherVM
                    )
                    hourlyForecastCard

                    // Add the new daily forecast view
                    DailyForecastView(dailyData: weather.daily, weatherVM: weatherVM)
                }

                // Weather details at the bottom
                weatherDetailsGrid
            }
            .padding()
        }
    }

    private var mainTemperatureCard: some View {
        VStack(spacing: 8) {
            Text("\(Int(weatherVM.convertTemp(weather.current.temp)))°")
                .font(.system(size: 96, weight: .thin))
                .padding(.top, 8)
                .minimumScaleFactor(0.7)

            Text(weather.current.weather.first?.description.capitalized ?? "")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)

            HStack(spacing: 20) {
                Text("H:\(Int(dailyHighLow.high))°")
                Text("L:\(Int(dailyHighLow.low))°")
            }
            .font(.title3.weight(.medium))
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private var weatherDetailsGrid: some View {
        VStack {
            LazyVGrid(columns: columns, spacing: 16) {
                WeatherDetailCard(
                    title: "Feels Like",
                    value: "\(Int(weatherVM.convertTemp(weather.current.feelsLike)))°",
                    icon: "thermometer"
                )

                WeatherDetailCard(
                    title: "Humidity",
                    value: "\(weather.current.humidity)%",
                    icon: "humidity"
                )

                WeatherDetailCard(
                    title: "Wind Speed",
                    value: "\(Int(weather.current.windSpeed)) km/h",
                    icon: "wind"
                )

                WeatherDetailCard(
                    title: "UV Index",
                    value: "\(Int(weather.current.uvi))",
                    icon: "sun.max"
                )
            }

            // Add the hyperlink below the grid
            HStack {
                Spacer()
                Link(" Weather", destination: URL(string: "https://weatherkit.apple.com/legal-attribution.html")!)
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .underline()
                    .padding(.trailing, 8)
            }
        }
    }

    private var hourlyForecastCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly Forecast")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 16) {
                    ForEach(weather.hourly.prefix(24), id: \.dt) { hourData in
                        HourlyForecastItem(
                            hourData: hourData,
                            weather: weather,
                            weatherVM: weatherVM
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

// Break out the hourly item into its own view
struct HourlyForecastItem: View {
    let hourData: WeatherData.Hourly
    let weather: WeatherData
    @ObservedObject var weatherVM: WeatherViewModel

    private var isCurrentHour: Bool {
        Calendar.current.isDate(
            Date(timeIntervalSince1970: hourData.dt),
            equalTo: Date(),
            toGranularity: .hour
        )
    }

    private var isSunrise: Bool {
        guard let daily = weather.daily.first else { return false }
        let sunriseDate = Date(timeIntervalSince1970: daily.sunrise)
        let hourDate = Date(timeIntervalSince1970: hourData.dt)
        return Calendar.current.isDate(sunriseDate, equalTo: hourDate, toGranularity: .hour)
    }

    private var isSunset: Bool {
        guard let daily = weather.daily.first else { return false }
        let sunsetDate = Date(timeIntervalSince1970: daily.sunset)
        let hourDate = Date(timeIntervalSince1970: hourData.dt)
        return Calendar.current.isDate(sunsetDate, equalTo: hourDate, toGranularity: .hour)
    }

    private var formattedHour: String {
        let date = Date(timeIntervalSince1970: hourData.dt)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: weather.timezone)
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(formattedHour)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)

            if isSunrise {
                Image(systemName: "sunrise.fill")
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                    .frame(minWidth: 44, minHeight: 44)
                    .symbolEffect(.bounce, options: .repeat(2))
            } else if isSunset {
                Image(systemName: "sunset.fill")
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                    .frame(minWidth: 44, minHeight: 44)
                    .symbolEffect(.bounce, options: .repeat(2))
            } else {
                let iconName = if let weatherCondition = hourData.weather.first {
                    weatherCondition.iconName(at: Date(timeIntervalSince1970: hourData.dt), sunEvents: (
                        sunrise: weather.daily.first.map { Date(timeIntervalSince1970: $0.sunrise) },
                        sunset: weather.daily.first.map { Date(timeIntervalSince1970: $0.sunset) }
                    ))
                } else {
                    "sun.max.fill"
                }

                Image(systemName: iconName)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                    .frame(minWidth: 44, minHeight: 44)
                    .symbolEffect(.bounce, options: .repeat(2))
            }

            Text("\(Int(weatherVM.convertTemp(hourData.temp)))°")
                .font(.system(.body, design: .rounded))
                .fontWeight(.medium)
                .frame(minHeight: 44)
                .contentTransition(.numericText())
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background {
            if isCurrentHour {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.08))
            }
        }
    }
}

struct WeatherDetailCard: View {
    let title: String
    let value: String
    let icon: String
    @State private var isAppearing = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .symbolRenderingMode(.hierarchical)
                .imageScale(.large)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
                .textCase(.uppercase)
                .fontWeight(.medium)

            Text(value)
                .font(.title3.bold())
                .minimumScaleFactor(0.75)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
        .opacity(isAppearing ? 1 : 0)
        .offset(y: isAppearing ? 0 : 20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                isAppearing = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .accessibilityAddTraits(.isStaticText)
    }
}

struct TemperatureGraphView: View {
    let hourlyData: [WeatherData.Hourly]
    let dailyData: [WeatherData.Daily]
    @ObservedObject var weatherVM: WeatherViewModel

    // Get all temperature data to calculate overall range
    private var allTemperatures: [Double] {
        hourlyData.map { weatherVM.convertTemp($0.temp) }
    }

    // Calculate temperature range
    private var temperatureRange: (min: Double, max: Double) {
        let minTemp = (allTemperatures.min() ?? 0) - 5
        let maxTemp = (allTemperatures.max() ?? 0) + 5
        return (minTemp, maxTemp)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("24-Hour Forecast")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }

                HStack {
                    Spacer()
                    HStack(spacing: 16) {
                        LegendItem(color: .green, label: "Low")
                        LegendItem(color: .blue, label: "Current")
                        LegendItem(color: .red, label: "High")
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }

            DayGraphView(
                hourlyData: hourlyData,
                weatherVM: weatherVM,
                temperatureRange: temperatureRange
            )
            .frame(height: 220)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

struct DayGraphView: View {
    let hourlyData: [WeatherData.Hourly]
    let weatherVM: WeatherViewModel
    let temperatureRange: (min: Double, max: Double)
    @State private var selectedX: CGFloat?
    @State private var selectedDataPoint: WeatherData.Hourly?
    @State private var chartSize: CGSize = .zero

    // Get data for the full current day
    private var fullDayData: [WeatherData.Hourly] {
        guard let timezone = TimeZone(identifier: weatherVM.currentWeather?.timezone ?? TimeZone.current.identifier) else {
            return hourlyData
        }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return hourlyData
            .filter { hourData in
                let date = Date(timeIntervalSince1970: hourData.dt)
                return date >= startOfDay && date < endOfDay
            }
            .sorted { $0.dt < $1.dt }
    }

    // Get the current temperature data point
    private var currentTemp: WeatherData.Hourly? {
        guard let currentWeather = weatherVM.currentWeather else { return nil }

        // Get the current time in the location's timezone
        let timezone = TimeZone(identifier: currentWeather.timezone) ?? TimeZone.current
        var calendar = Calendar.current
        calendar.timeZone = timezone

        let currentTime = Date(timeIntervalSince1970: currentWeather.current.dt)

        // Find the hourly data point closest to current time
        return fullDayData.min(by: { hourData1, hourData2 in
            abs(hourData1.dt - currentTime.timeIntervalSince1970) <
            abs(hourData2.dt - currentTime.timeIntervalSince1970)
        })
    }

    // Get the day's high and low
    private var dayHighLow: (low: WeatherData.Hourly, high: WeatherData.Hourly) {
        let sortedByTemp = fullDayData.sorted {
            weatherVM.convertTemp($0.temp) < weatherVM.convertTemp($1.temp)
        }
        return (sortedByTemp.first ?? fullDayData[0], sortedByTemp.last ?? fullDayData[0])
    }

    var body: some View {
        VStack(spacing: 4) {
            Chart {
                ForEach(fullDayData, id: \.dt) { hourData in
                    LineMark(
                        x: .value("Time", Date(timeIntervalSince1970: hourData.dt)),
                        y: .value("Temperature", weatherVM.convertTemp(hourData.temp))
                    )
                }
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor.gradient)

                // Low temperature point
                PointMark(
                    x: .value("Time", Date(timeIntervalSince1970: dayHighLow.low.dt)),
                    y: .value("Temperature", weatherVM.convertTemp(dayHighLow.low.temp))
                )
                .foregroundStyle(Color.green)
                .symbolSize(50)
                .annotation(position: .bottom) {
                    Text("\(Int(weatherVM.convertTemp(dayHighLow.low.temp)))°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // High temperature point
                PointMark(
                    x: .value("Time", Date(timeIntervalSince1970: dayHighLow.high.dt)),
                    y: .value("Temperature", weatherVM.convertTemp(dayHighLow.high.temp))
                )
                .foregroundStyle(Color.red)
                .symbolSize(50)
                .annotation(position: .top) {
                    Text("\(Int(weatherVM.convertTemp(dayHighLow.high.temp)))°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Current temperature point
                if let current = currentTemp {
                    PointMark(
                        x: .value("Time", Date(timeIntervalSince1970: current.dt)),
                        y: .value("Temperature", weatherVM.convertTemp(current.temp))
                    )
                    .foregroundStyle(Color.blue)
                    .symbolSize(80)
                    .annotation(position: .top) {
                        Text("\(Int(weatherVM.convertTemp(current.temp)))°")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let selected = selectedDataPoint {
                    RuleMark(
                        x: .value("Time", Date(timeIntervalSince1970: selected.dt))
                    )
                    .foregroundStyle(.gray.opacity(0.3))

                    RuleMark(
                        y: .value("Temperature", weatherVM.convertTemp(selected.temp))
                    )
                    .foregroundStyle(.gray.opacity(0.3))

                    PointMark(
                        x: .value("Time", Date(timeIntervalSince1970: selected.dt)),
                        y: .value("Temperature", weatherVM.convertTemp(selected.temp))
                    )
                    .foregroundStyle(.primary)
                    .symbolSize(100)
                }
            }
            .chartXScale(domain: {
                guard let timezone = TimeZone(identifier: weatherVM.currentWeather?.timezone ?? TimeZone.current.identifier) else {
                    return Date()...Date().addingTimeInterval(86400)
                }

                var calendar = Calendar.current
                calendar.timeZone = timezone
                let now = Date()
                let startOfDay = calendar.startOfDay(for: now)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

                return startOfDay...endOfDay
            }())
            .chartYScale(domain: temperatureRange.min...temperatureRange.max)
            .chartXAxis {
                AxisMarks(position: .bottom, values: .stride(by: .hour, count: 3)) { value in
                    if let date = value.as(Date.self),
                       let timezone = TimeZone(identifier: weatherVM.currentWeather?.timezone ?? TimeZone.current.identifier) {
                        let calendar = Calendar.current
                        let dateComponents = calendar.dateComponents(in: timezone, from: date)
                        let hour = dateComponents.hour ?? 0
                        AxisValueLabel {
                            Text(formatHour(hour))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        AxisTick()
                        AxisGridLine()
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 5)) { value in
                    if let temp = value.as(Double.self) {
                        AxisValueLabel {
                            Text("\(Int(temp))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        AxisGridLine()
                    }
                }
            }
            .frame(height: 180)
            .padding(.bottom, 24)
            .overlay {
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        chartSize = proxy.size
                    }
                    if let selectedDataPoint = selectedDataPoint {
                        let indicatorWidth: CGFloat = 100 // Approximate width of the indicator
                        let padding: CGFloat = 8

                        // Calculate x position with bounds checking
                        let xPosition = min(
                            max(selectedX ?? 0, indicatorWidth/2 + padding),
                            proxy.size.width - indicatorWidth/2 - padding
                        )

                        VStack(spacing: 4) {
                            Text(formatTime(Date(timeIntervalSince1970: selectedDataPoint.dt)))
                                .font(.caption)
                            Text("\(Int(weatherVM.convertTemp(selectedDataPoint.temp)))°")
                                .font(.caption.bold())
                        }
                        .padding(8)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.regularMaterial)
                                .opacity(0.5)
                        }
                        .frame(width: indicatorWidth)
                        .position(
                            x: xPosition,
                            y: proxy.size.height * 0.2
                        )
                    }
                }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.05)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            if let drag = drag {
                                guard let timezone = TimeZone(identifier: weatherVM.currentWeather?.timezone ?? TimeZone.current.identifier) else { return }
                                var calendar = Calendar.current
                                calendar.timeZone = timezone

                                let startOfDay = calendar.startOfDay(for: Date())
                                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                                let totalSeconds = endOfDay.timeIntervalSince(startOfDay)
                                let secondsPerPoint = totalSeconds / Double(chartSize.width)
                                let currentSeconds = Double(drag.location.x) * secondsPerPoint
                                let currentTime = startOfDay.addingTimeInterval(currentSeconds)

                                // Instead of finding the closest data point, interpolate between points
                                let timestamp = currentTime.timeIntervalSince1970

                                // Find the two closest data points
                                let sortedData = fullDayData.sorted { $0.dt < $1.dt }
                                if let beforePoint = sortedData.last(where: { $0.dt <= timestamp }),
                                   let afterPoint = sortedData.first(where: { $0.dt > timestamp }) {
                                    // Calculate interpolation factor (0 to 1)
                                    let factor = (timestamp - beforePoint.dt) / (afterPoint.dt - beforePoint.dt)

                                    // Interpolate temperature
                                    let interpolatedTemp = beforePoint.temp + (afterPoint.temp - beforePoint.temp) * factor

                                    // Create an interpolated data point
                                    selectedDataPoint = WeatherData.Hourly(
                                        dt: timestamp,
                                        temp: interpolatedTemp,
                                        weather: beforePoint.weather
                                    )
                                } else {
                                    // If we can't interpolate, use the closest point
                                    selectedDataPoint = fullDayData.min(by: {
                                        abs($0.dt - timestamp) < abs($1.dt - timestamp)
                                    })
                                }
                                selectedX = drag.location.x
                            }
                        default:
                            break
                        }
                    }
                    .onEnded { value in
                        selectedDataPoint = nil
                        selectedX = nil
                    }
            )
        }
    }

    private func formatTime(_ date: Date) -> String {
        guard let timezone = TimeZone(identifier: weatherVM.currentWeather?.timezone ?? TimeZone.current.identifier) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour < 12 ? "AM" : "PM"
        switch hour {
        case 0: return "12\(period)"
        case 12: return "12\(period)"
        case 13...23: return "\(hour-12)\(period)"
        default: return "\(hour)\(period)"
        }
    }
}

// Helper view for legend items
struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) temperature indicator")
    }
}

// Add this new view for the location picker
struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var weatherVM: WeatherViewModel

    var body: some View {
        List {
            ForEach(weatherVM.savedLocations) { location in
                Button(action: {
                    weatherVM.currentLocation = location
                    Task {
                        await weatherVM.fetchWeather(for: location)
                    }
                    dismiss()
                }) {
                    HStack {
                        Text(location.name)
                        if location.id == weatherVM.currentLocation?.id {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .onDelete { indexSet in
                weatherVM.savedLocations.remove(atOffsets: indexSet)
                weatherVM.saveLocations()

                // If we deleted the current location, update it
                if !weatherVM.savedLocations.contains(where: { $0.id == weatherVM.currentLocation?.id }) {
                    weatherVM.currentLocation = weatherVM.savedLocations.first
                    if let location = weatherVM.currentLocation {
                        Task {
                            await weatherVM.fetchWeather(for: location)
                        }
                    }
                }
            }
        }
    }
}

// Add this extension to get weather icons
extension WeatherData.Weather {
    // Simple icon name without day/night variants
    var iconName: String {
        getDayOrNightIcon(isDay: true) // Default to day icons for simple cases
    }

    // Icon name with day/night variants
    func iconName(at date: Date, sunEvents: (sunrise: Date?, sunset: Date?)) -> String {
        let isDay = isDayTime(at: date, sunEvents: sunEvents)
        return getDayOrNightIcon(isDay: isDay)
    }

    // Helper function to get the icon name based on weather condition
    func getDayOrNightIcon(isDay: Bool) -> String {
        switch main.lowercased() {
        case "thunderstorm", "thunder":
            return isDay ? "cloud.bolt.rain.fill" : "cloud.moon.bolt.fill"
        case "drizzle", "lightrain":
            return isDay ? "cloud.drizzle.fill" : "cloud.moon.rain.fill"
        case "rain", "showers":
            if description.contains("light") || description.contains("Light") {
                return isDay ? "cloud.drizzle.fill" : "cloud.moon.rain.fill"
            } else if description.contains("heavy") || description.contains("Heavy") {
                return isDay ? "cloud.heavyrain.fill" : "cloud.moon.rain.fill"
            }
            return isDay ? "cloud.rain.fill" : "cloud.moon.rain.fill"
        case "snow", "blizzard", "wintry":
            if description.contains("sleet") || description.contains("Sleet") {
                return "cloud.sleet.fill"
            } else if description.contains("heavy") || description.contains("Heavy") {
                return "cloud.snow.fill"
            }
            return "cloud.snow.fill"
        case "fog", "mist", "haze", "foggy", "misty", "hazy":
            return isDay ? "cloud.fog.fill" : "cloud.fog.night.fill"
        case "cloudy", "clouds", "overcast", "mostlycloudy", "partlycloudy":
            if description.contains("few") || description.contains("scattered") ||
               description.contains("partly") || description.contains("Partly") {
                return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
            } else if description.contains("broken") || description.contains("overcast") ||
                      description.contains("mostly") || description.contains("Mostly") {
                return "cloud.fill"
            }
            return "cloud.fill"
        case "clear", "sunny", "fair":
            return isDay ? "sun.max.fill" : "moon.fill"
        case "dust", "sand", "dusty", "sandy":
            return "sun.dust.fill"
        case "smoke", "smoky":
            return "smoke.fill"
        case "tornado", "waterspout":
            return "tornado"
        case "squall", "windy", "blustery":
            return "wind"
        case "ash":
            return "smoke.fill"
        case "mostlyclear":
            return isDay ? "sun.max.fill" : "moon.fill"
        default:
            print("Unhandled weather condition: \(main) - \(description)")
            return isDay ? "sun.max.fill" : "moon.fill"
        }
    }

    private func isDayTime(at date: Date, sunEvents: (sunrise: Date?, sunset: Date?)) -> Bool {
        guard let sunrise = sunEvents.sunrise,
              let sunset = sunEvents.sunset else {
            // Default to using 6 AM to 6 PM if no sun events
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: date)
            return hour >= 6 && hour < 18
        }

        // If the time is before sunrise or after sunset, it's night
        return date >= sunrise && date < sunset
    }
}

// Add this new view for daily forecast
struct DailyForecastView: View {
    let dailyData: [WeatherData.Daily]
    @ObservedObject var weatherVM: WeatherViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("8-Day Forecast")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(dailyData.prefix(8), id: \.dt) { day in
                    DailyForecastRow(day: day, weatherVM: weatherVM)

                    if day.dt != dailyData.prefix(8).last?.dt {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

struct DailyForecastRow: View {
    let day: WeatherData.Daily
    @ObservedObject var weatherVM: WeatherViewModel

    private var dayName: String {
        let date = Date(timeIntervalSince1970: day.dt)
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        if Calendar.current.isDateInToday(date) {
            return "Today"
        }
        return formatter.string(from: date)
    }

    private var iconName: String {
        if let weather = day.weather.first {
            return weather.getDayOrNightIcon(isDay: true)
        }
        return "sun.max.fill"
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(dayName)
                .frame(width: 52, alignment: .leading)
                .font(.body)
                .foregroundStyle(.primary)

            Image(systemName: iconName)
                .symbolRenderingMode(.multicolor)
                .font(.title2)
                .frame(width: 44, height: 44)

            Spacer()

            // Temperature range with gradient bar
            HStack(alignment: .center, spacing: 8) {
                Text("\(Int(weatherVM.convertTemp(day.temp.min)))°")
                    .foregroundStyle(.secondary)

                GeometryReader { geometry in
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.blue, .orange]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geometry.size.width, height: 4)
                }
                .frame(width: 50, height: 4)

                Text("\(Int(weatherVM.convertTemp(day.temp.max)))°")
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dayName), High of \(Int(weatherVM.convertTemp(day.temp.max))) degrees, Low of \(Int(weatherVM.convertTemp(day.temp.min))) degrees, \(day.weather.first?.description ?? "")")
    }
}

#Preview {
    ContentView()
}
