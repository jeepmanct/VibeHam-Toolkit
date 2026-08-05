import SwiftUI
import SwiftData

@MainActor
final class ConditionsViewModel: ObservableObject {
    @Published var sfi: String = "--"
    @Published var aIndex: String = "--"
    @Published var kIndex: String = "--"
    @Published var sunspotNumber: String = "--"
    @Published var status: String = "Tap refresh to load"

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
    @StateObject private var viewModel = ConditionsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Solar & Geomagnetic") {
                    ConditionRow(label: "Solar Flux Index", value: viewModel.sfi, unit: "sfu")
                    ConditionRow(label: "A-Index", value: viewModel.aIndex)
                    ConditionRow(label: "K-Index", value: viewModel.kIndex)
                    ConditionRow(label: "Sunspot Number", value: viewModel.sunspotNumber)
                }
                Section {
                    Text(viewModel.status).font(.caption).foregroundStyle(.secondary)
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
