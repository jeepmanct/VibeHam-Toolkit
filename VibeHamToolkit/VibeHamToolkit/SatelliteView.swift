import SwiftUI
import SwiftData
import CoreLocation

@MainActor
final class SatelliteViewModel: ObservableObject {
    @Published var satellites: [Satellite] = []
    @Published var isLoading = false
    @Published var message = ""

    private var context: ModelContext?

    func setContext(_ context: ModelContext) {
        self.context = context
        load()
    }

    func load() {
        guard let context = context else { return }
        let descriptor = FetchDescriptor<Satellite>(sortBy: [SortDescriptor<Satellite>(\.name)])
        satellites = (try? context.fetch(descriptor)) ?? []
        if satellites.isEmpty {
            seed()
        }
    }

    private func seed() {
        guard let context = context else { return }
        let defaults = [
            Satellite(noradId: 25544, name: "ISS (Crossband Repeater)", mode: "FM Voice", uplink: "145.990 MHz (67.0 Hz PL)", downlink: "437.800 MHz", notes: "Crew sometimes reconfigures for packet/SSTV."),
            Satellite(noradId: 27607, name: "SO-50", mode: "FM Voice", uplink: "145.850 MHz (67.0 Hz PL)", downlink: "436.795 MHz", notes: "Beginner-friendly FM bird."),
            Satellite(noradId: 43017, name: "AO-91 (RadFxSat / Fox-1B)", mode: "FM Voice", uplink: "435.250 MHz (67.0 Hz PL)", downlink: "145.960 MHz", notes: ""),
            Satellite(noradId: 7530, name: "AO-7", mode: "SSB/CW Linear", uplink: "432.125-432.175 MHz", downlink: "145.925-145.975 MHz", notes: "Only transmits in direct sunlight."),
            Satellite(noradId: 24278, name: "FO-29", mode: "SSB/CW Linear", uplink: "145.900-146.000 MHz", downlink: "435.800-435.900 MHz", notes: "Inverting transponder."),
            Satellite(noradId: 44909, name: "RS-44", mode: "SSB/CW Linear", uplink: "435.130-435.150 MHz (LSB)", downlink: "145.950-145.970 MHz (USB)", notes: "Inverting transponder, strong signal."),
        ]
        for sat in defaults { context.insert(sat) }
        try? context.save()
        satellites = defaults
    }

    func refreshTLEs() async {
        guard let context = context else { return }
        isLoading = true
        defer { isLoading = false }
        var updated = 0
        for sat in satellites where sat.enabled {
            do {
                let tle = try await SatelliteService.shared.fetchTLE(for: sat.noradId)
                sat.tleLine1 = tle.line1
                sat.tleLine2 = tle.line2
                sat.updatedAt = Date()
                updated += 1
            } catch {
                print("TLE fetch failed for \(sat.name): \(error)")
            }
        }
        try? context.save()
        message = "Updated \(updated) TLE sets."
    }
}

struct SatelliteView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = SatelliteViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(viewModel.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.satellites) { sat in
                    NavigationLink(value: sat) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sat.name).font(.headline)
                            Text(sat.mode).font(.subheadline).foregroundStyle(.secondary)
                            HStack {
                                Text("DL: \(sat.downlink)").font(.caption)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { sat.enabled },
                                    set: { _ in toggle(sat) }
                                ))
                                .labelsHidden()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Satellites")
            .navigationDestination(for: Satellite.self) { sat in
                SatelliteDetailView(satellite: sat)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await viewModel.refreshTLEs() } } label: {
                        Label("Refresh TLEs", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .onAppear {
                viewModel.setContext(context)
            }
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
        }
    }

    private func toggle(_ sat: Satellite) {
        sat.enabled.toggle()
        try? context.save()
    }
}

struct SatelliteDetailView: View {
    @Environment(\.modelContext) private var context
    let satellite: Satellite
    @State private var passes: [SatellitePass] = []
    @State private var isComputing = false

    var body: some View {
        Form {
            Section("Frequencies") {
                LabeledContent("Uplink", value: satellite.uplink)
                LabeledContent("Downlink", value: satellite.downlink)
            }
            Section("Notes") {
                Text(satellite.notes)
            }
            Section {
                Button("Compute Passes") {
                    Task { compute() }
                }
                .disabled(isComputing)
            }
            if !passes.isEmpty {
                Section("Next Passes (approximate)") {
                    ForEach(passes.prefix(10), id: \.start) { pass in
                        VStack(alignment: .leading) {
                            Text(pass.start.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                            Text("Peak: \(pass.peak.formatted(date: .omitted, time: .shortened)) · \(String(format: "%.1f", pass.maxElevation))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(satellite.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func compute() {
        guard let line1 = satellite.tleLine1, !line1.isEmpty,
              let line2 = satellite.tleLine2, !line2.isEmpty else {
            passes = []
            return
        }
        isComputing = true
        let profile = UserProfile.fetchOrCreate(in: context)
        let coord = CLLocationCoordinate2D(latitude: profile.latitude, longitude: profile.longitude)
        Task {
            do {
                let tle = try await SatelliteService.shared.parseTLE(name: satellite.name, line1: line1, line2: line2)
                passes = await SatelliteService.shared.predictPasses(tle: tle, observer: coord, minElevation: 10, hours: 48)
            } catch {
                passes = []
            }
            isComputing = false
        }
    }
}

#Preview {
    SatelliteView()
        .modelContainer(for: [Satellite.self, UserProfile.self], inMemory: true)
}
