import SwiftUI

// ============================================================
// Briefing-Banner (4a Horizont / 4c Dämmerung)
// Der Teaser öffnet kein Sheet mehr — er morpht an Ort und Stelle
// (matchedGeometryEffect, Spec: Sunwake-App-Spezifikation Abschnitt 5).
// Alle Funktionen des alten Detail-Sheets bleiben erhalten:
// Transformations-Chips, antippbare Termin-/Erinnerungs-Links,
// Vorlesen, „An Chat".
// ============================================================

// MARK: — Oberfläche je Stil

struct BriefingBannerSurface {
    let style: BriefingBannerStyle

    @ViewBuilder
    func background(radius: CGFloat) -> some View {
        switch style {
        case .horizont:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(SunwakeConstants.bannerGradient)
        case .daemmerung:
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(SunwakeConstants.duskSurface)
        }
    }

    var text: Color {
        style == .horizont ? SunwakeConstants.bannerText : SunwakeConstants.duskText
    }

    var label: Color {
        style == .horizont ? SunwakeConstants.bannerLabel : SunwakeConstants.duskLabel
    }

    var chipBackground: Color {
        style == .horizont ? SunwakeConstants.bannerChipBackground : SunwakeConstants.duskLabel.opacity(0.16)
    }

    var chipText: Color {
        style == .horizont ? SunwakeConstants.bannerChipText : SunwakeConstants.duskLabel
    }

    var divider: Color {
        style == .horizont ? SunwakeConstants.bannerDivider : SunwakeConstants.duskLabel.opacity(0.25)
    }
}

// MARK: — Eyebrow „Dein Briefing · 07:00"

enum BriefingBannerInfo {
    /// Geplante Briefing-Zeit für den heutigen Wochentag, falls gesetzt.
    static func scheduledTimeToday() -> String? {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let days = UserDefaults.standard.array(forKey: UserDefaultsKey.briefingScheduleDays) as? [Int] ?? []
        guard days.contains(weekday) else { return nil }
        let hour = UserDefaults.standard.object(forKey: UserDefaultsKey.briefingHourKey(weekday)) as? Int
        let minute = UserDefaults.standard.object(forKey: UserDefaultsKey.briefingMinuteKey(weekday)) as? Int
        guard let hour, let minute else { return nil }
        return String(format: "%02d:%02d", hour, minute)
    }

    static func eyebrowText(language: String) -> String {
        let base = language == "de" ? "Dein Briefing" : "Your briefing"
        if let time = scheduledTimeToday() {
            return "\(base) · \(time)"
        }
        return base
    }
}

// MARK: — Eingeklappter Teaser (in der Scroll-Fläche)

struct BriefingBannerTeaser: View {
    let summary: String
    let style: BriefingBannerStyle
    let language: String
    let onTap: () -> Void

    private var surface: BriefingBannerSurface { .init(style: style) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                SunwakeEyebrow(text: BriefingBannerInfo.eyebrowText(language: language), color: surface.label)
                Text(summary)
                    .font(SunwakeTypography.body)
                    .lineSpacing(5)
                    .foregroundStyle(surface.text)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(language == "de" ? "Antippen zum Aufklappen ›" : "Tap to expand ›")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(surface.label)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background { surface.background(radius: SunwakeRadius.card) }
            .shadow(color: SunwakeConstants.bannerShadow, radius: 14, y: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("todaySummaryCard")
    }
}

// MARK: — Aufgeklappte Detailkarte (Overlay über Scrim)

struct BriefingBannerExpanded: View {
    let summary: String
    let events: [CalendarEvent]
    let reminders: [ReminderItem]
    let style: BriefingBannerStyle
    let language: String
    let ai: AIService
    @ObservedObject var speechService: SpeechService
    let onClose: () -> Void
    let onSendToChat: (String) -> Void
    let onOpenEvent: (CalendarEvent) -> Void
    let onOpenReminder: (ReminderItem) -> Void

    @State private var contentVisible = false
    @State private var dragOffset: CGFloat = 0
    @State private var transformedText: String?
    @State private var isTransforming = false
    @State private var activeTransformation: BriefingTransformation?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var surface: BriefingBannerSurface { .init(style: style) }
    private var displayText: String { transformedText ?? summary }

    private var briefingText: some View {
        Text(attributedBriefing())
            .font(SunwakeTypography.body)
            .lineSpacing(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                handleLink(url)
                return .handled
            })
            .animation(.easeInOut(duration: 0.25), value: displayText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 8)

            // Kurzer Text: Karte schrumpft auf Inhaltshöhe.
            // Langer Text: gedeckelt auf 340 pt, dann scrollbar.
            ViewThatFits(in: .vertical) {
                briefingText
                ScrollView {
                    briefingText
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxHeight: 340)
            // fixedSize NACH dem Frame: Höhe = geclampte Inhaltshöhe statt
            // fixer 340-pt-Slot (frame(maxHeight:) füllt sonst bei
            // unbegrenztem Parent-Vorschlag immer voll aus).
            .fixedSize(horizontal: false, vertical: true)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 12)

