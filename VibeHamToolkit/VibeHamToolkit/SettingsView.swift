import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
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
                    SecureField("QRZ Logbook API Key", text: $qrzApiKey)
                    Text("Used to sync your QRZ Logbook ADIF. Get it from QRZ.com → Logbook → Settings.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("QRZ Username (callsign lookup)", text: $qrzUsername)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    SecureField("QRZ Password (callsign lookup)", text: $qrzPassword)
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
                    Button("Save") { save() }
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Settings")
            .onAppear { load() }
        }
    }

    private func load() {
        let p = UserProfile.fetchOrCreate(in: context)
        profile = p
        callsign = p.callsign
        operatorName = p.operatorName
        gridSquare = p.gridSquare
        latitude = p.latitude == 0 ? "" : String(p.latitude)
        longitude = p.longitude == 0 ? "" : String(p.longitude)
        qrzApiKey = p.qrzApiKey
        qrzUsername = p.qrzUsername
        qrzPassword = p.qrzPassword
        accentColor = themeManager.accentColorName
        colorSchemeName = themeManager.colorSchemeName
    }

    private func save() {
        guard let p = profile else { return }
        p.callsign = callsign.uppercased()
        p.operatorName = operatorName
        p.gridSquare = gridSquare.uppercased()
        p.latitude = Double(latitude) ?? 0
        p.longitude = Double(longitude) ?? 0
        p.qrzApiKey = qrzApiKey
        p.qrzUsername = qrzUsername
        p.qrzPassword = qrzPassword
        p.accentColorName = accentColor
        try? context.save()

        themeManager.setAccent(accentColor)
        themeManager.setScheme(colorSchemeName)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
