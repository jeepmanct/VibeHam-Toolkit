import SwiftUI
import CoreLocation

struct ToolsView: View {
    @State private var gridInput = ""
    @State private var gridCoord: CLLocationCoordinate2D?

    @State private var latA = ""
    @State private var lonA = ""
    @State private var latB = ""
    @State private var lonB = ""
    @State private var distanceResult: String?
    @State private var bearingResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Callsign Lookup") {
                    NavigationLink("QRZ.com Lookup") {
                        QRZLookupView()
                    }
                }

                Section("Grid Square") {
                    TextField("Enter grid (e.g. FN31pr)", text: $gridInput)
                        .autocapitalization(.allCharacters)
                        .onChange(of: gridInput) { _, new in
                            gridCoord = GridUtility.coordinate(from: new)
                        }
                    if let coord = gridCoord {
                        Text("Lat: \(String(format: "%.4f", coord.latitude)), Lon: \(String(format: "%.4f", coord.longitude))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Distance & Bearing") {
                    HStack {
                        TextField("Lat A", text: $latA).keyboardType(.decimalPad)
                        TextField("Lon A", text: $lonA).keyboardType(.decimalPad)
                    }
                    HStack {
                        TextField("Lat B", text: $latB).keyboardType(.decimalPad)
                        TextField("Lon B", text: $lonB).keyboardType(.decimalPad)
                    }
                    Button("Calculate") {
                        calculateDistanceBearing()
                    }
                    if let distance = distanceResult, let bearing = bearingResult {
                        Text("Distance: \(distance) miles")
                        Text("Bearing: \(bearing)°")
                    }
                }
            }
            .navigationTitle("Tools")
        }
    }

    private func calculateDistanceBearing() {
        guard let la = Double(latA), let loA = Double(lonA),
              let lb = Double(latB), let loB = Double(lonB) else { return }
        let a = CLLocationCoordinate2D(latitude: la, longitude: loA)
        let b = CLLocationCoordinate2D(latitude: lb, longitude: loB)
        distanceResult = String(format: "%.1f", GridUtility.distance(from: a, to: b))
        bearingResult = String(format: "%.1f", GridUtility.bearing(from: a, to: b))
    }
}

#Preview {
    ToolsView()
}
