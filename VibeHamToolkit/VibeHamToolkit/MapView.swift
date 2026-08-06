import SwiftUI
import SwiftData
import MapKit

struct MapView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<QSO>(\.qsoDate, order: .reverse)]) private var qsos: [QSO]

    @State private var position: MapCameraPosition = .automatic
    @State private var showingFilters = false
    @State private var appliedFilter = QSOFilter()
    @State private var displayedAnnotations: [QSOAnnotation] = []
    @State private var statusMessage: String? = "Set filters, then tap Show to map matching QSOs."

    private let maxAnnotations = 1_000

    private var availableBands: [String] {
        Set(qsos.compactMap { $0.band }).sorted()
    }

    private var availableModes: [String] {
        Set(qsos.compactMap { $0.mode }).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Map(position: $position) {
                    ForEach(displayedAnnotations) { annotation in
                        Annotation(annotation.qso.call, coordinate: annotation.coordinate) {
                            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
                .mapStyle(.standard)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 8)
                        .multilineTextAlignment(.center)
                }
            }
            .navigationTitle("QSO Map")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingFilters = true } label: {
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .badge(appliedFilter.isActive ? "●" : "")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { applyFilter() } label: {
                        Label("Show", systemImage: "mappin.and.ellipse")
                    }
                    Button { fitAnnotations() } label: {
                        Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .disabled(displayedAnnotations.isEmpty)
                }
            }
            .sheet(isPresented: $showingFilters) {
                MapFilterSheet(
                    filter: $appliedFilter,
                    bands: availableBands,
                    modes: availableModes,
                    totalQSOs: qsos.count,
                    onApply: {
                        applyFilter()
                        showingFilters = false
                    }
                )
            }
        }
    }

    private func applyFilter() {
        let matching = qsos.filter(appliedFilter.matches)
        let mappable = matching.filter { ($0.gridsquare ?? "").count >= 4 }

        guard !matching.isEmpty else {
            displayedAnnotations = []
            statusMessage = "No QSOs match the current filters."
            return
        }

        guard !mappable.isEmpty else {
            displayedAnnotations = []
            statusMessage = "\(matching.count) QSOs match, but none have a gridsquare to map."
            return
        }

        guard mappable.count <= maxAnnotations else {
            displayedAnnotations = []
            statusMessage = "\(mappable.count) QSOs to map (limit \(maxAnnotations)). Narrow filters to display."
            return
        }

        displayedAnnotations = mappable.compactMap { qso in
            guard let coord = GridUtility.coordinate(from: qso.gridsquare!) else { return nil }
            return QSOAnnotation(qso: qso, coordinate: coord)
        }

        statusMessage = "Showing \(displayedAnnotations.count) of \(matching.count) matching QSOs."
        fitAnnotations()
    }

    private func fitAnnotations() {
        guard !displayedAnnotations.isEmpty else { return }
        let rect = displayedAnnotations.reduce(MKMapRect.null) { rect, ann in
            let point = MKMapPoint(ann.coordinate)
            return rect.union(MKMapRect(x: point.x, y: point.y, width: 1, height: 1))
        }
        let padded = rect.insetBy(dx: -rect.width * 0.1, dy: -rect.height * 0.1)
        withAnimation {
            position = .rect(padded)
        }
    }
}

struct QSOAnnotation: Identifiable {
    let id = UUID()
    let qso: QSO
    let coordinate: CLLocationCoordinate2D
}

struct QSOFilter: Equatable {
    var callsign = ""
    var band = ""
    var mode = ""
    var startDate: Date?
    var endDate: Date?
    var potaOnly = false
    var sotaOnly = false

    var isActive: Bool {
        !callsign.isEmpty || !band.isEmpty || !mode.isEmpty || startDate != nil || endDate != nil || potaOnly || sotaOnly
    }

    func matches(_ qso: QSO) -> Bool {
        let lower = callsign.lowercased()
        if !lower.isEmpty {
            guard qso.call.lowercased().contains(lower) else { return false }
        }
        if !band.isEmpty, qso.band != band { return false }
        if !mode.isEmpty, qso.mode != mode { return false }
        if potaOnly, (qso.potaRef ?? "").isEmpty { return false }
        if sotaOnly, (qso.sotaRef ?? "").isEmpty { return false }

        if startDate != nil || endDate != nil {
            guard let qsoDate = qsoDate(from: qso.qsoDate) else { return false }
            if let start = startDate, qsoDate < start { return false }
            if let end = endDate, qsoDate > end { return false }
        }

        return true
    }

    private func qsoDate(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: string)
    }
}

struct MapFilterSheet: View {
    @Binding var filter: QSOFilter
    let bands: [String]
    let modes: [String]
    let totalQSOs: Int
    let onApply: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    TextField("Callsign contains", text: $filter.callsign)
                        .autocapitalization(.allCharacters)
                }

                Section("Band & Mode") {
                    Picker("Band", selection: $filter.band) {
                        Text("Any").tag("")
                        ForEach(bands, id: \.self) { band in
                            Text(band).tag(band)
                        }
                    }
                    Picker("Mode", selection: $filter.mode) {
                        Text("Any").tag("")
                        ForEach(modes, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }
                }

                Section("Date Range") {
                    DatePicker("From", selection: dateBinding(for: $filter.startDate), displayedComponents: .date)
                    DatePicker("To", selection: dateBinding(for: $filter.endDate), displayedComponents: .date)
                }

                Section("Programs") {
                    Toggle("POTA contacts only", isOn: $filter.potaOnly)
                    Toggle("SOTA contacts only", isOn: $filter.sotaOnly)
                }

                Section {
                    Button(role: .destructive) {
                        filter = QSOFilter()
                    } label: {
                        Text("Clear Filters")
                    }
                    .disabled(!filter.isActive)

                    Text("\(totalQSOs) total QSOs in logbook.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Map Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Show on Map") {
                        onApply()
                    }
                }
            }
        }
    }

    private func dateBinding(for binding: Binding<Date?>) -> Binding<Date> {
        Binding(
            get: { binding.wrappedValue ?? Date() },
            set: { binding.wrappedValue = $0 }
        )
    }
}

#Preview {
    MapView()
        .modelContainer(for: [UserProfile.self, QSO.self], inMemory: true)
}
