import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = TodayViewModel()
    // Shared app-wide instance (injected in SunwakeApp) so only one playback
    // pipeline exists — see SpeechService for why two instances conflict.
    @EnvironmentObject private var speechService: SpeechService

    @State private var showPaywall = false
    @State private var showCalendar = false
    @State private var showChatSheet = false
    @State private var showSettingsSheet = false
    @State private var showLibrarySheet = false
    @State private var selectedEvent: CalendarEvent? = nil
    @State private var selectedReminder: ReminderItem? = nil
    @State private var showVoiceQualityHint = false
    @State private var showVoiceSettingsSheet = false

    // Briefing-Banner (4a): morpht in situ statt Sheet
    @Namespace private var briefingNS
    @State private var briefingExpanded = false
    @State private var teaserHeight: CGFloat = 96
    @StateObject private var transformAI = AIService()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        headerRow
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        briefingSection
                            .padding(.horizontal, 20)
                            .padding(.top, 14)

                        if let weather = viewModel.weather {
                            WeatherCard(weather: weather, language: appState.selectedLanguage)
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        }

                        eventsSection
                            .padding(.horizontal, 20)
                            .padding(.top, 18)

                        if !viewModel.reminders.isEmpty {
                            remindersSection
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                        }

                        TomorrowPreviewCard(
                            isPremium: subscriptionManager.effectivelyPremium,
                            isLoading: viewModel.isLoadingTomorrow,
                            hasLoaded: viewModel.hasLoadedTomorrow,
                            summary: viewModel.tomorrowSummary,
                            events: viewModel.tomorrowEvents,
                            language: appState.selectedLanguage,
                            onUnlock: { showPaywall = true },
                            onLoad: { Task { await viewModel.loadTomorrowPreview() } }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        Spacer().frame(height: 190)
                    }
                }
                .scrollDisabled(briefingExpanded)
                .refreshable {
                    viewModel.language = appState.selectedLanguage
                    viewModel.briefingLength = appState.briefingLength
                    viewModel.briefingStyle = appState.briefingStyle
                    await viewModel.refresh()
                }

                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10 + MainTabView.tabBarContentHeight)

                if briefingExpanded {
                    briefingOverlay
                }
            }
            .sunwakeSkyScreen()
            .sunwakeTabBackground()
            .toolbarVisibility(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCalendar) {
                SunwakeCalendarView()
                    .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $showChatSheet) {
                ChatView(isPresentedAsCover: true)
                    .environmentObject(appState)
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showSettingsSheet) {
                NavigationStack { SettingsView() }
                    .environmentObject(appState)
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showLibrarySheet) {
                NavigationStack { LibraryView() }
                    .environmentObject(appState)
                    .environmentObject(subscriptionManager)
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event)
                    .environmentObject(subscriptionManager)
            }
            .sheet(item: $selectedReminder) { reminder in
                ReminderDetailSheet(reminder: reminder, accentColor: .sunwakeAccent, language: appState.selectedLanguage)
            }
            .task {
                viewModel.language = appState.selectedLanguage
                viewModel.briefingLength = appState.briefingLength
                viewModel.briefingStyle = appState.briefingStyle
                refreshVoiceQualityHint()
                await viewModel.loadInitialData()
            }
            .sheet(isPresented: $showVoiceSettingsSheet, onDismiss: refreshVoiceQualityHint) {
                NavigationStack { VoiceSettingsView() }
                    .environmentObject(appState)
                    .environmentObject(speechService)
                    .tint(Color.sunwakeAccent)
            }
            .onChange(of: appState.pendingBriefingForChat) { _, pending in
                guard pending != nil else { return }
                if appState.tabOrder.contains(.chat) {
                    appState.selectedTab = .chat
                } else {
                    showChatSheet = true
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: — Header (V3): Eyebrow-Begrüßung + Datum, rechts Bogen + Aktionen

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                SunwakeEyebrow(
                    text: BriefingNarrator.timeOfDay(language: appState.selectedLanguage).greeting,
                    color: .sunwakeAccentDeep
                )
                Text(Date(), format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(SunwakeTypography.hero)
                    .tracking(-0.3)
                    .foregroundStyle(Color.sunwakeInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
            }

            Spacer(minLength: 4)

            HStack(spacing: 8) {
                if appState.isDeveloperModeActive {
                    DeveloperFeedbackButton(screen: "Today", feature: "Daily Briefing", element: "Header")
                }

                // Briefing-Bogen (A1): Fortschritt beim Erzeugen/Abspielen,
                // Tippen = Play/Pause (gleiche Aktion wie die Play-Leiste).
                Button {
                    HapticFeedback.impact(.light)
                    togglePlayback()
                } label: {
                    BriefingArcGauge(progress: arcProgress)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(appState.selectedLanguage == "de" ? "Briefing abspielen" : "Play briefing")

                topBarButtons
            }
            .padding(.top, 4)
        }
    }

    /// nil = Erzeugen läuft (unbestimmt); sonst Wiedergabe-Position bzw. voll.
    private var arcProgress: Double? {
        if viewModel.isGeneratingAI { return nil }
        if speechService.isPlaying || speechService.isPaused { return speechService.progress }
        return 1.0
    }

    @ViewBuilder
    private var topBarButtons: some View {
        ForEach(Array(appState.topBarActions.prefix(2)), id: \.self) { action in
            switch action {
            case "calendar":
                SunwakeRoundIconButton(systemImage: "calendar") { showCalendar = true }
            case "chat_shortcut":
                SunwakeRoundIconButton(systemImage: "bubble.left") { openChat() }
                    .contextMenu {
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Label(appState.selectedLanguage == "de" ? "Aktualisieren" : "Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .accessibilityIdentifier("chatShortcutButton")
            case "library":
                SunwakeRoundIconButton(systemImage: "books.vertical") {
                    if appState.tabOrder.contains(.library) {
                        appState.selectedTab = .library
                    } else {
                        showLibrarySheet = true
                    }
                }
            case "settings":
                SunwakeRoundIconButton(systemImage: "gearshape") {
                    if appState.tabOrder.contains(.settings) {
                        appState.selectedTab = .settings
                    } else {
                        showSettingsSheet = true
                    }
                }
            case "refresh":
                SunwakeRoundIconButton(systemImage: "arrow.clockwise") {
                    Task { await viewModel.refresh() }
                }
            default:
                EmptyView()
            }
        }
    }

    private func openChat() {
        if appState.tabOrder.contains(.chat) {
            appState.selectedTab = .chat
        } else {
            showChatSheet = true
        }
    }

    private func togglePlayback() {
        if speechService.isPlaying {
            speechService.pause()
        } else if speechService.isPaused {
            speechService.resume()
        } else {
            let item = SpeechItem(
                title: "Briefing",
                text: spokenText,
                language: appState.selectedLanguage == "de" ? "de-DE" : "en-US"
            )
            speechService.speak([item], accentColorHex: SunwakeConstants.liveActivityAccentHex)
        }
    }

    private var spokenText: String {
        viewModel.aiSummary.isEmpty
            ? BriefingNarrator.narrative(events: viewModel.events, reminders: viewModel.reminders, weather: viewModel.weather, language: appState.selectedLanguage)
            : viewModel.aiSummary
    }

    // MARK: — Briefing-Banner

    @ViewBuilder
    private var briefingSection: some View {
        if viewModel.isGeneratingAI && viewModel.aiSummary.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Color.sunwakeAccent)
                Text(appState.selectedLanguage == "de" ? "Briefing wird vorbereitet…" : "Preparing your briefing…")
                    .font(SunwakeTypography.caption)
                    .foregroundStyle(Color.sunwakeInkSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .sunwakeCard()
        } else if !viewModel.aiSummary.isEmpty {
            if briefingExpanded {
                Color.clear.frame(height: teaserHeight)
            } else {
                teaser
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        teaserHeight = height
                    }
            }
        }
    }

    @ViewBuilder
    private var teaser: some View {
        let card = BriefingBannerTeaser(
            summary: viewModel.aiSummary,
            style: appState.briefingBannerStyle,
            language: appState.selectedLanguage,
            onTap: { openBriefing() }
        )
        if reduceMotion {
            card
        } else {
            card.matchedGeometryEffect(id: "briefing.card", in: briefingNS)
        }
    }

    @ViewBuilder
    private var briefingOverlay: some View {
        ZStack(alignment: .top) {
            Color.sunwakeScrim
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { closeBriefing() }

            let expanded = BriefingBannerExpanded(
                summary: viewModel.aiSummary,
                events: viewModel.events,
                reminders: viewModel.reminders,
                style: appState.briefingBannerStyle,
                language: appState.selectedLanguage,
                ai: transformAI,
                speechService: speechService,
                onClose: { closeBriefing() },
                onSendToChat: { text in
                    closeBriefing()
                    appState.pendingBriefingForChat = text
                },
                onOpenEvent: { selectedEvent = $0 },
                onOpenReminder: { selectedReminder = $0 }
            )
            .padding(.horizontal, 20)
            .padding(.top, 72)

            if reduceMotion {
                expanded.transition(.opacity)
            } else {
                expanded.matchedGeometryEffect(id: "briefing.card", in: briefingNS)
            }
        }
    }

    private func openBriefing() {
        HapticFeedback.impact(.soft)
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { briefingExpanded = true }
        } else {
            withAnimation(.spring(response: 0.50, dampingFraction: 0.82)) { briefingExpanded = true }
        }
    }

    private func closeBriefing() {
        HapticFeedback.impact(.light)
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { briefingExpanded = false }
        } else {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.86)) { briefingExpanded = false }
        }
    }

    // MARK: — Termine (dynamischer Leerzustand V2)

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SunwakeSectionLabel(text: sectionTitle(
                de: "Heute · \(viewModel.events.count) \(viewModel.events.count == 1 ? "Termin" : "Termine")",
                en: "Today · \(viewModel.events.count) \(viewModel.events.count == 1 ? "event" : "events")"
            ))

            if viewModel.events.isEmpty && !viewModel.isLoadingEvents {
                SunwakeEmptyState(language: appState.selectedLanguage)
            } else {
                ForEach(viewModel.events) { event in
                    Button { HapticFeedback.selection(); selectedEvent = event } label: {
                        EventCard(event: event, language: appState.selectedLanguage)
                    }
                    .buttonStyle(.plain)
                    .developerFeedbackOverlay(
                        isActive: appState.isDeveloperModeActive,
                        screen: "Today",
                        feature: "Events",
                        element: "Event: \(event.title)"
                    )
                }
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SunwakeSectionLabel(text: sectionTitle(
                de: "Erinnerungen · \(viewModel.reminders.count)",
                en: "Reminders · \(viewModel.reminders.count)"
            ))

            ForEach(viewModel.reminders) { reminder in
                ReminderCard(reminder: reminder)
            }
        }
    }

    private func sectionTitle(de: String, en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    // MARK: — Unten: V4-Hinweis + Play-Leiste

    private var bottomBar: some View {
        VStack(spacing: 6) {
            if showVoiceQualityHint {
                VoiceQualityHintBanner(
                    language: appState.selectedLanguage,
                    onTap: { showVoiceSettingsSheet = true },
                    onDismiss: {
                        UserDefaults.standard.set(true, forKey: UserDefaultsKey.voiceQualityHintDismissed)
                        withAnimation(.easeInOut(duration: 0.2)) { showVoiceQualityHint = false }
                    }
                )
            }
            PlayBarView(
                speechService: speechService,
                spokenText: spokenText,
                language: appState.selectedLanguage
            )
        }
        // Weicher Auslauf hinter Hinweis + Play-Leiste, damit darunter
        // durchscrollender Inhalt die Inline-Zeile (V4) nicht unleserlich macht.
        .padding(.top, 18)
        .background {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Color.sunwakePaper.opacity(0.9), location: 0.35),
                    .init(color: Color.sunwakePaper, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .padding(.horizontal, -16)
            .padding(.bottom, -30)
        }
    }

    /// Show the hint until the user dismisses it or an Enhanced/Premium voice
    /// is installed — the single biggest lever for a natural-sounding briefing.
    private func refreshVoiceQualityHint() {
        let dismissed = UserDefaults.standard.bool(forKey: UserDefaultsKey.voiceQualityHintDismissed)
        let langCode = appState.selectedLanguage == "de" ? "de-DE" : "en-US"
        showVoiceQualityHint = !dismissed && SpeechService.onlyDefaultQualityAvailable(for: langCode)
    }
}

