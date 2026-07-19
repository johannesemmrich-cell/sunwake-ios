import SwiftUI
import SwiftData
import EventKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var versionTapCount = 0
    @State private var showDeveloperUnlock = false
    @State private var showPaywall = false
    @State private var showResetOnboardingConfirm = false

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                        .padding(.top, 8)

                    // Calendar & Reminders
                    settingsGroup(loc("Kalender", "Calendar")) {
                        navRow(icon: "calendar", title: loc("Verbundene Kalender", "Connected Calendars")) {
                            CalendarSettingsView()
                        }
                        divider
                        navRow(icon: "checklist", title: loc("Erinnerungen", "Reminders")) {
                            ReminderSettingsView()
                        }
                    }

                    // Notifications
                    settingsGroup(loc("Mitteilungen", "Notifications")) {
                        navRow(icon: "calendar.badge.clock", title: loc("Briefing-Zeitplan", "Briefing schedule")) {
                            BriefingScheduleView()
                        }
                    }

                    // Voice
                    settingsGroup(loc("Vorlesen", "Read aloud")) {
                        navRow(icon: "waveform", title: loc("Stimme", "Voice")) {
                            VoiceSettingsView()
                        }
                    }

                    // Appearance (Design + NEU: Briefing-Stil 4c)
                    settingsGroup(loc("Darstellung", "Appearance")) {
                        row(icon: "paintbrush", title: loc("Design", "Theme")) {
                            SunwakeSegmented(
                                options: AppTheme.allCases,
                                selection: $themeManager.currentTheme
                            ) { $0.displayName(language: appState.selectedLanguage) }
                        }
                        divider
                        row(icon: "sun.horizon", title: loc("Briefing-Stil", "Briefing style")) {
                            SunwakeSegmented(
                                options: BriefingBannerStyle.allCases,
                                selection: $appState.briefingBannerStyle
                            ) { $0.displayName(language: appState.selectedLanguage) }
                        }
                    }

                    // Subscription
                    settingsGroup(loc("Abo", "Subscription")) {
                        if subscriptionManager.effectivelyPremium {
                            row(icon: "star.fill", title: loc("Premium aktiv", "Premium Active"), titleColor: .sunwakeAccentDeep) {
                                EmptyView()
                            }
                        } else {
                            buttonRow(icon: "star", title: loc("Auf Premium upgraden", "Upgrade to Premium"), detail: loc("2 €/Monat", "€2/mo")) {
                                showPaywall = true
                            }
                        }
                        divider
                        buttonRow(icon: "arrow.clockwise.circle", title: loc("Käufe wiederherstellen", "Restore Purchases"), titleColor: .sunwakeInkSecondary) {
                            Task { await subscriptionManager.restorePurchases() }
                        }
                    }

                    // Premium customization
                    if subscriptionManager.effectivelyPremium {
                        settingsGroup("Premium") {
                            navRow(icon: "wand.and.sparkles", title: loc("Briefing einstellen", "Briefing settings")) {
                                BriefingSettingsView()
                            }
                            divider
                            navRow(icon: "paintpalette.fill", title: loc("App-Layout", "App layout")) {
                                AppLayoutConfigView()
                            }
                            divider
                            navRow(icon: "app.badge", title: loc("App-Icon", "App icon")) {
                                AppIconPickerView()
                            }
                        }
                    }

                    // About
                    settingsGroup(loc("Über", "About")) {
                        navRow(icon: "info.circle", title: loc("Über Sunwake", "About Sunwake")) {
                            AboutView()
                        }
                        divider
                        navRow(icon: "hand.raised", title: loc("Datenschutz", "Privacy")) {
                            PrivacyView()
                        }
                        divider
                        buttonRow(icon: "arrow.counterclockwise", title: loc("Onboarding wiederholen", "Repeat onboarding")) {
                            showResetOnboardingConfirm = true
                        }
                    }

                    if appState.isDeveloperModeActive {
                        settingsGroup("Developer") {
                            navRow(icon: "hammer.fill", title: "Developer Mode", titleColor: .red) {
                                DeveloperModeView()
                            }
                        }
                    }

                    // Mehr von Emmrich — Familien-Banner (Messing-Konstante)
                    VStack(alignment: .leading, spacing: 8) {
                        SunwakeSectionLabel(text: loc("Mehr von Emmrich", "More from Emmrich"))
                        EmmrichBanner()
                    }

                    versionFooter
                        .padding(.top, 2)

                    Spacer().frame(height: 20 + MainTabView.tabBarContentHeight)
                }
                .padding(.horizontal, 20)
            }
            .sunwakeSkyScreen()
            .sunwakeTabBackground()
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showDeveloperUnlock) {
            DeveloperUnlockSheet(isPresented: $showDeveloperUnlock)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .confirmationDialog(
            loc("Onboarding wiederholen?", "Repeat onboarding?"),
            isPresented: $showResetOnboardingConfirm,
            titleVisibility: .visible
        ) {
            Button(loc("Onboarding starten", "Start onboarding"), role: .destructive) {
                resetOnboarding()
            }
            Button(loc("Abbrechen", "Cancel"), role: .cancel) {}
        } message: {
            Text(loc("Die App startet das Onboarding erneut. Deine Daten bleiben erhalten.",
                     "The app will run onboarding again. Your data is kept."))
        }
    }

    // MARK: — Bausteine

    private var header: some View {
        HStack(alignment: .top) {
            Text(loc("Einstellungen", "Settings"))
                .font(SunwakeTypography.title)
                .foregroundStyle(Color.sunwakeInk)
            Spacer()
            if appState.isDeveloperModeActive {
                DeveloperFeedbackButton(screen: "Settings", feature: "General", element: "Header")
            }
        }
    }

    @ViewBuilder
    private func settingsGroup(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SunwakeSectionLabel(text: title)
            VStack(spacing: 0) {
                content()
            }
            .sunwakeCard()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.sunwakeHairline)
            .frame(height: 1)
            .padding(.leading, 51)
    }

    private func rowLabel(icon: String, title: String, titleColor: Color = .sunwakeInk) -> some View {
        HStack(spacing: 12) {
            SunwakeIconTile(systemImage: icon)
            Text(title)
                .font(SunwakeTypography.listTitle)
                .foregroundStyle(titleColor)
        }
    }

    @ViewBuilder
    private func navRow(icon: String, title: String, titleColor: Color = .sunwakeInk, @ViewBuilder destination: () -> some View) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                rowLabel(icon: icon, title: title, titleColor: titleColor)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.sunwakeInkTertiary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func row(icon: String, title: String, titleColor: Color = .sunwakeInk, @ViewBuilder accessory: () -> some View) -> some View {
        HStack {
            rowLabel(icon: icon, title: title, titleColor: titleColor)
            Spacer()
            accessory()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
    }

    @ViewBuilder
    private func buttonRow(icon: String, title: String, detail: String? = nil, titleColor: Color = .sunwakeInk, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                rowLabel(icon: icon, title: title, titleColor: titleColor)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(Color.sunwakeInkSecondary)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var versionFooter: some View {
        Button {
            handleVersionTap()
        } label: {
            HStack(spacing: 6) {
                Spacer()
                Text("Sunwake \(appVersion) (\(buildNumber))")
                    .font(SunwakeTypography.caption2)
                    .foregroundStyle(Color.sunwakeInkTertiary)
                if appState.isDeveloperModeActive {
                    Text("DEV")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.red))
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    private func resetOnboarding() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKey.hasCompletedOnboarding)
        withAnimation(.easeInOut(duration: 0.5)) {
            appState.hasCompletedOnboarding = false
        }
    }

    private func handleVersionTap() {
        versionTapCount += 1
        if versionTapCount >= 5 {
            versionTapCount = 0
            showDeveloperUnlock = true
        }
    }
}

// MARK: — Calendar Settings

struct CalendarSettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @State private var availableCalendars: [EKCalendar] = []
    @State private var excludedIDs: Set<String> = BriefingExclusionStore.excludedIDs

    private var calendarsByProvider: [(CalendarProvider, [EKCalendar])] {
        CalendarProvider.allCases.compactMap { provider in
            let cals = availableCalendars.filter { $0.provider == provider }
            return cals.isEmpty ? nil : (provider, cals)
        }
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    var body: some View {
        List {
            // Connected providers
            Section {
                CalendarProviderButton(name: "Apple Calendar", icon: "applelogo", color: .primary, isLoading: false) {}
                CalendarProviderButton(name: "Google Calendar", icon: "globe", color: .sunwakeInkSecondary, isLoading: false, badge: loc("Bald verfügbar", "Coming soon")) {}
                CalendarProviderButton(name: "Outlook", icon: "envelope.fill", color: .sunwakeInkSecondary, isLoading: false, badge: loc("Bald verfügbar", "Coming soon")) {}
            } header: {
                Text(loc("Verbundene Anbieter", "Connected providers"))
            } footer: {
                if !subscriptionManager.effectivelyPremium {
                    Text(loc("Free plan: 1 Kalender. Mit Premium mehrere Anbieter verbinden.", "Free plan: 1 calendar. Connect multiple providers with Premium."))
                        .font(SunwakeTypography.caption)
                }
            }

            // Briefing inclusion per calendar
            if !availableCalendars.isEmpty {
                ForEach(calendarsByProvider, id: \.0.id) { provider, cals in
                    Section {
                        ForEach(cals, id: \.calendarIdentifier) { cal in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(cgColor: cal.cgColor))
                                    .frame(width: 10, height: 10)
                                Text(cal.title)
                                    .font(SunwakeTypography.callout)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { !excludedIDs.contains(cal.calendarIdentifier) },
                                    set: { include in
                                        if include {
                                            excludedIDs.remove(cal.calendarIdentifier)
                                        } else {
                                            excludedIDs.insert(cal.calendarIdentifier)
                                        }
                                        BriefingExclusionStore.excludedIDs = excludedIDs
                                    }
                                ))
                                .labelsHidden()
                                .tint(Color.sunwakeAccent)
                            }
                        }
                    } header: {
                        Label(provider.displayName(language: appState.selectedLanguage), systemImage: provider.systemImage)
                    } footer: {
                        Text(loc("Deaktivierte Kalender erscheinen nicht im Briefing.", "Disabled calendars won't appear in the briefing."))
                            .font(SunwakeTypography.caption)
                    }
                }
            }
        }
        .navigationTitle(loc("Kalender", "Calendar"))
        .listStyle(.insetGrouped)
        .sunwakePaperScreen()
        .onAppear {
            excludedIDs = BriefingExclusionStore.excludedIDs
        }
        .task {
            let store = EKEventStore()
            if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
                availableCalendars = store.calendars(for: .event)
            }
        }
    }
}

