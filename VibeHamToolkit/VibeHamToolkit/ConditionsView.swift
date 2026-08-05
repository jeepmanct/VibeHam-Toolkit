import SwiftUI
import SwiftData

@MainActor
final class ConditionsViewModel: ObservableObject {
    @Published var sfi: String = "--"
    @Published var aIndex: String = "--"
    @Published var kIndex: String = "--"
    @Published var sunspotNumber: String = "--"
    @Published var status: String = "Tap refresh to load"

    @Published var storedDays: Int = 0
    @Published var storedRange: String = ""
    @Published var solarSyncStatus: String = ""
    @Published var isSyncingSolar = false

    func refresh() async {
        status = "Loading..."
        do {
            let flux = try await fetchJSON(url: URL(string: "https://services.swpc.noaa.gov/products/summary/10cm-flux.json")!)
            let aIndexArr = try await fetchJSONArray(url: URL(string: "https://services.swpc.noaa.gov/json/predicted_fredericksburg_a_index.json")!)
            let kArr = try await fetchJSONArray(url: URL(string: "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json")!)
            let sunspot = try await fetchSunspot()

            sfi = string(from: flux["flux"])
            aIndex = string(from: aIndexArr.first?["afred_1_day"])
            kIndex = string(from: kArr.last?["kp_index"])
            sunspotNumber = sunspot ?? "--"
            status = "Updated \(Date().formatted(date: .abbreviated, time: .shortened))"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    func loadStoredCount(context: ModelContext) {
        let descriptor = FetchDescriptor<SolarDataPoint>(sortBy: [SortDescriptor<SolarDataPoint>(\.date)])
        guard let points = try? context.fetch(descriptor) else { return }
        storedDays = points.count
        if let first = points.first?.date, let last = points.last?.date {
            storedRange = "\(format(date: first)) - \(format(date: last))"
        }
    }

    func syncHistorical(context: ModelContext) async {
        isSyncingSolar = true
        solarSyncStatus = "Downloading GFZ Potsdam data..."
        do {
            let records = try await SolarDataService.shared.fetchAndParse()
            solarSyncStatus = "Importing \(records.count) days..."

            let descriptor = FetchDescriptor<SolarDataPoint>()
            let existing = (try? context.fetch(descriptor)) ?? []
            let existingByDate = Dictionary(uniqueKeysWithValues: existing.map { ($0.date, $0) })

            for record in records {
                if let point = existingByDate[record.date] {
                    point.sfi = record.sfi
                    point.sfiAdjusted = record.sfiAdjusted
                    point.aIndex = record.aIndex
                    point.kIndex = record.kIndex
                    point.kIndexMax = record.kIndexMax
                    point.sunspotNumber = record.sunspotNumber
                    point.updatedAt = Date()
                } else {
                    let point = SolarDataPoint(
                        date: record.date,
                        sfi: record.sfi,
                        sfiAdjusted: record.sfiAdjusted,
                        aIndex: record.aIndex,
                        kIndex: record.kIndex,
                        kIndexMax: record.kIndexMax,
                        sunspotNumber: record.sunspotNumber
                    )
                    context.insert(point)
                }
            }
            try context.save()
            loadStoredCount(context: context)
            solarSyncStatus = "Synced \(records.count) days."
        } catch {
            solarSyncStatus = "Sync failed: \(error.localizedDescription)"
        }
        isSyncingSolar = false
    }

    private func format(date: String) -> String {
        guard date.count == 8 else { return date }
        let year = String(date.prefix(4))
        let month = String(date[date.index(date.startIndex, offsetBy: 4)..<date.index(date.startIndex, offsetBy: 6)])
        let day = String(date[date.index(date.startIndex, offsetBy: 6)..<date.index(date.startIndex, offsetBy: 8)])
        return "\(year)-\(month)-\(day)"
    }

    private func string(from value: Any?) -> String {
        if let number = value as? NSNumber { return number.stringValue }
        if let string = value as? String { return string }
        return "--"
    }

    private func fetchJSON(url: URL) async throws -> [String: Any] {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }

    private func fetchJSONArray(url: URL) async throws -> [[String: Any]] {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }

    private func fetchSunspot() async throws -> String? {
        let url = URL(string: "https://www.sidc.be/SILSO/INFO/sndtotcsv.php")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\n").filter { !$0.isEmpty }
        guard let last = lines.last else { return nil }
        let parts = last.split(separator: ";", omittingEmptySubsequences: false)
        if parts.count > 4 {
            let value = parts[4].trimmingCharacters(in: .whitespaces)
            return value.isEmpty ? nil : value
        }
        return nil
    }
}

struct ConditionsView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel = ConditionsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Solar & Geomagnetic (Today)") {
                    ConditionRow(label: "Solar Flux Index", value: viewModel.sfi, unit: "sfu")
                    ConditionRow(label: "A-Index", value: viewModel.aIndex)
                    ConditionRow(label: "K-Index", value: viewModel.kIndex)
                    ConditionRow(label: "Sunspot Number", value: viewModel.sunspotNumber)
                }
                Section {
                    Text(viewModel.status).font(.caption).foregroundStyle(.secondary)
                }

                Section("Historical Solar Data") {
                    ConditionRow(label: "Stored days", value: "\(viewModel.storedDays)")
                    if !viewModel.storedRange.isEmpty {
                        ConditionRow(label: "Range", value: viewModel.storedRange)
                    }
                    Button("Sync Historical Data") {
                        Task { await viewModel.syncHistorical(context: context) }
                    }
                    .disabled(viewModel.isSyncingSolar)
                    if !viewModel.solarSyncStatus.isEmpty {
                        Text(viewModel.solarSyncStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Space Weather")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .onAppear {
                viewModel.loadStoredCount(context: context)
            }
        }
    }
}

struct ConditionRow: View {
    let label: String
    let value: String
    var unit: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value + (unit.isEmpty ? "" : " \(unit)"))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ConditionsView()
}
