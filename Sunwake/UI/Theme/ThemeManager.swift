import SwiftUI
import UIKit
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

// MARK: — Briefing banner style (4c — a design feature, stored per user)

/// Surface style of the briefing hero banner. Layout, behavior and animation
/// are identical for both — only the card surface swaps (see spec section 5).
/// Storage key deliberately NOT "briefingStyle" — that key already holds the
/// AI prompt style (friendly/formal/concise).
enum BriefingBannerStyle: String, CaseIterable {
    case horizont = "horizont"
    case daemmerung = "daemmerung"

    func displayName(language: String) -> String {
        switch self {
        case .horizont: return "Horizont"
        case .daemmerung: return language == "de" ? "Dämmerung" : "Twilight"
        }
    }
}

// MARK: — Design tokens „Goldene Stunde" (verbindlich: Sunwake-App-Spezifikation)

private extension UIColor {
    convenience init(hexValue: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hexValue >> 16) & 0xFF) / 255,
            green: CGFloat((hexValue >> 8) & 0xFF) / 255,
            blue: CGFloat(hexValue & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    /// Dynamic token color that follows the effective color scheme
    /// (including the in-app Hell/Dunkel/Auto override via preferredColorScheme).
    static func sunwakeDynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hexValue: dark, alpha: darkAlpha)
                : UIColor(hexValue: light, alpha: lightAlpha)
        })
    }

    // Grundflächen
    static let sunwakePaper        = sunwakeDynamic(light: 0xF8F3EA, dark: 0x100D08)
    static let sunwakeCardTop      = sunwakeDynamic(light: 0xFFFFFF, dark: 0x221B10)
    static let sunwakeCardBottom   = sunwakeDynamic(light: 0xFBF5EA, dark: 0x181209)
    static let sunwakeEdgeLight    = sunwakeDynamic(light: 0xFFFFFF, dark: 0xF5A93B, lightAlpha: 0.9, darkAlpha: 0.26)
    static let sunwakeHairline     = sunwakeDynamic(light: 0xA0875A, dark: 0xF5A93B, lightAlpha: 0.16, darkAlpha: 0.10)
    static let sunwakeWell         = sunwakeDynamic(light: 0xF0E9DA, dark: 0x0C0A05)
    static let sunwakePressShadow  = sunwakeDynamic(light: 0x5A461E, dark: 0x000000, lightAlpha: 0.25, darkAlpha: 0.6)
    static let sunwakeFloatShadow  = sunwakeDynamic(light: 0x82550F, dark: 0x000000, lightAlpha: 0.30, darkAlpha: 0.55)

    // Text
    static let sunwakeInk          = sunwakeDynamic(light: 0x2A2214, dark: 0xF2E9D6)
    static let sunwakeInkSecondary = sunwakeDynamic(light: 0x7A6E58, dark: 0xA2967E)
    static let sunwakeInkTertiary  = sunwakeDynamic(light: 0xA18960, dark: 0x8A7346)

    // Akzent (der eine Akzent — keine wählbaren Systemfarben mehr)
    static let sunwakeAccent       = sunwakeDynamic(light: 0xC0760D, dark: 0xF5A93B)
    static let sunwakeAccentDeep   = sunwakeDynamic(light: 0x9A5B08, dark: 0xE0921F)
    static let sunwakeAccentBright = sunwakeDynamic(light: 0xE89B2E, dark: 0xFFC46B)
    static let sunwakeAccentShadow = sunwakeDynamic(light: 0xA0640F, dark: 0x000000, lightAlpha: 0.5, darkAlpha: 0.5)
    static let sunwakeTint         = sunwakeDynamic(light: 0xF6E3BE, dark: 0xF5A93B, darkAlpha: 0.15)
    static let sunwakeOnAccent     = sunwakeDynamic(light: 0xFFF6E0, dark: 0x2A1A05)

    // Tab-Bar (einzige Blur-Fläche der App)
    static let sunwakeTabBar       = sunwakeDynamic(light: 0xFFFCF4, dark: 0x161109, lightAlpha: 0.88, darkAlpha: 0.88)

    // Scrim hinter dem aufgeklappten Briefing-Banner
    static let sunwakeScrim        = sunwakeDynamic(light: 0x140C02, dark: 0x140C02, lightAlpha: 0.38, darkAlpha: 0.55)

    // Legacy-Aliasse (bestehende Call-Sites erben automatisch die neuen Tokens)
    static let sunwakeBackground = sunwakePaper
    static let sunwakeSurface = sunwakeCardTop
    static let sunwakeSurfaceElevated = sunwakeCardTop
    static let sunwakeSeparator = sunwakeHairline
    static let sunwakePrimary = sunwakeInk
    static let sunwakeSecondary = sunwakeInkSecondary
    static let sunwakeTertiary = sunwakeInkTertiary
}

