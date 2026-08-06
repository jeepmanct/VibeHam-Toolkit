import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor<QSO>(\.qsoDate, order: .reverse)]) private var qsos: [QSO]
    @State private var searchText = ""
    @State private var filter: FilterMode = .all
    @State private var showingImporter = false
    @State private var importResult: String?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var qrzSyncInProgress = false
    @State private var potaSyncInProgress = false

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case pota = "POTA"
        case sota = "SOTA"
    }

    private var filtered: [QSO] {
        var result = qsos
        switch filter {
        case .pota:
            result = result.filter { ($0.potaRef ?? "").isEmpty == false }
        case .sota:
            result = result.filter { ($0.sotaRef ?? "").isEmpty == false }
        case .all:
            break
        }
        guard !searchText.isEmpty else { return result }
        let lower = searchText.lowercased()
        return result.filter {
            $0.call.lowercased().contains(lower) ||
            ($0.country?.lowercased().contains(lower) ?? false) ||
            ($0.band?.lowercased().contains(lower) ?? false) ||
            ($0.mode?.lowercased().contains(lower) ?? false) ||
            ($0.potaRef?.lowercased().contains(lower) ?? false) ||
            ($0.sotaRef?.lowercased().contains(lower) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(FilterMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)

                ForEach(filtered) { qso in
                    NavigationLink(value: qso) {
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
                                if let pota = qso.potaRef, !pota.isEmpty {
                                    Text(pota).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.green.opacity(0.2)).cornerRadius(4)
                                }
                                if let sota = qso.sotaRef, !sota.isEmpty {
                                    Text(sota).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2)).cornerRadius(4)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .navigationTitle("QSO Log")
            .navigationDestination(for: QSO.self) { qso in
                QSOEditorView(qso: qso)
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { syncQRZ(full: false) } label: {
                            Label("Sync New Since Last", systemImage: "arrow.down.circle")
                        }
                        .disabled(qrzSyncInProgress)
                        Button { syncQRZ(full: true) } label: {
                            Label("Sync All Records", systemImage: "arrow.down.circle.fill")
                        }
                        .disabled(qrzSyncInProgress)
                    } label: {
                        if qrzSyncInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                .frame(width: 22, height: 22)
                        } else {
                            Label("QRZ", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    .disabled(qrzSyncInProgress)

                    Button { syncPOTA() } label: {
                        if potaSyncInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                .frame(width: 22, height: 22)
                        } else {
                            Label("POTA", systemImage: "tree")
                        }
                    }
                    .disabled(potaSyncInProgress)

                    Button { exportLog() } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(qsos.isEmpty)
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
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    private func exportLog() {
        let profile = UserProfile.fetchOrCreate(in: context)
        let adif = ADIFExporter.export(qsos: qsos, myGrid: profile.gridSquare)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("VibeHam-Export.adi")
        try? adif.write(to: url, atomically: true, encoding: .utf8)
        shareItems = [url]
        showingShareSheet = true
    }

    private func syncQRZ(full: Bool) {
        let profile = UserProfile.fetchOrCreate(in: context)
        guard !profile.qrzApiKey.isEmpty else {
            importResult = "Add your QRZ Logbook API key in Settings first."
            return
        }
        qrzSyncInProgress = true
        Task {
            do {
                let option: QRZLogbookService.FetchOption = full ? .all : .last
                let adif = try await QRZLogbookService.fetchADIF(apiKey: profile.qrzApiKey, option: option)
                let parsed = ADIFParser.parse(content: adif)
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
                profile.lastQRZSync = Date()
                try context.save()
                let label = full ? "all" : "new"
                importResult = "QRZ sync (\(label)): imported \(inserted) QSOs, skipped \(skipped) duplicates."
            } catch {
                importResult = "QRZ sync failed: \(error.localizedDescription)"
            }
            qrzSyncInProgress = false
        }
    }

    private func syncPOTA() {
        let profile = UserProfile.fetchOrCreate(in: context)
        guard !profile.callsign.isEmpty else {
            importResult = "Set your callsign in Settings first so POTA knows whose log to fetch."
            return
        }
        potaSyncInProgress = true
        Task {
            do {
                let potaQSOs = try await POTAService.fetchRecentHunterQSOs(callsign: profile.callsign)
                let existing = (try? context.fetch(FetchDescriptor<QSO>())) ?? []
                var inserted = 0
                var skipped = 0
                for pota in potaQSOs {
                    guard let qso = POTAService.parsePOTAQSO(pota, myCallsign: profile.callsign) else { continue }
                    let isDuplicate = existing.contains { $0.call == qso.call && $0.qsoDate == qso.qsoDate && $0.potaRef == qso.potaRef }
                    if !isDuplicate {
                        context.insert(qso)
                        inserted += 1
                    } else {
                        skipped += 1
                    }
                }
                try context.save()
                profile.lastPOTASync = Date()
                try context.save()
                importResult = "POTA sync: imported \(inserted) QSOs, skipped \(skipped) duplicates."
            } catch {
                importResult = "POTA sync failed: \(error.localizedDescription)"
            }
            potaSyncInProgress = false
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
