import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \QSO.qsoDate) private var qsos: [QSO]

    private var total: Int { qsos.count }
    private var confirmed: Int { qsos.filter { $0.lotwQslRcvd?.uppercased() == "Y" }.count }

    private func counts(_ keyPath: KeyPath<QSO, String?>) -> [(String, Int)] {
        var map: [String: Int] = [:]
        for qso in qsos {
            if let value = qso[keyPath: keyPath], !value.isEmpty {
                map[value, default: 0] += 1
            }
        }
        return map.sorted { $0.value > $1.value }
    }

    private var uniqueCountries: [String] {
        Set(qsos.compactMap { $0.country }).filter { !$0.isEmpty }.sorted()
    }

    private var uniqueStates: [String] {
        Set(qsos.compactMap { $0.state }).filter { !$0.isEmpty }.sorted()
    }

    private var yearCounts: [(String, Int)] {
        var map: [String: Int] = [:]
        for qso in qsos {
            let year = String(qso.qsoDate.prefix(4))
            map[year, default: 0] += 1
        }
        return map.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    StatRow(label: "Total QSOs", value: "\(total)")
                    StatRow(label: "LoTW Confirmed", value: "\(confirmed)")
                    StatRow(label: "DXCC Entities", value: "\(uniqueCountries.count)")
                    StatRow(label: "US States", value: "\(uniqueStates.count)")
                }

                Section("By Band") {
                    ForEach(counts(\.band), id: \.0) { name, count in
                        StatRow(label: name, value: "\(count)")
                    }
                }

                Section("By Mode") {
                    ForEach(counts(\.mode), id: \.0) { name, count in
                        StatRow(label: name, value: "\(count)")
                    }
                }

                Section("By Year") {
                    ForEach(yearCounts, id: \.0) { year, count in
                        StatRow(label: year, value: "\(count)")
                    }
                }
            }
            .navigationTitle("Stats")
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).font(.headline).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [QSO.self], inMemory: true)
}
