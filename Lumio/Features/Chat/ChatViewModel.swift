import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isThinking: Bool = false

    var language: String = "en"

    private let aiService = AIService()
    private let calendarService = CalendarService()

    func setup(language: String = "en") async {
        self.language = language
        let _ = await calendarService.requestAccess()
        if messages.isEmpty {
            let greetingText = language == "de"
                ? "Hallo! Ich bin dein Lumio-Assistent. Ich kann dir bei deinem Tagesplan helfen, Fragen zu deinen Notizen beantworten oder Termine eintragen. Was kann ich für dich tun?"
                : String(localized: "Hi! I'm your Lumio assistant. I can help you with your schedule, answer questions about your lecture notes, or add events to your calendar. What can I help you with?")
            messages.append(ChatMessage(role: .assistant, text: greetingText, timestamp: Date()))
        }
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, text: text, timestamp: Date()))

        isThinking = true
        defer { isThinking = false }

        await calendarService.fetchTodayEvents()
        let context = BriefingContext(
            todayEvents: calendarService.todayEvents,
            pdfSummaries: [],
            date: Date()
        )

        let response = await aiService.answerQuestion(text, context: context, language: language)
        messages.append(ChatMessage(role: .assistant, text: response, timestamp: Date()))
    }

    func clearHistory(language: String? = nil) {
        messages = []
        let lang = language ?? self.language
        Task { await setup(language: lang) }
    }
}