/// Konstanten, die in beiden Modi identisch sind.
enum SunwakeConstants {
    // Horizont-Banner (4a) — das einzige Gradient des Systems neben dem Himmel-Wash
    static let bannerGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: "2A2013"), location: 0.0),
            .init(color: Color(hex: "3A2A14"), location: 0.72),
            .init(color: Color(hex: "8F5606"), location: 0.96),
            .init(color: Color(hex: "C0760D"), location: 1.0),
        ],
        startPoint: .top, endPoint: .bottom
    )
    static let bannerText = Color(hex: "EBDDBE")
    static let bannerLabel = Color(hex: "C9A15C")
    static let bannerChipBackground = Color(hex: "F0A93B").opacity(0.16)
    static let bannerChipText = Color(hex: "F2C173")
    static let bannerDivider = Color(hex: "C9A15C").opacity(0.25)
    static let bannerShadow = Color(red: 90/255, green: 60/255, blue: 8/255).opacity(0.45)

    // Dämmerung (4c): invertierte Fläche
    static let duskSurface = Color.sunwakeDynamic(light: 0x221A0E, dark: 0xF6EFDF)
    static let duskText = Color.sunwakeDynamic(light: 0xD9CCAF, dark: 0x5C5240)
    static let duskLabel = Color.sunwakeDynamic(light: 0xF2A93B, dark: 0x8F5606)

    // Emmrich-Banner: Familien-Konstante — nie an die App-Farbwelt anpassen
    static let emmrichGradient = LinearGradient(
        colors: [Color(hex: "2A2118"), Color(hex: "3A2E1E")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let emmrichBorder = Color(hex: "A98E5B").opacity(0.45)
    static let emmrichBrass = Color(hex: "A98E5B")
    static let emmrichText = Color(hex: "EDE2CC")

    /// Akzent-Hex für Live Activity / Dynamic Island (dunkle Fläche → Dark-Akzent).
    static let liveActivityAccentHex = "F5A93B"

    /// Website der App-Familie (Emmrich-Banner-Ziel). Vor Release verifizieren.
    static let emmrichWebsite = URL(string: "https://emmrich-apps.de")!
}

// MARK: — Radius-Skala (5a) — alle continuous

enum SunwakeRadius {
    static let chip: CGFloat = 10
    static let control: CGFloat = 12
    static let iconTile: CGFloat = 7
    static let card: CGFloat = 16
    static let bannerExpanded: CGFloat = 24
    static let sheet: CGFloat = 28
}

// MARK: — Typografie (2c): Clash Display für Display-Rollen, sonst SF Pro

enum SunwakeFont {
    /// false → SF Pro Heavy übernimmt die Display-Rollen 1:1 (gleiche Skala).
    static let useDisplayFont = true

    enum DisplayWeight {
        case medium, semibold, bold

        var postScriptName: String {
            switch self {
            case .medium: return "ClashDisplay-Medium"
            case .semibold: return "ClashDisplay-Semibold"
            case .bold: return "ClashDisplay-Bold"
            }
        }
    }

    static func display(_ size: CGFloat, _ weight: DisplayWeight, relativeTo style: Font.TextStyle) -> Font {
        guard useDisplayFont else {
            return .system(size: size, weight: .heavy)
        }
        return .custom(weight.postScriptName, size: size, relativeTo: style)
    }
}

struct SunwakeTypography {
    // Display-Ebene (Clash Display)
    static let hero = SunwakeFont.display(32, .bold, relativeTo: .largeTitle)      // Large Title (Datum)
    static let title = SunwakeFont.display(26, .bold, relativeTo: .title)          // Screen-Titel
    static let title2 = SunwakeFont.display(22, .semibold, relativeTo: .title2)
    static let title3 = SunwakeFont.display(17, .semibold, relativeTo: .title3)
    static let headline = SunwakeFont.display(17, .semibold, relativeTo: .headline) // Karten-Titel / Leerzustand
    static let bigNumber = SunwakeFont.display(28, .medium, relativeTo: .title)     // Großzahlen (Temperatur)

    // Text-Ebene (SF Pro)
    static let body = Font.system(size: 17, weight: .regular)          // Briefing-Text
    static let listTitle = Font.system(size: 15, weight: .semibold)    // Listentitel
    static let callout = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 13, weight: .regular)       // Sekundär/Meta
    static let caption2 = Font.system(size: 11, weight: .regular)
    static let eyebrow = Font.system(size: 12, weight: .semibold)      // Versalien, Tracking +0.12em
    static let tabLabel = Font.system(size: 10, weight: .semibold)
}

// MARK: — Hex helpers (Dynamic Island liest accentColorHex weiterhin als Hex)

extension Color {
    init(hex hexString: String) {
        let hex = UInt32(hexString.trimmingCharacters(in: .init(charactersIn: "#")), radix: 16) ?? 0xC0760D
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
}
