import SwiftUI
import EventKit
import SwiftData

// MARK: — Main Calendar View

struct SunwakeCalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var selectedEvent: CalendarEvent?
    @State private var showAddEvent = false

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                calendarHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                WeekStripView(
                    selectedDate: $viewModel.selectedDate,
                    eventDays: viewModel.eventDays,
                    onVisibleRangeChange: { start, end in
                        Task { await viewModel.loadEventDays(from: start, to: end) }
                    }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                if !viewModel.availableCalendars.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            // Provider filter
                            CalendarFilterPill(title: loc("Alle", "All"), color: .sunwakeAccent,
                                isSelected: viewModel.selectedProvider == nil && viewModel.selectedCalendarIDs.isEmpty) {
                                withAnimation(.spring(duration: 0.2)) {
                                    viewModel.selectedProvider = nil
                                    viewModel.selectedCalendarIDs = []
                                }
                            }
                            ForEach(viewModel.availableProviders) { provider in
                                CalendarFilterPill(
                                    title: provider.displayName(language: appState.selectedLanguage),
                                    color: provider.pillColor,
                                    isSelected: viewModel.selectedProvider == provider
                                ) {
                                    withAnimation(.spring(duration: 0.2)) {
                                        viewModel.selectedProvider = viewModel.selectedProvider == provider ? nil : provider
                                        viewModel.selectedCalendarIDs = []
                                    }
                                }
                            }
                            if !viewModel.visibleCalendars.isEmpty {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.25))
                                    .frame(width: 1, height: 20)
                                ForEach(viewModel.visibleCalendars, id: \.calendarIdentifier) { cal in
                                    CalendarFilterPill(
                                        title: cal.title,
                                        color: Color(cgColor: cal.cgColor),
                                        isSelected: viewModel.selectedCalendarIDs.contains(cal.calendarIdentifier)
                                    ) {
                                        withAnimation(.spring(duration: 0.2)) {
                                            viewModel.toggleCalendar(cal.calendarIdentifier)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }

                Group {
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Color.sunwakeAccent)
                        Spacer()
                    } else {
                        dayContent
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: viewModel.filteredEvents.map(\.id))
            }
            .sunwakeSkyScreen()
            .sunwakeTabBackground()
            .toolbarVisibility(.hidden, for: .navigationBar)
            .task { await viewModel.setup() }
            .onChange(of: viewModel.selectedDate) { Task { await viewModel.fetchEvents() } }
            .onChange(of: viewModel.selectedCalendarIDs) { Task { await viewModel.fetchEvents() } }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event)
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showAddEvent) {
                AddEventSheet(defaultDate: viewModel.selectedDate) {
                    Task { await viewModel.fetchEvents() }
                }
            }
        }
    }

    // Header (V3): Eyebrow-Kontextzeile + Titel, rechts + und „Heute".
    private var calendarHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                SunwakeEyebrow(text: loc("Diese Woche", "This week"), color: .sunwakeAccentDeep)
                Text(loc("Kalender", "Calendar"))
                    .font(SunwakeTypography.title)
                    .foregroundStyle(Color.sunwakeInk)
            }
            Spacer()
            HStack(spacing: 8) {
                if appState.isDeveloperModeActive {
                    DeveloperFeedbackButton(screen: "Calendar", feature: "Calendar View", element: "Header")
                }
                if !viewModel.selectedDate.isToday {
                    Button {
                        withAnimation(.spring(duration: 0.3)) { viewModel.selectedDate = Date() }
                    } label: {
                        SunwakeChipLabel(text: loc("Heute", "Today"))
                    }
                    .buttonStyle(.plain)
                }
                SunwakeRoundIconButton(systemImage: "plus") {
                    showAddEvent = true
                }
            }
            .padding(.top, 4)
        }
    }

    /// Sektionstitel immer mit Zähler: „Heute · 2 Termine" / „Dienstag, 21. Juli · 1 Termin".
    private var daySectionTitle: String {
        let count = viewModel.filteredEvents.count
        let countText = appState.selectedLanguage == "de"
            ? "\(count) Termin\(count == 1 ? "" : "e")"
            : "\(count) event\(count == 1 ? "" : "s")"
        let dayText = viewModel.selectedDate.isToday
            ? loc("Heute", "Today")
            : viewModel.selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return "\(dayText) · \(countText)"
    }

    /// Tagesinhalt wie im Rundgang: Sektion des gewählten Tags (Liste oder
    /// Bogen-Leerzustand) — und wenn „Heute" gewählt ist, darunter die
    /// Vorschau des nächsten Tags mit Terminen.
    private var dayContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                SunwakeSectionLabel(text: daySectionTitle)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                if viewModel.filteredEvents.isEmpty {
                    if viewModel.selectedDate.isToday {
                        SunwakeEmptyState(language: appState.selectedLanguage)
                            .padding(.top, 10)
                    } else {
                        VStack(spacing: 12) {
                            SunArcMotif()
                            Text(loc("Keine Termine", "No events"))
                                .font(SunwakeTypography.headline)
                                .foregroundStyle(Color.sunwakeInk)
                                .padding(.top, 4)
                            Text(loc("An diesem Tag sind keine Termine.", "No events scheduled for this day."))
                                .font(SunwakeTypography.caption)
                                .foregroundStyle(Color.sunwakeInkSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 26)
                    }
                } else {
                    eventCards(viewModel.filteredEvents)
                }

                nextDaySection

                Spacer().frame(height: 24 + MainTabView.tabBarContentHeight)
            }
        }
    }

    @ViewBuilder
    private var nextDaySection: some View {
        if viewModel.selectedDate.isToday,
           let preview = viewModel.nextDayPreview {
            let previewEvents = viewModel.applyFilters(preview.events)
            if !previewEvents.isEmpty {
                SunwakeSectionLabel(text: preview.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                eventCards(previewEvents)
            }
        }
    }

    private func eventCards(_ events: [CalendarEvent]) -> some View {
        VStack(spacing: 8) {
            ForEach(events) { event in
                AgendaEventRow(event: event, language: appState.selectedLanguage) {
                    selectedEvent = event
                }
                .padding(.horizontal, 20)
                .developerFeedbackOverlay(
                    isActive: appState.isDeveloperModeActive,
                    screen: "Calendar",
                    feature: "Events",
                    element: "Event: \(event.title)"
                )
            }
        }
    }
}

