import SwiftUI

// ============================================================
// Sunwake-Designsystem „Goldene Stunde" — Komponenten
// Verbindliche Quelle: Sunwake-App-Spezifikation.html (19.07.2026)
// ============================================================

// MARK: — Himmel-Wash (1d) — nur auf Tab-Root-Screens

/// Light: Morgenhimmel oben (→ 46 % Höhe, danach flach paper).
/// Dark: Nacht mit Horizont-Glut am unteren Rand.
struct SunwakeSkyBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if scheme == .dark {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "100D08"), location: 0.0),
                        .init(color: Color(hex: "100D08"), location: 0.42),
                        .init(color: Color(hex: "241503"), location: 0.86),
                        .init(color: Color(hex: "3E2402"), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "FBE2B4"), location: 0.0),
                        .init(color: Color(hex: "F8F3EA"), location: 0.46),
                        .init(color: Color(hex: "F8F3EA"), location: 1.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Tab-Root-Screens: Himmel-Wash hinter dem Inhalt.
    func sunwakeSkyScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { SunwakeSkyBackground() }
    }

    /// Gepushte Detail-Views: flaches paper, nie der Wash.
    func sunwakePaperScreen() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background { Color.sunwakePaper.ignoresSafeArea() }
    }
}

// MARK: — Tiefe (3d Lichtkante · 3f Prägung · Schwebend)

/// Ebene 1 „Liegend": Karten-Verlauf + 1-pt-Lichtkante oben. Kein Schatten.
struct SunwakeCardModifier: ViewModifier {
    var radius: CGFloat = SunwakeRadius.card

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(
                        colors: [.sunwakeCardTop, .sunwakeCardBottom],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: .sunwakeEdgeLight, location: 0),
                                        .init(color: .clear, location: 0.35),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

/// Ebene 2 „Eingeprägt" (3f): Mulde mit Innenschatten oben + Lichtkante unten.
/// Nur für Suchfelder, Segmented-Hintergründe, erledigte/inaktive Zeilen.
struct SunwakeWellModifier: ViewModifier {
    var radius: CGFloat = SunwakeRadius.control

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color.sunwakeWell)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(
                                stops: [
                                    .init(color: .sunwakePressShadow, location: 0),
                                    .init(color: .clear, location: 0.22),
                                ],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .blur(radius: 1.5)
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.65),
                                        .init(color: .sunwakeEdgeLight, location: 1),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

/// Ebene 3 „Schwebend": Lichtkante + EIN warmer Schatten.
/// Nur: Play-Leiste, Briefing-Banner, Chat-Button, Tab-Bar.
struct SunwakeFloatingModifier: ViewModifier {
    var radius: CGFloat = SunwakeRadius.card

    func body(content: Content) -> some View {
        content
            .modifier(SunwakeCardModifier(radius: radius))
            .shadow(color: .sunwakeFloatShadow, radius: 12, y: 10)
    }
}

extension View {
    func sunwakeCard(radius: CGFloat = SunwakeRadius.card) -> some View {
        modifier(SunwakeCardModifier(radius: radius))
    }

    func sunwakeWell(radius: CGFloat = SunwakeRadius.control) -> some View {
        modifier(SunwakeWellModifier(radius: radius))
    }

    func sunwakeFloating(radius: CGFloat = SunwakeRadius.card) -> some View {
        modifier(SunwakeFloatingModifier(radius: radius))
    }
}

// MARK: — Eyebrow (Versalien-Label)

struct SunwakeEyebrow: View {
    let text: String
    var color: Color = .sunwakeInkTertiary

