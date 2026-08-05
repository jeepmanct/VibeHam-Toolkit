import SwiftUI

@Observable
final class ThemeManager {
    var accentColorName: String = UserDefaults.standard.string(forKey: "accentColorName") ?? "blue"
    var colorSchemeName: String = UserDefaults.standard.string(forKey: "colorSchemeName") ?? "system"

    var accentColor: Color {
        switch accentColorName {
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        default: .blue
        }
    }

    var colorScheme: ColorScheme? {
        switch colorSchemeName {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    func setAccent(_ name: String) {
        accentColorName = name
        UserDefaults.standard.set(name, forKey: "accentColorName")
    }

    func setScheme(_ name: String) {
        colorSchemeName = name
        UserDefaults.standard.set(name, forKey: "colorSchemeName")
    }
}