// MARK: — Week Strip (Karte mit 2 Wochen, Termin-Punkten und Monatskopf)

struct WeekStripView: View {
    @Binding var selectedDate: Date
    var eventDays: Set<Date> = []
    var onVisibleRangeChange: ((Date, Date) -> Void)? = nil

    @State private var weekOffset: Int = 0

    private func week(at offset: Int) -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let base = cal.date(byAdding: .weekOfYear, value: offset, to: today)!
        let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: base))!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    private var firstWeek: [Date] { week(at: weekOffset) }
    private var secondWeek: [Date] { week(at: weekOffset + 1) }

    private var monthLabel: String {
        guard let first = firstWeek.first, let last = secondWeek.last else { return "" }
        let cal = Calendar.current
        if cal.component(.month, from: first) == cal.component(.month, from: last) {
            return first.formatted(.dateTime.month(.wide).year())
        }
        return "\(first.formatted(.dateTime.month(.abbreviated))) / \(last.formatted(.dateTime.month(.abbreviated).year()))"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(monthLabel)
                    .font(SunwakeFont.display(17, .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.sunwakeInk)
                    .animation(.easeInOut(duration: 0.2), value: monthLabel)

                Spacer()

                HStack(spacing: 2) {
                    chevron("chevron.left") { shiftWeeks(-1) }
                    chevron("chevron.right") { shiftWeeks(1) }
                }
            }

            // Kopfzeile M D M D F S S
            HStack(spacing: 0) {
                ForEach(firstWeek, id: \.self) { day in
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.sunwakeInkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            weekRow(firstWeek)
            weekRow(secondWeek)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .sunwakeCard()
        .onAppear { notifyRange() }
    }

    private func chevron(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.sunwakeAccent)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shiftWeeks(_ delta: Int) {
        withAnimation(.spring(duration: 0.25)) { weekOffset += delta }
        notifyRange()
    }

    private func notifyRange() {
        guard let start = firstWeek.first,
              let lastDay = secondWeek.last,
              let end = Calendar.current.date(byAdding: .day, value: 1, to: lastDay) else { return }
        onVisibleRangeChange?(start, end)
    }

    private func weekRow(_ days: [Date]) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                DayButton(
                    date: day,
                    isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate),
                    hasEvents: eventDays.contains(Calendar.current.startOfDay(for: day))
                ) {
                    withAnimation(.spring(duration: 0.22)) { selectedDate = day }
                }
            }
        }
    }
}