    var body: some View {
        Text(text.uppercased())
            .font(SunwakeTypography.eyebrow)
            .kerning(1.4)
            .foregroundStyle(color)
    }
}

/// Sektionstitel mit Zähler („Heute · 2 Termine").
struct SunwakeSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Font.system(size: 12, weight: .semibold))
            .kerning(1.3)
            .foregroundStyle(Color.sunwakeInkTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: — Sonnenbogen-Form (5d) — genau 4 Orte

/// Ort ① Play-Button (52×33) und Ort ④ Chat-Senden (34×22).
struct SunArcButtonLabel: View {
    var width: CGFloat = 52
    var height: CGFloat = 33
    var bottomRadius: CGFloat = 11
    let systemImage: String
    var iconSize: CGFloat = 15

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 999, bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius, topTrailingRadius: 999,
            style: .continuous
        )
    }

    var body: some View {
        shape
            .fill(LinearGradient(
                colors: [.sunwakeAccentBright, .sunwakeAccent],
                startPoint: .top, endPoint: .bottom
            ))
            .frame(width: width, height: height)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: iconSize, weight: .bold))
                    .foregroundStyle(Color(hex: "FFF6E0"))
            }
            .shadow(color: .sunwakeAccentShadow, radius: 9, y: 8)
    }
}

/// Oberer Halbbogen (links → über den Scheitel → rechts) als Kreis-Trim:
/// Circle-Pfade starten bei 3 Uhr und laufen im Uhrzeigersinn, 0.5…1.0 ist
/// exakt der obere Halbkreis von links nach rechts.
private struct SunArcStroke: View {
    var progress: Double
    let color: Color
    var lineWidth: CGFloat = 3.5

    var body: some View {
        GeometryReader { geo in
            let diameter = geo.size.width - lineWidth
            Circle()
                .trim(from: 0.5, to: 0.5 + 0.5 * min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: diameter, height: diameter)
                .offset(x: lineWidth / 2, y: lineWidth / 2)
        }
    }
}

/// Ort ② Briefing-Bogen im Header (A1): 44×24, ersetzt den Fortschrittsring.
/// Bahn tint, Füllung accent links→rechts, Sonnenpunkt mittig.
struct BriefingArcGauge: View {
    /// nil = unbestimmt (Erzeugen läuft) → Bogen pulst durch.
    let progress: Double?

    @State private var sweep: Double = 0.15

    var body: some View {
        ZStack(alignment: .top) {
            SunArcStroke(progress: 1, color: .sunwakeTint)
            SunArcStroke(progress: progress ?? sweep, color: .sunwakeAccent)
                .animation(progress == nil ? nil : .easeInOut(duration: 0.25), value: progress)
            Circle()
                .fill(RadialGradient(
                    colors: [.sunwakeAccentBright, .sunwakeAccent],
                    center: .init(x: 0.35, y: 0.35), startRadius: 0, endRadius: 6
                ))
                .frame(width: 9, height: 9)
                .offset(y: 9)
        }
        .frame(width: 44, height: 24)
        .padding(.top, 2)
        .onAppear { animateIfIndeterminate() }
        .onChange(of: progress == nil) { animateIfIndeterminate() }
    }

    private func animateIfIndeterminate() {
        guard progress == nil else { return }
        sweep = 0.15
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            sweep = 1.0
        }
    }
}

/// Ort ③ Sonnenbogen-Motiv (V2): ersetzt das ✨-Sparkle in Leerzuständen.
struct SunArcMotif: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 7) {
                ray.rotationEffect(.degrees(-30)).padding(.bottom, 12)
                SunArcStroke(progress: 1, color: .sunwakeAccent, lineWidth: 5)
                    .frame(width: 54, height: 28)
                ray.rotationEffect(.degrees(30)).padding(.bottom, 12)
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.sunwakeInk)
                .frame(width: 84, height: 3)
                .padding(.top, 0)
        }
    }

    private var ray: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.sunwakeAccent)
            .frame(width: 4, height: 14)
    }
}

/// Kompletter Leerzustand mit tageszeitabhängiger Copy.
struct SunwakeEmptyState: View {
    let language: String
    var date: Date = Date()

    private var isEvening: Bool { Calendar.current.component(.hour, from: date) >= 17 }