            chipRow
                .padding(.top, 12)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background { surface.background(radius: SunwakeRadius.bannerExpanded) }
        .shadow(color: SunwakeConstants.bannerShadow, radius: 14, y: 12)
        .offset(y: dragOffset)
        .gesture(dragToDismiss)
        .onAppear { revealContent() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            SunwakeEyebrow(text: BriefingBannerInfo.eyebrowText(language: language), color: surface.label)
            Spacer()
            Button {
                HapticFeedback.impact(.light)
                toggleSpeech()
            } label: {
                Image(systemName: speechService.isPlaying ? "pause.fill" : (speechService.isPaused ? "play.fill" : "speaker.wave.2"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(surface.label)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(surface.label)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language == "de" ? "Schließen" : "Close")
            .accessibilityIdentifier("briefingCloseButton")
        }
    }

    // MARK: Chips (Stichpunkte / Kürzer / Ausführlicher / An Chat / Original)

    private var chipRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(surface.divider)
                .frame(height: 1)
                .padding(.bottom, 11)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    transformChip(icon: "list.bullet",
                                  title: language == "de" ? "Stichpunkte" : "Bullet points",
                                  transformation: .bulletPoints)
                    transformChip(icon: nil,
                                  title: language == "de" ? "Kürzer" : "Shorter",
                                  transformation: .condense)
                    transformChip(icon: nil,
                                  title: language == "de" ? "Ausführlicher" : "More detail",
                                  transformation: .expand)

                    if transformedText != nil {
                        chip(icon: "arrow.uturn.left", title: "Original") {
                            withAnimation(.easeInOut(duration: 0.2)) { transformedText = nil }
                        }
                    }

                    chip(icon: "bubble.left.fill", title: language == "de" ? "An Chat" : "To chat") {
                        onSendToChat(displayText)
                    }
                }
            }
        }
    }

    private func transformChip(icon: String?, title: String, transformation: BriefingTransformation) -> some View {
        chip(icon: icon, title: title, isBusy: isTransforming && activeTransformation == transformation) {
            guard !isTransforming else { return }
            Task { await applyTransformation(transformation) }
        }
    }

    private func chip(icon: String?, title: String, isBusy: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isBusy {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(surface.chipText)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(surface.chipText)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: SunwakeRadius.chip, style: .continuous)
                    .fill(surface.chipBackground)
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }

    // MARK: Verhalten

    private var dragToDismiss: some Gesture {
        DragGesture()
            .onChanged { value in
                guard value.translation.height > 0 else {
                    dragOffset = 0
                    return
                }
                dragOffset = value.translation.height * 0.4
            }
            .onEnded { value in
                if value.translation.height > 80 {
                    close()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragOffset = 0 }
                }
            }
    }

    private func revealContent() {
        if reduceMotion {
            contentVisible = true
            return
        }
        withAnimation(.easeOut(duration: 0.28).delay(0.06)) { contentVisible = true }
    }

    private func close() {
        // Inhalte faden zuerst, dann der Karten-Morph zurück.
        withAnimation(.easeOut(duration: 0.12)) { contentVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.12)) {
            onClose()
        }
    }

    private func toggleSpeech() {
        if speechService.isPlaying {
            speechService.pause()
        } else if speechService.isPaused {
            speechService.resume()
        } else {
            speechService.speak(
                [SpeechItem(title: "Briefing",
                            text: displayText,
                            language: language == "de" ? "de-DE" : "en-US")],
                accentColorHex: SunwakeConstants.liveActivityAccentHex
            )
        }
    }

    private func applyTransformation(_ t: BriefingTransformation) async {
        isTransforming = true
        activeTransformation = t
        defer { isTransforming = false; activeTransformation = nil }
        let result = await ai.transformBriefing(displayText, into: t, language: language)
        withAnimation(.easeInOut(duration: 0.25)) { transformedText = result }
    }

    // MARK: Attributed Text (Termin-/Erinnerungs-Links bleiben Funktion)

    private func attributedBriefing() -> AttributedString {
        let text = displayText
        let mutable = NSMutableAttributedString(string: text)
        let nsStr = text as NSString
        let full = NSRange(location: 0, length: nsStr.length)
        mutable.addAttribute(.foregroundColor, value: UIColor(surface.text), range: full)

        func mark(title: String, url: URL?) {
            guard !title.isEmpty else { return }
            var location = 0
            while location < nsStr.length {
                let range = nsStr.range(
                    of: title,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: NSRange(location: location, length: nsStr.length - location)
                )
                guard range.location != NSNotFound else { break }
                mutable.addAttribute(.foregroundColor, value: UIColor(surface.chipText), range: range)
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                if let url {
                    mutable.addAttribute(.link, value: url, range: range)
                }
                location = range.upperBound
            }
        }

        for event in events {
            mark(title: event.title, url: briefingURL(scheme: "event", id: event.id))
        }
        for reminder in reminders {
            mark(title: reminder.title, url: briefingURL(scheme: "reminder", id: reminder.id))
        }

        return (try? AttributedString(mutable, including: \.uiKit)) ?? AttributedString(text)
    }

    // Query-Parameter, damit EventKit-IDs mit '/' das Parsen nicht brechen.
    private func briefingURL(scheme: String, id: String) -> URL? {
        var comps = URLComponents()
        comps.scheme = "sunwake"
        comps.host = scheme
        comps.queryItems = [URLQueryItem(name: "id", value: id)]
        return comps.url
    }

    private func handleLink(_ url: URL) {
        guard url.scheme == "sunwake" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let id = comps?.queryItems?.first(where: { $0.name == "id" })?.value ?? ""
        guard !id.isEmpty else { return }
        HapticFeedback.selection()
        switch url.host {
        case "event":
            if let event = events.first(where: { $0.id == id }) { onOpenEvent(event) }
        case "reminder":
            if let reminder = reminders.first(where: { $0.id == id }) { onOpenReminder(reminder) }
        default: break
        }
    }
}