struct DayButton: View {
    let date: Date
    let isSelected: Bool
    var hasEvents: Bool = false
    let action: () -> Void

    private var isToday: Bool { date.isToday }

    var body: some View {
        Button {
            HapticFeedback.selection()
            action()
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: SunwakeRadius.iconTile, style: .continuous)
                            .fill(Color.sunwakeAccent)
                            .frame(width: 32, height: 32)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: SunwakeRadius.iconTile, style: .continuous)
                            .strokeBorder(Color.sunwakeAccent, lineWidth: 1.5)
                            .frame(width: 32, height: 32)
                    }

                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 15, weight: isSelected || isToday ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.sunwakeOnAccent : (isToday ? Color.sunwakeAccent : Color.sunwakeInk))
                }
                .frame(height: 32)

                Circle()
                    .fill(hasEvents && !isSelected ? Color.sunwakeAccent : Color.clear)
                    .frame(width: 3.5, height: 3.5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.22), value: isSelected)
    }
}

// MARK: — Calendar Filter Pill

struct CalendarFilterPill: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: SunwakeRadius.chip, style: .continuous)
                    .fill(isSelected ? Color.sunwakeTint : Color.sunwakeWell)
            )
            .foregroundStyle(isSelected ? Color.sunwakeAccentDeep : Color.sunwakeInkSecondary)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.18), value: isSelected)
    }
}

// MARK: — Agenda Event Row

struct AgendaEventRow: View {
    let event: CalendarEvent
    let language: String
    let onTap: () -> Void

    private var isDE: Bool { language == "de" }