    private var title: String {
        if language == "de" {
            return isEvening ? "Freier Abend" : "Entspannter Tag"
        }
        return isEvening ? "Free evening" : "Clear day ahead"
    }

    private var subtitle: String {
        if language == "de" {
            return isEvening
                ? "Keine Termine mehr heute. Lass den Tag ausklingen."
                : "Keine Termine heute. Genieß die freie Zeit."
        }
        return isEvening
            ? "Nothing left on the schedule. Enjoy your evening."
            : "No events scheduled for today. Enjoy the open time."
    }

    var body: some View {
        VStack(spacing: 12) {
            SunArcMotif()
            Text(title)
                .font(SunwakeTypography.headline)
                .foregroundStyle(Color.sunwakeInk)
                .padding(.top, 4)
            Text(subtitle)
                .font(SunwakeTypography.caption)
                .foregroundStyle(Color.sunwakeInkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: — Chips

/// Vorschlags-/Filter-Chip: tint-Fläche, Radius 10, Text accentDeep.
struct SunwakeChipLabel: View {
    let text: String
    var systemImage: String? = nil
    var isActive: Bool = true

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(isActive ? Color.sunwakeAccentDeep : Color.sunwakeInkSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: SunwakeRadius.chip, style: .continuous)
                .fill(isActive ? Color.sunwakeTint : Color.sunwakeWell)
        }
    }
}

// MARK: — Segmented Control als 3f-Mulde

struct SunwakeSegmented<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button {
                    HapticFeedback.selection()
                    withAnimation(.spring(duration: 0.22)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.system(size: 13, weight: selection == option ? .semibold : .regular))
                        .foregroundStyle(selection == option ? Color.sunwakeInk : Color.sunwakeInkSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            if selection == option {
                                RoundedRectangle(cornerRadius: SunwakeRadius.chip, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [.sunwakeCardTop, .sunwakeCardBottom],
                                        startPoint: .top, endPoint: .bottom
                                    ))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: SunwakeRadius.chip, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    stops: [
                                                        .init(color: .sunwakeEdgeLight, location: 0),
                                                        .init(color: .clear, location: 0.5),
                                                    ],
                                                    startPoint: .top, endPoint: .bottom
                                                ),
                                                lineWidth: 1
                                            )
                                    }
                                    .shadow(color: .sunwakePressShadow, radius: 2.5, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .sunwakeWell(radius: SunwakeRadius.control)
    }
}

// MARK: — Icon-Kachel (Einstellungen)

struct SunwakeIconTile: View {
    let systemImage: String

    var body: some View {
        RoundedRectangle(cornerRadius: SunwakeRadius.iconTile, style: .continuous)
            .fill(Color.sunwakeTint)
            .frame(width: 26, height: 26)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.sunwakeAccentDeep)
            }
    }
}

// MARK: — Emmrich-Banner (Familien-Konstante)