// MARK: — About & Privacy

struct AboutView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section {
                HStack {
                    SunArcMotif()
                        .scaleEffect(0.7)
                        .frame(width: 64, height: 44)
                    VStack(alignment: .leading) {
                        Text("Sunwake")
                            .font(SunwakeTypography.title3)
                        Text(loc("Dein Morgen-Briefing", "Your morning briefing"))
                            .font(SunwakeTypography.caption)
                            .foregroundStyle(Color.sunwakeInkSecondary)
                    }
                }
                .padding(.vertical, 8)
            }
            Section(loc("Technologie", "Technology")) {
                Label(loc("Gebaut mit SwiftUI & SwiftData", "Built with SwiftUI & SwiftData"), systemImage: "swift")
                Label(loc("KI auf dem Gerät mit Apple Foundation Models", "On-device AI via Apple Foundation Models"), systemImage: "brain")
                Label(loc("PDFs werden komplett auf dem Gerät verarbeitet", "PDFs processed entirely on-device"), systemImage: "lock.shield")
            }
        }
        .navigationTitle(loc("Über", "About"))
        .listStyle(.insetGrouped)
        .sunwakePaperScreen()
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }
}

struct PrivacyView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        List {
            Section(loc("Deine Privatsphäre", "Your privacy")) {
                Label(loc("Kein Konto, kein Tracking", "No account, no tracking"), systemImage: "person.slash")
                Label(loc("KI läuft komplett auf dem Gerät", "AI runs entirely on-device"), systemImage: "iphone")
                Label(loc("PDFs bleiben auf deinem Gerät", "PDFs never leave your device"), systemImage: "doc.fill")
                Label(loc("Kalenderdaten bleiben lokal", "Calendar data stays local"), systemImage: "calendar")
            }
        }
        .navigationTitle(loc("Datenschutz", "Privacy"))
        .listStyle(.insetGrouped)
        .sunwakePaperScreen()
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }
}
