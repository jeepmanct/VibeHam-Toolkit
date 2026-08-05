import SwiftUI
import SwiftData

@main
struct VibeHamToolkitApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .tint(themeManager.accentColor)
                .preferredColorScheme(themeManager.colorScheme)
        }
        .modelContainer(for: [UserProfile.self, QSO.self, PhotoEntry.self, Satellite.self, SolarDataPoint.self])
    }
}
