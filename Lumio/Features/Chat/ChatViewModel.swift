import SwiftUI
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isThinking: Bool = false

    private let aiService = AIService()
    private let calendarService = CalendarService()

    func setup() async {
        let _ = await calendarService.requestAccess()
        if messages.isEmpty {
            let greeting = ChatMessage(
                role: .assistant,
                text: String(localized: "Hi! I'm your Lumio assistant. I can help you with your schedule, answer questions about your lecture notes, or add events to your calendar. What can I help you with?"),
                timestamp: Date()
            )
            messages.append(greeting)
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

        let response = await aiService.answerQuestion(text, context: context)
        messages.append(ChatMessage(role: .assistant, text: response, timestamp: Date()))
    }

    func clearHistory() {
        messages = []
        Task { await setup() }
    }
}