    private var timeString: String {
        if event.isAllDay { return isDE ? "Ganztägig" : "All day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    private var isNow: Bool {
        guard !event.isAllDay else { return false }
        let now = Date()
        return event.startDate <= now && event.endDate >= now
    }

    // Rundgang-Layout: Farb-Bar, Titel, EINE Meta-Zeile „09:30 – 10:15 · Ort".
    private var metaLine: String {
        if let loc = event.location, !loc.isEmpty {
            return "\(timeString) · \(loc)"
        }
        return timeString
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(cgColor: event.calendarColor))
                    .frame(width: 3, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(SunwakeTypography.listTitle)
                        .foregroundStyle(Color.sunwakeInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(metaLine)
                        .font(SunwakeTypography.caption)
                        .foregroundStyle(Color.sunwakeInkTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isNow {
                    Text(isDE ? "Jetzt" : "Now")
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
            .padding(.vertical, 12)
            .sunwakeCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: — Event Detail Sheet

struct EventDetailSheet: View {
    let event: CalendarEvent
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var matchingNotes: [CalendarEventNote]
    @State private var draftNotes: String = ""
    @State private var draftKeywords: String = ""
    @State private var showAIChat = false
    @State private var showDeleteConfirm = false
    @State private var showReschedule = false

    private let calendarService = CalendarService()

    init(event: CalendarEvent) {
        self.event = event
        let eid = event.id
        _matchingNotes = Query(filter: #Predicate<CalendarEventNote> { $0.eventIdentifier == eid })
    }

    private var existingNote: CalendarEventNote? { matchingNotes.first }
    private var hasChanges: Bool {
        draftNotes != (existingNote?.customNotes ?? "") ||
        draftKeywords != (existingNote?.linkedKeywords ?? "")
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    private var timeString: String {
        if event.isAllDay { return loc("Ganztägig", "All day") }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(cgColor: event.calendarColor))
                                .frame(width: 6, height: 40)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title)
                                    .font(SunwakeTypography.title3.weight(.bold))
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(cgColor: event.calendarColor))
                                        .frame(width: 7, height: 7)
                                    Text(event.calendarTitle)
                                        .font(SunwakeTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        // Meta rows
                        metaRow(icon: "clock", text: timeString)
                        if let loc = event.location, !loc.isEmpty {
                            metaRow(icon: "mappin", text: loc)
                        }
                        metaRow(icon: "calendar", text: event.selectedDate)
                    }
                    .padding(16)
                    .background(Color.sunwakeWell)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Apple Calendar notes
                    if let notes = event.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(loc("Aus der Kalender-App", "From the Calendar app"), systemImage: "calendar.badge.checkmark")
                                .font(SunwakeTypography.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(notes)
                                .font(SunwakeTypography.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.sunwakeAccent.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.sunwakeAccent.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    }

                    // User notes
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc("Meine Notizen", "My notes"), systemImage: "pencil.and.outline")
                            .font(SunwakeTypography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextEditor(text: $draftNotes)
                            .font(SunwakeTypography.body)
                            .frame(minHeight: 100)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .tertiarySystemBackground))
                            )
                            .onChange(of: draftNotes) { _, _ in }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    // Keywords / file links
                    VStack(alignment: .leading, spacing: 8) {
                        Label(loc("Stichwörter & Dateien", "Keywords & files"), systemImage: "link")
                            .font(SunwakeTypography.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(loc("z.B. App-Idee, Projekt Alpha, Rechnung", "e.g. App idea, Project Alpha, Invoice"), text: $draftKeywords)
                            .font(SunwakeTypography.body)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(uiColor: .tertiarySystemBackground))
                            )
                        if !draftKeywords.isEmpty {
                            let tags = draftKeywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                            if !tags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(SunwakeTypography.caption2.weight(.medium))
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 4)
                                                .background(RoundedRectangle(cornerRadius: SunwakeRadius.chip, style: .continuous).fill(Color.sunwakeTint))
                                                .foregroundStyle(Color.sunwakeAccentDeep)
                                        }
                                    }
                                }
                            }
                        }
                        Text(loc("Komma-getrennte Stichworte. Der KI-Chat findet passende Dateien automatisch.", "Comma-separated keywords. The AI chat finds matching files automatically."))
                            .font(SunwakeTypography.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    // AI Chat (Premium)
                    if subscriptionManager.effectivelyPremium {
                        Button {
                            showAIChat = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.sunwakeAccent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc("Mit KI besprechen", "Discuss with AI"))
                                        .font(SunwakeTypography.callout.weight(.semibold))
                                    Text(loc("Fragen stellen, Zusammenhänge entdecken", "Ask questions, discover connections"))
                                        .font(SunwakeTypography.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.sunwakeWell)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc("Mit KI besprechen", "Discuss with AI"))
                                    .font(SunwakeTypography.callout)
                                    .foregroundStyle(.secondary)
                                Text(loc("Nur mit Premium", "Premium only"))
                                    .font(SunwakeTypography.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.sunwakeWell.opacity(0.5))
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    }

                    Spacer().frame(height: 32)
                }
            }
            .background(Color.sunwakePaper)
            .navigationTitle(loc("Termin", "Event"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(loc("Schließen", "Close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        if hasChanges {
                            Button(loc("Speichern", "Save")) { saveNotes() }
                                .fontWeight(.semibold)
                        }
                        if !event.isAllDay {
                            Button {
                                showReschedule = true
                            } label: {
                                Image(systemName: "clock.arrow.2.circlepath")
                            }
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .confirmationDialog(loc("Termin löschen?", "Delete event?"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button(loc("Löschen", "Delete"), role: .destructive) {
                    HapticFeedback.impact(.medium)
                    Task {
                        try? await calendarService.deleteEvent(identifier: event.id, language: appState.selectedLanguage)
                        dismiss()
                    }
                }
                Button(loc("Abbrechen", "Cancel"), role: .cancel) {}
            } message: {
                Text(loc("Der Termin '\(event.title)' wird dauerhaft aus dem Kalender entfernt.",
                         "The event '\(event.title)' will be permanently removed from the calendar."))
            }
            .onAppear {
                draftNotes = existingNote?.customNotes ?? ""
                draftKeywords = existingNote?.linkedKeywords ?? ""
            }
            .sheet(isPresented: $showReschedule) {
                RescheduleSheet(event: event, calendarService: calendarService) {
                    dismiss()
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(SunwakeRadius.sheet)
            }
            .sheet(isPresented: $showAIChat) {
                EventAIChatSheet(event: event, userNotes: draftNotes, keywords: draftKeywords)
            }
        }
    }

    @ViewBuilder
    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(SunwakeTypography.callout)
                .foregroundStyle(.primary)
        }
    }

    private func saveNotes() {
        if let existing = existingNote {
            existing.customNotes = draftNotes
            existing.linkedKeywords = draftKeywords
            existing.updatedAt = Date()
        } else {
            let note = CalendarEventNote(
                eventIdentifier: event.id,
                customNotes: draftNotes,
                linkedKeywords: draftKeywords
            )
            modelContext.insert(note)
        }
        dismiss()
    }
}

// MARK: — Reschedule Sheet

private struct RescheduleSheet: View {
    let event: CalendarEvent
    let calendarService: CalendarService
    let onDone: () -> Void

    @State private var newStart: Date
    @State private var newEnd: Date
    @State private var isSaving = false
    @State private var errorMessage: String?
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    init(event: CalendarEvent, calendarService: CalendarService, onDone: @escaping () -> Void) {
        self.event = event
        self.calendarService = calendarService
        self.onDone = onDone
        _newStart = State(initialValue: event.startDate)
        _newEnd   = State(initialValue: event.endDate)
    }

    private var duration: TimeInterval { event.endDate.timeIntervalSince(event.startDate) }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(loc("Startzeit", "Start time")) {
                    DatePicker("", selection: $newStart, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .onChange(of: newStart) { _, val in
                            newEnd = val.addingTimeInterval(duration)
                        }
                }
                Section(loc("Endzeit", "End time")) {
                    DatePicker("", selection: $newEnd, in: newStart..., displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundStyle(.red).font(SunwakeTypography.caption) }
                }
            }
            .navigationTitle(loc("Termin verschieben", "Reschedule event"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(loc("Abbrechen", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc("Speichern", "Save")) {
                        Task {
                            isSaving = true
                            do {
                                try await calendarService.updateEvent(
                                    identifier: event.id,
                                    newStartDate: newStart,
                                    newEndDate: newEnd,
                                    language: appState.selectedLanguage
                                )
                                HapticFeedback.success()
                                dismiss()
                                onDone()
                            } catch {
                                errorMessage = error.localizedDescription
                                HapticFeedback.error()
                            }
                            isSaving = false
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
    }
}

private extension CalendarEvent {
    var selectedDate: String {
        startDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }
}

// MARK: — Event AI Chat Sheet

struct EventAIChatSheet: View {
    let event: CalendarEvent
    let userNotes: String
    let keywords: String
    @StateObject private var viewModel: EventChatViewModel
    @FocusState private var inputFocused: Bool
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    init(event: CalendarEvent, userNotes: String, keywords: String = "") {
        self.event = event
        self.userNotes = userNotes
        self.keywords = keywords
        _viewModel = StateObject(wrappedValue: EventChatViewModel(event: event, userNotes: userNotes, keywords: keywords))
    }

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Context chip
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Label(event.title, systemImage: "calendar")
                            .font(SunwakeTypography.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: SunwakeRadius.chip, style: .continuous)
                                    .fill(Color(cgColor: event.calendarColor).opacity(0.12))
                            )
                            .foregroundStyle(Color(cgColor: event.calendarColor))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(uiColor: .systemBackground))

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { msg in
                                ChatBubble(message: msg).id(msg.id)
                            }
                            if viewModel.isThinking {
                                ThinkingIndicator()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.count) {
                        if let last = viewModel.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()
                ChatInputBar(
                    text: $viewModel.inputText,
                    isThinking: viewModel.isThinking,
                    focused: $inputFocused
                ) {
                    Task { await viewModel.sendMessage() }
                }
            }
            .navigationTitle(loc("KI-Chat", "AI Chat"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc("Fertig", "Done")) { dismiss() }
                }
            }
            .task { viewModel.setup(language: appState.selectedLanguage) }
        }
    }
}

