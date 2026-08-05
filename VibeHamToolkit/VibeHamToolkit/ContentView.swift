import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        TabView {
            LogView()
                .tabItem { Label("Log", systemImage: "book.pages") }
            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }
            AwardsView()
                .tabItem { Label("Awards", systemImage: "trophy") }
            MapView()
                .tabItem { Label("Map", systemImage: "map") }
            ToolsView()
                .tabItem { Label("Tools", systemImage: "wrench.adjustable") }
            ConditionsView()
                .tabItem { Label("Space", systemImage: "sun.max") }
            SatelliteView()
                .tabItem { Label("Sats", systemImage: "satellite") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .environment(ThemeManager())
        .modelContainer(for: [UserProfile.self, QSO.self, PhotoEntry.self, Satellite.self, SolarDataPoint.self], inMemory: true)
}
