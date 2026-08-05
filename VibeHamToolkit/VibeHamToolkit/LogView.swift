import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<QSO>(\.qsoDate, order: .reverse)]) private var qsos: [QSO]
    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var importResult: String?
    @State private var selectedQSO: QSO?

    private var filtered: [QSO] {
        guard !searchText.isEmpty else { return qsos }
        let lower = searchText.lowercased()
        return qsos.filter {
            $0.call.lowercased().contains(lower) ||
            ($0.country?.lowercased().contains(lower) ?? false) ||
            ($0.band?.lowercased().contains(lower) ?? false) ||
            ($0.mode?.lowercased().contains(lower) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List(selection: $selectedQSO) {
                ForEach(filtered) { qso in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(qso.call).font(.headline)
                            Spacer()
                            Text(qso.qsoDate).font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text([qso.band, qso.mode].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline)
                            Spacer()
                            Text(qso.country ?? "").font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .tag(qso)
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .navigationTitle("QSO Log")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingImporter = true } label: {
                        Label("Import ADIF", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [UTType.plainText], allowsMultipleSelection: false) { result in
                handleImport(result)
            }
            .alert("Import Result", isPresented: .constant(importResult != nil)) {
                Button("OK") { importResult = nil }
            } message: {
                Text(importResult ?? "")
            }
        }
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        switch result {
        case .failure(let error):
            importResult = "Import failed: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
                let content = try String(contentsOf: url, encoding: .utf8)
                let parsed = ADIFParser.parse(content: content)
                var inserted = 0
                var skipped = 0
                let existing = (try? context.fetch(FetchDescriptor<QSO>())) ?? []
                for qso in parsed {
                    let isDuplicate = existing.contains { $0.call == qso.call && $0.qsoDate == qso.qsoDate }
                    if !isDuplicate {
                        context.insert(qso)
                        inserted += 1
                    } else {
                        skipped += 1
                    }
                }
                try context.save()
                importResult = "Imported \(inserted) QSOs, skipped \(skipped) duplicates."
            } catch {
                importResult = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            context.delete(filtered[index])
        }
        try? context.save()
    }
}

#Preview {
    LogView()
        .modelContainer(for: [UserProfile.self, QSO.self], inMemory: true)
}