@MainActor
final class EventChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isThinking = false

    private let aiService = AIService()
    private let event: CalendarEvent
    private let userNotes: String
    private let keywords: String
    private var language: String = "en"

    init(event: CalendarEvent, userNotes: String, keywords: String = "") {
        self.event = event
        self.userNotes = userNotes
        self.keywords = keywords
    }

    private func loc(_ de: String, _ en: String) -> String { language == "de" ? de : en }

    func setup(language: String) {
        self.language = language
        guard messages.isEmpty else { return }
        var parts: [String] = []
        if let notes = event.notes, !notes.isEmpty { parts.append("\(loc("Kalender-Notiz", "Calendar note")): \"\(notes)\"") }
        if !userNotes.isEmpty { parts.append("\(loc("Meine Notiz", "My note")): \"\(userNotes)\"") }
        if !keywords.isEmpty { parts.append("\(loc("Verknüpfte Stichworte", "Linked keywords")): \(keywords)") }
        let context = parts.isEmpty ? "" : " \(loc("Kontext", "Context")): \(parts.joined(separator: " | "))"
        let greeting = loc(
            "Hallo! Ich kenne deinen Termin **\(event.title)**.\(context) Was möchtest du wissen oder besprechen?",
            "Hi! I know about your event **\(event.title)**.\(context) What would you like to know or discuss?"
        )
        messages = [ChatMessage(role: .assistant, text: greeting, timestamp: Date())]
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        messages.append(ChatMessage(role: .user, text: text, timestamp: Date()))
        isThinking = true
        defer { isThinking = false }

        var contextParts = ["\(loc("Termin", "Event")): \(event.title)"]
        if !event.isAllDay {
            let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
            contextParts.append("\(loc("Zeit", "Time")): \(fmt.string(from: event.startDate))–\(fmt.string(from: event.endDate))")
        }
        if let eventLocation = event.location, !eventLocation.isEmpty { contextParts.append("\(loc("Ort", "Location")): \(eventLocation)") }
        if let notes = event.notes, !notes.isEmpty { contextParts.append("\(loc("Kalender-Notiz", "Calendar note")): \(notes)") }
        if !userNotes.isEmpty { contextParts.append("\(loc("Meine Notiz", "My note")): \(userNotes)") }
        if !keywords.isEmpty { contextParts.append("\(loc("Verknüpfte Stichworte/Dateien", "Linked keywords/files")): \(keywords)") }

        let fullQuestion = "[\(contextParts.joined(separator: " | "))] \(text)"
        let ctx = BriefingContext(todayEvents: [], pdfSummaries: [], date: Date())
        let reply = await aiService.answerQuestion(fullQuestion, context: ctx, language: language)
        messages.append(ChatMessage(role: .assistant, text: reply, timestamp: Date()))
    }
}

