import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    /// Segment title following the app language (not the system language).
    func displayName(language: String) -> String {
        let isDE = language == "de"
        switch self {
        case .light: return isDE ? "Hell" : "Light"
        case .dark: return isDE ? "Dunkel" : "Dark"
        case .system: return isDE ? "Auto" : "System"
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: UserDefaultsKey.selectedTheme)
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch currentTheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: UserDefaultsKey.selectedTheme) ?? AppTheme.system.rawValue
        self.currentTheme = AppTheme(rawValue: saved) ?? .system
    }
}

// MARK: — Design tokens

// Preset accent colors for the App Layout configurator
struct SunwakeAccentColor {
    let labelDE: String
    let labelEN: String
    let hex: String

    func label(language: String) -> String { language == "de" ? labelDE : labelEN }
}

let sunwakeAccentPalette: [SunwakeAccentColor] = [
    .init(labelDE: "Orange", labelEN: "Orange",  hex: "FF9500"),
    .init(labelDE: "Blau",   labelEN: "Blue",    hex: "007AFF"),
    .init(labelDE: "Indigo", labelEN: "Indigo",  hex: "5856D6"),
    .init(labelDE: "Pink",   labelEN: "Pink",    hex: "FF2D55"),
    .init(labelDE: "Grün",   labelEN: "Green",   hex: "34C759"),
    .init(labelDE: "Teal",   labelEN: "Teal",    hex: "5AC8FA"),
    .init(labelDE: "Rot",    labelEN: "Red",     hex: "FF3B30"),
    .init(labelDE: "Gelb",   labelEN: "Yellow",  hex: "FFCC00"),
    .init(labelDE: "Braun",  labelEN: "Brown",   hex: "A2845E"),
    .init(labelDE: "Grau",   labelEN: "Gray",    hex: "636366"),
]

extension Color {
    // Dynamic: reads SwiftUI's tint color, which is set per-app via .tint(appState.accentColor)
    static var sunwakeAccent: Color { .accentColor }

    init(hex hexString: String) {
        let hex = UInt32(hexString.trimmingCharacters(in: .init(charactersIn: "#")), radix: 16) ?? 0xFF9500
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255
        )
    }

    var hexString: String {
        let resolved = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }

    // Semantic surface colors that adapt to theme
    static let sunwakeBackground = Color("Background")
    static let sunwakeSurface = Color("Surface")
    static let sunwakeSurfaceElevated = Color("SurfaceElevated")
    static let sunwakeSeparator = Color("Separator")

    // Text hierarchy
    static let sunwakePrimary = Color("TextPrimary")
    static let sunwakeSecondary = Color("TextSecondary")
    static let sunwakeTertiary = Color("TextTertiary")
}

struct SunwakeTypography {
    static let hero = Font.system(.largeTitle, design: .default, weight: .bold)
    static let title = Font.system(.title, design: .default, weight: .semibold)
    static let title2 = Font.system(.title2, design: .default, weight: .semibold)
    static let title3 = Font.system(.title3, design: .default, weight: .medium)
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.system(.body, design: .default, weight: .regular)
    static let callout = Font.system(.callout, design: .default, weight: .regular)
    static let caption = Font.system(.caption, design: .default, weight: .regular)
    static let caption2 = Font.system(.caption2, design: .default, weight: .regular)
}
