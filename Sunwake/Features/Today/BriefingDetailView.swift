import SwiftUI

// Das frühere BriefingDetailView-Sheet ist durch den in situ aufklappbaren
// Briefing-Banner ersetzt (BriefingBannerView.swift) — alle Funktionen
// (Transformations-Chips, Termin-/Erinnerungs-Links, Vorlesen, „An Chat")
// leben dort weiter. Hier verbleibt nur das Erinnerungs-Detail-Sheet.

// MARK: — Reminder Detail Sheet

struct ReminderDetailSheet: View {
    let reminder: ReminderItem
    let accentColor: Color
    let language: String
    @Environment(\.dismiss) private var dismiss

    private func loc(_ de: String, _ en: String) -> String { language == "de" ? de : en }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .stroke(Color.sunwakeInkTertiary, lineWidth: 1.5)
                                .frame(width: 28, height: 28)
                            if !reminder.priorityLabel.isEmpty {
                                Text(reminder.priorityLabel)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color.sunwakeAccentDeep)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reminder.title)
                                .font(SunwakeTypography.listTitle)
                            if !reminder.priorityLabel.isEmpty {
                                Text(reminder.priorityLabel + " " + loc("Priorität", "Priority"))
                                    .font(SunwakeTypography.caption)
                                    .foregroundStyle(Color.sunwakeAccentDeep)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let due = reminder.dueDate {
                    Section(loc("Fälligkeit", "Due date")) {
                        Label(due.formatted(.dateTime.day().month().hour().minute()),
                              systemImage: "clock")
                    }
                }

                if let notes = reminder.notes, !notes.isEmpty {
                    Section(loc("Notizen", "Notes")) {
                        Text(notes)
                            .font(SunwakeTypography.body)
                            .foregroundStyle(Color.sunwakeInkSecondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .sunwakePaperScreen()
            .navigationTitle(loc("Erinnerung", "Reminder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc("Fertig", "Done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.45)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(SunwakeRadius.sheet)
    }
}