struct EmmrichBanner: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            HapticFeedback.selection()
            openURL(SunwakeConstants.emmrichWebsite)
        } label: {
            HStack(spacing: 12) {
                // Frei schwebendes E aus 3 Balken, mittlerer 68 % Breite
                VStack(alignment: .leading, spacing: 0) {
                    bar(widthFraction: 1)
                    Spacer(minLength: 0)
                    bar(widthFraction: 0.68)
                    Spacer(minLength: 0)
                    bar(widthFraction: 1)
                }
                .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Emmrich Apps")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(SunwakeConstants.emmrichText)
                    Text("Dresslyst · Restock · Sunwake")
                        .font(.system(size: 11))
                        .foregroundStyle(SunwakeConstants.emmrichBrass)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SunwakeConstants.emmrichBrass)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: SunwakeRadius.card, style: .continuous)
                    .fill(SunwakeConstants.emmrichGradient)
                    .overlay {
                        RoundedRectangle(cornerRadius: SunwakeRadius.card, style: .continuous)
                            .strokeBorder(SunwakeConstants.emmrichBorder, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private func bar(widthFraction: CGFloat) -> some View {
        GeometryReader { geo in
            Rectangle()
                .fill(SunwakeConstants.emmrichBrass)
                .frame(width: geo.size.width * widthFraction)
        }
        .frame(height: 4.8)
    }
}

// MARK: — Tab-Bar V1: Custom-Glyphen, keine Auswahl-Pille

/// Monochrome Custom-Glyphen (SVG-Referenz aus dem Rundgang, viewBox 19×19).
struct SunwakeTabGlyph: View {
    let tab: AppTab
    var size: CGFloat = 19
    var lineWidth: CGFloat = 1.7

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 19
            let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
                var p = Path()
                p.move(to: pt(x1, y1))
                p.addLine(to: pt(x2, y2))
                context.stroke(p, with: .color(.primary), style: stroke)
            }
            func roundedRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) {
                let p = Path(roundedRect: CGRect(x: x * s, y: y * s, width: w * s, height: h * s), cornerRadius: r * s)
                context.stroke(p, with: .color(.primary), style: stroke)
            }

            switch tab {
            case .today:
                // Sonnenbogen über Horizontlinie mit 3 Strahlen
                var arc = Path()
                arc.addArc(center: pt(9.5, 12), radius: 4.5 * s,
                           startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                context.stroke(arc, with: .color(.primary), style: stroke)
                line(2, 12, 17, 12)
                line(9.5, 3.2, 9.5, 5)
                line(4.2, 5.6, 5.4, 6.9)
                line(14.8, 5.6, 13.6, 6.9)

            case .library:
                // Zwei Buchrücken + schräg angelehntes Buch
                roundedRect(3, 3.5, 3.2, 12, 0.8)
                roundedRect(8, 3.5, 3.2, 12, 0.8)
                var lean = Path()
                lean.move(to: pt(12.8, 4.4))
                lean.addLine(to: pt(15.8, 5.2))
                lean.addLine(to: pt(12.9, 16.2))
                lean.addLine(to: pt(9.9, 15.4))
                context.stroke(lean, with: .color(.primary), style: stroke)

            case .calendar:
                // Raster-Kachel mit Bindungs-Stiften und 2 Termin-Punkten
                roundedRect(2.8, 4, 13.4, 12, 2.4)
                line(2.8, 8, 16.2, 8)
                line(6.5, 2.5, 6.5, 5.5)
                line(12.5, 2.5, 12.5, 5.5)
                context.fill(Path(ellipseIn: CGRect(x: (6.6 - 0.9) * s, y: (11.4 - 0.9) * s, width: 1.8 * s, height: 1.8 * s)), with: .color(.primary))
                context.fill(Path(ellipseIn: CGRect(x: (9.5 - 0.9) * s, y: (11.4 - 0.9) * s, width: 1.8 * s, height: 1.8 * s)), with: .color(.primary))

            case .settings:
                // Zahnrad: gezahnter Ring (Strich-Muster) + Nabe
                let gear = Path(ellipseIn: CGRect(x: (9.5 - 5.6) * s, y: (9.5 - 5.6) * s, width: 11.2 * s, height: 11.2 * s))
                context.stroke(gear, with: .color(.primary),
                               style: StrokeStyle(lineWidth: 2.6, lineCap: .butt, dash: [2.9 * s, 2.96 * s]))
                context.fill(Path(ellipseIn: CGRect(x: (9.5 - 2) * s, y: (9.5 - 2) * s, width: 4 * s, height: 4 * s)), with: .color(.primary))

            case .chat:
                // Sprechblase (Glyph des Chat-Buttons, skaliert auf 19er-Raster)
                let f: CGFloat = 19.0 / 16.0
                var bubble = Path()
                bubble.move(to: pt(2.5 * f, 3.5 * f))
                bubble.addLine(to: pt(13.5 * f, 3.5 * f))
                bubble.addQuadCurve(to: pt(14.5 * f, 4.5 * f), control: pt(14.5 * f, 3.5 * f))
                bubble.addLine(to: pt(14.5 * f, 10.5 * f))
                bubble.addQuadCurve(to: pt(13.5 * f, 11.5 * f), control: pt(14.5 * f, 11.5 * f))
                bubble.addLine(to: pt(6 * f, 11.5 * f))
                bubble.addLine(to: pt(3 * f, 14 * f))
                bubble.addLine(to: pt(3 * f, 11.5 * f))
                bubble.addLine(to: pt(2.5 * f, 11.5 * f))
                bubble.addQuadCurve(to: pt(1.5 * f, 10.5 * f), control: pt(1.5 * f, 11.5 * f))
                bubble.addLine(to: pt(1.5 * f, 4.5 * f))
                bubble.addQuadCurve(to: pt(2.5 * f, 3.5 * f), control: pt(1.5 * f, 3.5 * f))
                context.stroke(bubble, with: .color(.primary), style: stroke)
            }
        }
        .frame(width: size, height: size)
    }
}