// MARK: — Wetter (Sonnen-Disc + Clash-Großzahl)

struct WeatherCard: View {
    let weather: WeatherData
    let language: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(RadialGradient(
                    colors: [.sunwakeAccentBright, .sunwakeAccent],
                    center: .init(x: 0.35, y: 0.35), startRadius: 0, endRadius: 14
                ))
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.conditionLabel(language: language))
                    .font(SunwakeTypography.listTitle)
                    .foregroundStyle(Color.sunwakeInk)
                HStack(spacing: 8) {
                    Text("↑\(Int(weather.temperatureMax.rounded()))°  ↓\(Int(weather.temperatureMin.rounded()))°")
                    if weather.windSpeed > 0 {
                        Text("· \(Int(weather.windSpeed.rounded())) km/h")
                    }
                }
                .font(SunwakeTypography.caption)
                .foregroundStyle(Color.sunwakeInkTertiary)
            }

            Spacer()

            Text("\(Int(weather.temperatureCurrent.rounded()))°")
                .font(SunwakeTypography.bigNumber)
                .monospacedDigit()
                .foregroundStyle(Color.sunwakeInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .sunwakeCard()
    }
}

// MARK: — Termin-Karte

struct EventCard: View {
    let event: CalendarEvent
    var language: String = "en"