// MARK: — ViewModel

/// Nächster Tag mit Terminen (Vorschau unter dem Heute-Block, wie im Rundgang).
struct UpcomingDayPreview: Equatable {
    let date: Date
    let events: [CalendarEvent]
}

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var events: [CalendarEvent] = []
    @Published var availableCalendars: [EKCalendar] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var selectedProvider: CalendarProvider? = nil
    @Published var isLoading: Bool = false
    /// Tage (startOfDay) mit mindestens einem Termin — Punkte im Wochen-Grid.
    @Published var eventDays: Set<Date> = []
    /// Nächster zukünftiger Tag mit Terminen (bis 14 Tage voraus).
    @Published var nextDayPreview: UpcomingDayPreview? = nil

    private let calendarService = CalendarService()
    private var dotsRange: (start: Date, end: Date)? = nil

    var availableProviders: [CalendarProvider] {
        let providers = Set(availableCalendars.map { $0.provider })
        return CalendarProvider.allCases.filter { providers.contains($0) }
    }

    // Calendars shown in second-level filter (depends on selected provider)
    var visibleCalendars: [EKCalendar] {
        guard let provider = selectedProvider else { return [] }
        return availableCalendars.filter { $0.provider == provider }
    }

    var filteredEvents: [CalendarEvent] {
        applyFilters(events)
    }

    /// Provider-/Kalender-Pills wirken überall gleich (Tagesliste + Vorschau).
    func applyFilters(_ input: [CalendarEvent]) -> [CalendarEvent] {
        var result = input
        if let provider = selectedProvider {
            result = result.filter { event in
                availableCalendars.first { $0.calendarIdentifier == event.calendarIdentifier }?.provider == provider
            }
        }
        if !selectedCalendarIDs.isEmpty {
            result = result.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        }
        return result
    }

    func setup() async {
        let _ = await calendarService.requestAccess()
        let excluded = BriefingExclusionStore.excludedIDs
        availableCalendars = calendarService.availableCalendars()
            .filter { !excluded.contains($0.calendarIdentifier) }
        await fetchEvents()
    }

    func fetchEvents() async {
        isLoading = true
        defer { isLoading = false }
        await calendarService.fetchEvents(for: selectedDate)
        let excluded = BriefingExclusionStore.excludedIDs
        events = calendarService.todayEvents.filter { !excluded.contains($0.calendarIdentifier) }
        await loadNextDayPreview()
        if let range = dotsRange {
            await loadEventDays(from: range.start, to: range.end)
        }
    }

    /// Termin-Punkte für den im Wochen-Grid sichtbaren Bereich.
    func loadEventDays(from start: Date, to end: Date) async {
        dotsRange = (start, end)
        let excluded = BriefingExclusionStore.excludedIDs
        let cal = Calendar.current
        let rangeEvents = await calendarService.events(from: start, to: end)
            .filter { !excluded.contains($0.calendarIdentifier) }
        eventDays = Set(applyFilters(rangeEvents).map { cal.startOfDay(for: $0.startDate) })
    }

    private func loadNextDayPreview() async {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let horizon = cal.date(byAdding: .day, value: 14, to: tomorrow)!
        let excluded = BriefingExclusionStore.excludedIDs
        let upcoming = await calendarService.events(from: tomorrow, to: horizon)
            .filter { !excluded.contains($0.calendarIdentifier) }

        let grouped = Dictionary(grouping: upcoming) { cal.startOfDay(for: $0.startDate) }
        if let firstDay = grouped.keys.sorted().first, let dayEvents = grouped[firstDay] {
            nextDayPreview = UpcomingDayPreview(date: firstDay, events: dayEvents)
        } else {
            nextDayPreview = nil
        }
    }

    func toggleCalendar(_ id: String) {
        if selectedCalendarIDs.contains(id) {
            selectedCalendarIDs.remove(id)
        } else {
            selectedCalendarIDs.insert(id)
        }
    }
}