struct SunwakeTabBar: View {
    let tabs: [AppTab]
    @Binding var selection: AppTab
    let language: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let isActive = selection == tab
                Button {
                    HapticFeedback.selection()
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        SunwakeTabGlyph(tab: tab, lineWidth: isActive ? 2.0 : 1.7)
                        Text(tab.localizedTitle(language: language))
                            .font(.system(size: 10, weight: isActive ? .bold : .semibold))
                        Circle()
                            .fill(isActive ? Color.sunwakeAccent : Color.clear)
                            .frame(width: 3.5, height: 3.5)
                    }
                    .foregroundStyle(isActive ? Color.sunwakeAccent : Color.sunwakeInkTertiary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.localizedTitle(language: language))
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
            }
        }
        .padding(.top, 9)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .background {
            SunwakeTabBarSurface()
        }
        .accessibilityIdentifier("sunwakeTabBar")
    }
}

/// Tab-Bar-Fläche: die einzige Blur-Fläche der App.
/// Reduce Transparency → opake tabBar-Farbe.
private struct SunwakeTabBarSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: SunwakeRadius.card, bottomLeadingRadius: 0,
            bottomTrailingRadius: 0, topTrailingRadius: SunwakeRadius.card,
            style: .continuous
        )
    }

    var body: some View {
        ZStack {
            if reduceTransparency {
                shape.fill(Color.sunwakeTabBar.opacity(1))
            } else {
                shape.fill(.ultraThinMaterial)
                shape.fill(Color.sunwakeTabBar)
            }
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .sunwakeEdgeLight, location: 0),
                        .init(color: .clear, location: 0.3),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: — AppTab Anzeige-Helfer

extension AppTab {
    func localizedTitle(language: String) -> String {
        let isDE = language == "de"
        switch self {
        case .today:    return isDE ? "Heute" : "Today"
        case .calendar: return isDE ? "Kalender" : "Calendar"
        case .library:  return isDE ? "Bibliothek" : "Library"
        case .chat:     return "Chat"
        case .settings: return isDE ? "Einstellungen" : "Settings"
        }
    }
}

// MARK: — Runder Karten-Button (Chat-Button oben rechts, 32 pt)

struct SunwakeRoundIconButton: View {
    let systemImage: String
    var size: CGFloat = 32
    var iconSize: CGFloat = 15
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(LinearGradient(
                    colors: [.sunwakeCardTop, .sunwakeCardBottom],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .sunwakeEdgeLight, location: 0),
                                .init(color: .clear, location: 0.5),
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                }
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: iconSize, weight: .medium))
                        .foregroundStyle(Color.sunwakeAccent)
                }
                .frame(width: size, height: size)
                .shadow(color: .sunwakeFloatShadow, radius: 8, y: 6)
        }
        .buttonStyle(.plain)
    }
}