    private var timeString: String {
        if event.isAllDay { return language == "de" ? "Ganztägig" : "All day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendarColor))
                .frame(width: 3, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(SunwakeTypography.listTitle)
                    .foregroundStyle(Color.sunwakeInk)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(timeString)
                    if let location = event.location, !location.isEmpty {
                        Text("· \(location)")
                            .lineLimit(1)
                    }
                }
                .font(SunwakeTypography.caption)
                .foregroundStyle(Color.sunwakeInkTertiary)
            }

            Spacer()

            if isNow {
                Text(language == "de" ? "Jetzt" : "Now")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.sunwakeAccentDeep)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: SunwakeRadius.chip, style: .continuous)
                            .fill(Color.sunwakeTint)
                    )
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .sunwakeCard()
    }

    private var isNow: Bool {
        let now = Date()
        return event.startDate <= now && event.endDate >= now
    }
}

// MARK: — Erinnerungs-Karte

struct ReminderCard: View {
    let reminder: ReminderItem

    private var timeString: String? {
        guard let due = reminder.dueDate, !reminder.isDueTomorrow else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: due)
    }

    var body: some View {
        HStack(spacing: 11) {
            Circle()
                .strokeBorder(Color.sunwakeInkTertiary, lineWidth: 1.6)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if !reminder.priorityLabel.isEmpty {
                        Text(reminder.priorityLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.sunwakeAccentDeep)
                    }
                    Text(reminder.title)
                        .font(SunwakeTypography.listTitle)
                        .foregroundStyle(Color.sunwakeInk)
                        .lineLimit(2)
                }

                if reminder.isDueTomorrow {
                    Text("Bis morgen", comment: "Reminder due tomorrow label")
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(Color.sunwakeAccentDeep)
                } else if let time = timeString {
                    Text(time)
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(Color.sunwakeInkTertiary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .sunwakeCard()
    }
}

// MARK: — Play-Leiste (schwebend, Bogen-Play 5d)

struct PlayBarView: View {
    @ObservedObject var speechService: SpeechService
    /// The exact text that gets spoken (AI briefing or narrator fallback).
    let spokenText: String
    let language: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if speechService.isPlaying {
                    Text(speechService.currentItemTitle)
                        .font(SunwakeTypography.listTitle)
                        .foregroundStyle(Color.sunwakeInk)
                        .lineLimit(1)
                    ProgressView(value: speechService.progress)
                        .tint(Color.sunwakeAccent)
                } else {
                    Text(language == "de" ? "Briefing abspielen" : "Play briefing")
                        .font(SunwakeTypography.listTitle)
                        .foregroundStyle(Color.sunwakeInk)
                    Text(language == "de" ? "Tippe, um deinen Tag zu hören" : "Tap to hear your day read aloud")
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(Color.sunwakeInkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                if speechService.isPlaying || speechService.isPaused {
                    Button {
                        HapticFeedback.impact(.light)
                        speechService.skipBackward()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.sunwakeInkSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    HapticFeedback.impact(.medium)
                    if speechService.isPlaying {
                        speechService.pause()
                    } else if speechService.isPaused {
                        speechService.resume()
                    } else {
                        let item = SpeechItem(
                            title: "Briefing",
                            text: spokenText,
                            language: language == "de" ? "de-DE" : "en-US"
                        )
                        speechService.speak([item], accentColorHex: SunwakeConstants.liveActivityAccentHex)
                    }
                } label: {
                    SunArcButtonLabel(systemImage: speechService.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)

                if speechService.isPlaying || speechService.isPaused {
                    Button {
                        HapticFeedback.impact(.light)
                        speechService.skipForward()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.sunwakeInkSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .sunwakeFloating()
    }
}

// MARK: — Stimme-Hinweis (V4): Inline-Zeile ohne Karte

struct VoiceQualityHintBanner: View {
    let language: String
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 8) {
                    waveform
                    Text(language == "de"
                         ? "Natürlichere Stimme verfügbar — laden"
                         : "A more natural voice is available — download")
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(Color.sunwakeInkSecondary)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.sunwakeInkTertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 2) {
            RoundedRectangle(cornerRadius: 1).fill(Color.sunwakeAccent).frame(width: 2.5, height: 8)
            RoundedRectangle(cornerRadius: 1).fill(Color.sunwakeAccent).frame(width: 2.5, height: 13)
            RoundedRectangle(cornerRadius: 1).fill(Color.sunwakeAccent).frame(width: 2.5, height: 6)
        }
    }
}

// MARK: — Ausblick auf morgen (Premium)

struct TomorrowPreviewCard: View {
    let isPremium: Bool
    let isLoading: Bool
    let hasLoaded: Bool
    let summary: String
    let events: [CalendarEvent]
    let language: String
    let onUnlock: () -> Void
    let onLoad: () -> Void

    private var isDE: Bool { language == "de" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(isDE ? "Ausblick auf morgen" : "Tomorrow's outlook")
                        .font(SunwakeTypography.headline)
                        .foregroundStyle(Color.sunwakeInk)
                } icon: {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.sunwakeAccent)
                }
                Spacer()
                if !isPremium {
                    PremiumBadge()
                }
            }

            if !isPremium {
                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                        Text(isDE
                             ? "Mit Premium siehst du schon heute, was morgen ansteht."
                             : "With Premium, see tonight what tomorrow holds.")
                            .font(SunwakeTypography.caption)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(Color.sunwakeInkSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Color.sunwakeAccent)
                    Text(isDE ? "Morgen wird vorbereitet…" : "Preparing tomorrow…")
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(Color.sunwakeInkSecondary)
                }
            } else if hasLoaded {
                if !summary.isEmpty {
                    Text(summary)
                        .font(SunwakeTypography.callout)
                        .foregroundStyle(Color.sunwakeInkSecondary)
                        .lineSpacing(4)
                }
                ForEach(events) { event in
                    HStack(spacing: 10) {
                        Text(timeLabel(for: event))
                            .font(SunwakeTypography.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Color.sunwakeAccent)
                            .frame(width: 64, alignment: .leading)
                        Text(event.title)
                            .font(SunwakeTypography.caption)
                            .foregroundStyle(Color.sunwakeInk)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                }
                Button(action: onLoad) {
                    Label(isDE ? "Aktualisieren" : "Refresh", systemImage: "arrow.clockwise")
                        .font(SunwakeTypography.caption.weight(.semibold))
                        .foregroundStyle(Color.sunwakeAccentDeep)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onLoad) {
                    Text(isDE ? "Vorschau erstellen" : "Generate preview")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.sunwakeOnAccent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: SunwakeRadius.control, style: .continuous)
                                .fill(LinearGradient(
                                    colors: [.sunwakeAccentBright, .sunwakeAccent],
                                    startPoint: .top, endPoint: .bottom
                                ))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sunwakeCard()
    }

    private func timeLabel(for event: CalendarEvent) -> String {
        if event.isAllDay { return isDE ? "Ganztägig" : "All day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: event.startDate)
    }
}
