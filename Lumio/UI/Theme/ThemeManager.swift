import SwiftUI
import Combine

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: LocalizedStringKey {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
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

extension Color {
    static let lumioAccent = Color("AccentColor")

    // Semantic surface colors that adapt to theme
    static let lumioBackground = Color("Background")
    static let lumioSurface = Color("Surface")
    static let lumioSurfaceElevated = Color("SurfaceElevated")
    static let lumioSeparator = Color("Separator")

    // Text hierarchy
    static let lumioPrimary = Color("TextPrimary")
    static let lumioSecondary = Color("TextSecondary")
    static let lumioTertiary = Color("TextTertiary")
}

struct LumioTypography {
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
