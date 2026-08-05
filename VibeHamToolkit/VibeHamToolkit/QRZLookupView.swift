import SwiftUI
import SwiftData

struct QRZLookupView: View {
    @Environment(\.modelContext) private var context
    @State private var call = ""
    @State private var info: QRZInfo?
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Callsign", text: $call)
                        .autocapitalization(.allCharacters)
                    Button("Look Up") {
                        Task { await lookup() }
                    }
                    .disabled(call.isEmpty || isLoading)
                }

                if let error = errorText {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }

                if let info = info {
                    Section("Identity") {
                        LabeledContent("Call", value: info.call)
                        LabeledContent("Name", value: "\(info.fname) \(info.name)")
                        if !info.aliases.isEmpty { LabeledContent("Aliases", value: info.aliases) }
                        if !info.classCode.isEmpty { LabeledContent("Class", value: info.classCode) }
                        if !info.codes.isEmpty { LabeledContent("Codes", value: info.codes) }
                    }
                    Section("QTH") {
                        if !info.grid.isEmpty { LabeledContent("Grid", value: info.grid) }
                        if !info.addr1.isEmpty { LabeledContent("Address", value: info.addr1) }
                        if !info.addr2.isEmpty { LabeledContent("City", value: info.addr2) }
                        if !info.state.isEmpty { LabeledContent("State", value: info.state) }
                        if !info.zip.isEmpty { LabeledContent("ZIP", value: info.zip) }
                        if !info.country.isEmpty { LabeledContent("Country", value: info.country) }
                    }
                    Section("Data") {
                        if !info.dxcc.isEmpty { LabeledContent("DXCC", value: info.dxcc) }
                        if !info.cqzone.isEmpty { LabeledContent("CQ Zone", value: info.cqzone) }
                        if !info.ituzone.isEmpty { LabeledContent("ITU Zone", value: info.ituzone) }
                        if !info.lotw.isEmpty { LabeledContent("LoTW", value: info.lotw) }
                    }
                }
            }
            .navigationTitle("QRZ Lookup")
            .overlay {
                if isLoading { ProgressView() }
            }
        }
    }

    private func lookup() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        let profile = UserProfile.fetchOrCreate(in: context)
        guard !profile.qrzApiKey.isEmpty else {
            errorText = "Add your QRZ.com API key in Settings."
            return
        }
        do {
            info = try await QRZService.shared.lookup(callsign: call, apiKey: profile.qrzApiKey)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

#Preview {
    QRZLookupView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
