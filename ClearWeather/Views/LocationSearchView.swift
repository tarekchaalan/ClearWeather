import SwiftUI
import CoreLocation

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [Location] = []
    @State private var isSearching = false
    @State private var error: Error?

    let weatherVM: WeatherViewModel
    private let searchCompleter = CLGeocoder()

    var body: some View {
        NavigationStack {
            List {
                // Locate Me Button
                Button(action: requestLocation) {
                    Label("Current Location", systemImage: "location.fill")
                }

                // Search Results
                if isSearching {
                    ProgressView()
                } else {
                    ForEach(searchResults) { location in
                        Button(action: { selectLocation(location) }) {
                            VStack(alignment: .leading) {
                                Text(location.name)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText)
            .onChange(of: searchText) { _, newValue in
                guard !newValue.isEmpty else {
                    searchResults = []
                    return
                }
                searchLocation(query: newValue)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func searchLocation(query: String) {
        guard !query.isEmpty else { return }

        isSearching = true
        searchCompleter.geocodeAddressString(query) { places, error in
            isSearching = false

            if let error = error {
                self.error = error
                return
            }

            searchResults = places?.compactMap { place in
                guard let name = place.name ?? place.locality else { return nil }
                return Location(
                    name: name,
                    latitude: place.location?.coordinate.latitude ?? 0,
                    longitude: place.location?.coordinate.longitude ?? 0
                )
            } ?? []
        }
    }

    private func selectLocation(_ location: Location) {
        weatherVM.savedLocations.append(location)
        weatherVM.currentLocation = location
        weatherVM.saveLocations()
        Task {
            await weatherVM.fetchWeather(for: location)
        }
        dismiss()
    }

    private func requestLocation() {
        weatherVM.requestLocation { location in
            if let location = location {
                selectLocation(location)
            }
        }
    }
}

#Preview {
    LocationSearchView(weatherVM: WeatherViewModel())
}