// MARK: — CalendarProvider UI helpers

extension CalendarProvider {
    var pillColor: Color {
        switch self {
        case .apple:   return .primary
        case .google:  return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .outlook: return Color(red: 0.0,  green: 0.47, blue: 0.84)
        case .other:   return .secondary
        }
    }
}

// MARK: — Add Event Sheet

struct AddEventSheet: View {
    let defaultDate: Date
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var title = ""
    @State private var isAllDay = false
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var availableCalendars: [EKCalendar] = []
    @State private var selectedCalendarID: String = ""

    private let calendarService = CalendarService()

    /// Picks the German or English string based on the app language.
    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    init(defaultDate: Date, onSave: @escaping () -> Void) {
        self.defaultDate = defaultDate
        self.onSave = onSave
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: defaultDate)
        let hour = cal.component(.hour, from: Date())
        let roundedHour = max(hour, cal.component(.hour, from: dayStart))
        var startComps = cal.dateComponents([.year, .month, .day], from: defaultDate)
        startComps.hour = roundedHour + 1
        startComps.minute = 0
        let start = cal.date(from: startComps) ?? defaultDate
        _startTime = State(initialValue: start)
        _endTime = State(initialValue: cal.date(byAdding: .hour, value: 1, to: start) ?? start)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(loc("Titel", "Title"), text: $title)
                        .autocorrectionDisabled()
                }
                Section {
                    Toggle(loc("Ganztägig", "All day"), isOn: $isAllDay)
                }
                if !isAllDay {
                    Section(loc("Start", "Start")) {
                        DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                    Section(loc("Ende", "End")) {
                        DatePicker("", selection: $endTime, in: startTime..., displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                    }
                } else {
                    Section(loc("Datum", "Date")) {
                        DatePicker("", selection: $startTime, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                }
                if !availableCalendars.isEmpty {
                    Section(loc("Kalender", "Calendar")) {
                        Picker(loc("Kalender", "Calendar"), selection: $selectedCalendarID) {
                            ForEach(availableCalendars, id: \.calendarIdentifier) { cal in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(cgColor: cal.cgColor))
                                        .frame(width: 10, height: 10)
                                    Text(cal.title)
                                }
                                .tag(cal.calendarIdentifier)
                            }
                        }
                    }
                }
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(SunwakeTypography.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(loc("Neuer Termin", "New Event"))
            .navigationBarTitleDisplayMode(.inline)
            .task { loadCalendars() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(loc("Abbrechen", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc("Hinzufügen", "Add")) {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let cal = Calendar.current

        let start: Date
        let end: Date
        if isAllDay {
            start = cal.startOfDay(for: startTime)
            end = cal.date(byAdding: .day, value: 1, to: start)!
        } else {
            start = startTime
            end = endTime > startTime ? endTime : cal.date(byAdding: .hour, value: 1, to: startTime)!
        }

        do {
            try await calendarService.addEvent(title: trimmed, startDate: start, endDate: end, calendarIdentifier: selectedCalendarID.isEmpty ? nil : selectedCalendarID, language: appState.selectedLanguage)
            HapticFeedback.success()
            onSave()
            dismiss()
        } catch {
            HapticFeedback.error()
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func loadCalendars() {
        let store = EKEventStore()
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            availableCalendars = store.calendars(for: .event).sorted { $0.title < $1.title }
            if let defaultCal = store.defaultCalendarForNewEvents {
                selectedCalendarID = defaultCal.calendarIdentifier
            }
        }
    }
}

// MARK: — Date helpers

extension Date {
    var isToday: Bool { Calendar.current.isDateInToday(self) }
}
