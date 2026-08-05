import SwiftUI
import SwiftData

struct AwardsView: View {
    @Query private var qsos: [QSO]

    private var dxccEntities: Set<String> {
        Set(qsos.compactMap { $0.country }.filter { !$0.isEmpty })
    }

    private var usStates: Set<String> {
        Set(qsos.compactMap { $0.state }.filter { !$0.isEmpty })
    }

    private var potaParks: Set<String> {
        Set(qsos.compactMap { $0.potaRef }.filter { !$0.isEmpty })
    }

    private var iotaRefs: Set<String> {
        Set(qsos.compactMap { $0.iota }.filter { !$0.isEmpty })
    }

    private var cqZones: Set<String> {
        Set(qsos.compactMap { $0.cqz }.filter { !$0.isEmpty })
    }

    var body: some View {
        NavigationStack {
            List {
                AwardRow(title: "DXCC Challenge", count: dxccEntities.count, target: 340)
                AwardRow(title: "Worked All States", count: usStates.count, target: 50)
                AwardRow(title: "POTA Hunter", count: potaParks.count, target: nil)
                AwardRow(title: "IOTA", count: iotaRefs.count, target: nil)
                AwardRow(title: "CQ Zones", count: cqZones.count, target: 40)

                Section("DXCC Entities") {
                    ForEach(dxccEntities.sorted(), id: \.self) { entity in
                        Text(entity)
                    }
                }

                Section("US States") {
                    ForEach(usStates.sorted(), id: \.self) { state in
                        Text(state)
                    }
                }

                Section("POTA Parks") {
                    ForEach(potaParks.sorted(), id: \.self) { park in
                        Text(park)
                    }
                }

                Section("IOTA References") {
                    ForEach(iotaRefs.sorted(), id: \.self) { ref in
                        Text(ref)
                    }
                }
            }
            .navigationTitle("Awards")
        }
    }
}

struct AwardRow: View {
    let title: String
    let count: Int
    let target: Int?

    var progress: Double {
        guard let target = target, target > 0 else { return 0 }
        return min(Double(count) / Double(target), 1.0)
    }

    var body: some View {
        Section(title) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(count)")
                        .font(.title2.bold())
                    if let target = target {
                        Text("/ \(target)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let target = target {
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let target = target {
                    ProgressView(value: progress)
                        .tint(.green)
                }
            }
        }
    }
}

#Preview {
    AwardsView()
        .modelContainer(for: [QSO.self], inMemory: true)
}
