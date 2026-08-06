import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var profile: UserProfile?
    @State private var callsign = ""
    @State private var operatorName = ""
    @State private var gridSquare = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var qrzApiKey = ""
    @State private var qrzUsername = ""
    @State private var qrzPassword = ""
    @State private var accentColor = "blue"
    @State private var colorSchemeName = "system"
    @State private var saveMessage: String?
    @State private var testingQRZ = false
    @State private var qrzTestResult: String?
    @State private var showQRZKey = false
    @State private var showQRZPassword = false

    private let colors = ["red", "orange", "yellow", "green", "mint", "teal", "cyan", "blue", "indigo", "purple", "pink"]
    private let schemes = ["system", "light", "dark"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Station") {
                    TextField("Callsign", text: $callsign)
                        .autocapitalization(.allCharacters)
                    TextField("Operator Name", text: $operatorName)
                    TextField("Grid Square", text: $gridSquare)
                        .autocapitalization(.allCharacters)
                    TextField("Latitude", text: $latitude).keyboardType(.decimalPad)
                    TextField("Longitude", text: $longitude).keyboardType(.decimalPad)
                }

                Section("Integrations") {
                    HStack {
                        Group {
                            if showQRZKey {
                                TextField("QRZ Logbook API Key", text: $qrzApiKey, prompt: Text("XXXX-XXXX-XXXX-XXXX"))
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .onChange(of: qrzApiKey) { _, newValue in
                                        qrzApiKey = formatQRZKey(newValue)
                                    }
                            } else {
                                SecureField("QRZ Logbook API Key", text: $qrzApiKey, prompt: Text("XXXX-XXXX-XXXX-XXXX"))
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .onChange(of: qrzApiKey) { _, newValue in
                                        qrzApiKey = formatQRZKey(newValue)
                                    }
                            }
                        }
                        Button {
                            showQRZKey.toggle()
                        } label: {
                            Image(systemName: showQRZKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }

                    Text("Used to sync your QRZ Logbook ADIF. Get it from QRZ.com -> Logbook -> Settings.")
                        .font(.caption).foregroundStyle(.secondary)

                    Button {
                        Task { await testQRZKey() }
                    } label: {
                        HStack {
                            Text("Test QRZ Key")
                            Spacer()
                            if testingQRZ {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(qrzApiKey.isEmpty || testingQRZ)

                    if let result = qrzTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.hasPrefix("OK") ? .green : .red)
                    }

                    TextField("QRZ Username (callsign lookup)", text: $qrzUsername)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    HStack {
                        Group {
                            if showQRZPassword {
                                TextField("QRZ Password (callsign lookup)", text: $qrzPassword)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("QRZ Password (callsign lookup)", text: $qrzPassword)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            }
                        }
                        Button {
                            showQRZPassword.toggle()
                        } label: {
                            Image(systemName: showQRZPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }

                    Text("QRZ callsign lookup requires an active QRZ XML Data subscription.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Appearance") {
                    Picker("Accent", selection: $accentColor) {
                        ForEach(colors, id: \.self) { color in
                            Text(color.capitalized).tag(color)
                        }
                    }
                    Picker("Theme", selection: $colorSchemeName) {
                        ForEach(schemes, id: \.self) { scheme in
                            Text(scheme.capitalized).tag(scheme)
                        }
                    }
                }

                Section {
                    Button("Save") {
                        save()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
            .onAppear { load() }
            .overlay {
                if let message = saveMessage {
                    VStack {
                        Spacer()
                        Text(message)
                            .font(.subheadline)
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                            .padding(.bottom, 32)
                    }
                }
            }
        }
    }

    private func formatQRZKey(_ input: String) -> String {
        let cleaned = input.uppercased().filter { $0.isLetter || $0.isNumber }
        var chunks: [String] = []
        for i in stride(from: 0, to: cleaned.count, by: 4) {
            let start = cleaned.index(cleaned.startIndex, offsetBy: i)
            let end = cleaned.index(start, offsetBy: min(4, cleaned.count - i))
            chunks.append(String(cleaned[start..<end]))
        }
        return chunks.joined(separator: "-")
    }

    private func load() {
        let p = UserProfile.fetchOrCreate(in: context)
        profile = p
        callsign = p.callsign
        operatorName = p.operatorName
        gridSquare = p.gridSquare
        latitude = p.latitude == 0 ? "" : String(p.latitude)
        longitude = p.longitude == 0 ? "" : String(p.longitude)
        qrzApiKey = formatQRZKey(p.qrzApiKey)
        qrzUsername = p.qrzUsername ?? ""
        qrzPassword = p.qrzPassword ?? ""
        accentColor = themeManager.accentColorName
        colorSchemeName = themeManager.colorSchemeName
    }

    private func save() {
        guard let p = profile else {
            saveMessage = "Error: profile not loaded"
            clearMessageAfterDelay()
            return
        }
        p.callsign = callsign.uppercased()
        p.operatorName = operatorName
        p.gridSquare = gridSquare.uppercased()
        p.latitude = Double(latitude) ?? 0
        p.longitude = Double(longitude) ?? 0
        p.qrzApiKey = qrzApiKey
        p.qrzUsername = qrzUsername.isEmpty ? nil : qrzUsername
        p.qrzPassword = qrzPassword.isEmpty ? nil : qrzPassword
        p.accentColorName = accentColor

        do {
            try context.save()
            themeManager.setAccent(accentColor)
            themeManager.setScheme(colorSchemeName)

            // Verify persistence by re-fetching from a fresh context read
            let verify = UserProfile.fetchOrCreate(in: context)
            let keySet = !verify.qrzApiKey.isEmpty
            let userSet = !(verify.qrzUsername ?? "").isEmpty
            saveMessage = "Saved (key \(keySet ? "set" : "empty"), user \(userSet ? "set" : "empty"))"
        } catch {
            saveMessage = "Save failed: \(error.localizedDescription)"
        }
        clearMessageAfterDelay()
    }

    private func clearMessageAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            saveMessage = nil
        }
    }

    private func testQRZKey() async {
        testingQRZ = true
        qrzTestResult = nil
        defer { testingQRZ = false }
        do {
            let adif = try await QRZLogbookService.fetchADIF(apiKey: qrzApiKey)
            let count = ADIFParser.parse(content: adif).count
            qrzTestResult = "OK: key valid, \(count) QSOs available"
        } catch {
            qrzTestResult = "Failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    SettingsView()
        .environment(ThemeManager())
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
