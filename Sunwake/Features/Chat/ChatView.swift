import SwiftUI

struct ChatView: View {
    /// true, wenn per Chat-Button als Vollbild-Push geöffnet (mit ✕, ohne Tab-Bar);
    /// false, wenn Chat als Tab konfiguriert ist.
    var isPresentedAsCover: Bool = false

    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private func loc(_ de: String, _ en: String) -> String {
        appState.selectedLanguage == "de" ? de : en
    }

    var body: some View {
        Group {
            if !subscriptionManager.effectivelyPremium {
                NavigationStack {
                    ChatPaywallView()
                        .sunwakePaperScreen()
                        .toolbar {
                            if isPresentedAsCover {
                                ToolbarItem(placement: .topBarTrailing) {
                                    closeButton
                                }
                            }
                        }
                }
            } else {
                chatContent
            }
        }
    }

    private var chatContent: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                                .developerFeedbackOverlay(
                                    isActive: appState.isDeveloperModeActive,
                                    screen: "Chat",
                                    feature: "AI Chatbot",
                                    element: String(message.text.prefix(100))
                                )
                        }
                        if viewModel.isThinking {
                            ThinkingIndicator()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            ChatInputBar(text: $viewModel.inputText, isThinking: viewModel.isThinking, focused: $inputFocused, language: appState.selectedLanguage) {
                HapticFeedback.impact(.light)
                inputFocused = false
                Task { await viewModel.sendMessage() }
            }
            .padding(.bottom, isPresentedAsCover ? 0 : MainTabView.tabBarContentHeight)
        }
        .sunwakeSkyScreen()
        .task { await viewModel.setup(language: appState.selectedLanguage) }
        .onAppear {
            if let pending = appState.pendingBriefingForChat {
                viewModel.injectBriefingContext(pending, language: appState.selectedLanguage)
                appState.pendingBriefingForChat = nil
            }
        }
        .onChange(of: appState.pendingBriefingForChat) { _, pending in
            if let text = pending {
                viewModel.injectBriefingContext(text, language: appState.selectedLanguage)
                appState.pendingBriefingForChat = nil
            }
        }
    }

    // Header: Eyebrow = Datum, Titel „Frag Sunwake" (Clash Display), ✕ rechts.
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                SunwakeEyebrow(
                    text: Date().formatted(.dateTime.weekday(.wide).day().month(.wide)),
                    color: .sunwakeAccentDeep
                )
                Text(loc("Frag Sunwake", "Ask Sunwake"))
                    .font(SunwakeTypography.title)
                    .foregroundStyle(Color.sunwakeInk)
            }

            Spacer()

            HStack(spacing: 8) {
                if appState.isDeveloperModeActive {
                    DeveloperFeedbackButton(screen: "Chat", feature: "AI Chatbot", element: "Header")
                }
                Button(loc("Löschen", "Clear")) {
                    viewModel.clearHistory(language: appState.selectedLanguage)
                }
                .font(SunwakeTypography.caption)
                .foregroundStyle(Color.sunwakeInkSecondary)

                if isPresentedAsCover {
                    closeButton
                }
            }
            .padding(.top, 4)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.sunwakeInkSecondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loc("Schließen", "Close"))
    }
}

// MARK: — Message bubble

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let text: String
    let timestamp: Date

    enum MessageRole { case user, assistant }
}

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if isUser {
                    // Eigene Blase: Amber-Verlauf, Radius 16/16/5/16
                    Text(message.text)
                        .font(SunwakeTypography.callout)
                        .foregroundStyle(Color.sunwakeOnAccent)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 16, bottomLeadingRadius: 16,
                                bottomTrailingRadius: 5, topTrailingRadius: 16,
                                style: .continuous
                            )
                            .fill(LinearGradient(
                                colors: [.sunwakeAccentBright, .sunwakeAccent],
                                startPoint: .top, endPoint: .bottom
                            ))
                        }
                } else {
                    // Assistenz-Blase: liegende Lichtkante-Karte, Radius 16/16/16/5
                    Text(message.text)
                        .font(SunwakeTypography.callout)
                        .foregroundStyle(Color.sunwakeInkSecondary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .background {
                            let shape = UnevenRoundedRectangle(
                                topLeadingRadius: 16, bottomLeadingRadius: 5,
                                bottomTrailingRadius: 16, topTrailingRadius: 16,
                                style: .continuous
                            )
                            shape
                                .fill(LinearGradient(
                                    colors: [.sunwakeCardTop, .sunwakeCardBottom],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                .overlay {
                                    shape.strokeBorder(
                                        LinearGradient(
                                            stops: [
                                                .init(color: .sunwakeEdgeLight, location: 0),
                                                .init(color: .clear, location: 0.4),
                                            ],
                                            startPoint: .top, endPoint: .bottom
                                        ),
                                        lineWidth: 1
                                    )
                                }
                        }
                }

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(SunwakeTypography.caption2)
                    .foregroundStyle(Color.sunwakeInkTertiary)
                    .padding(.horizontal, 4)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

struct ThinkingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.sunwakeInkTertiary)
                        .frame(width: 6, height: 6)
                        .offset(y: phase == Double(i) ? -4 : 0)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .sunwakeCard()
            Spacer()
        }
        .onAppear { phase = 1 }
    }
}

// MARK: — Input bar (3f-Mulde + Bogen-Senden, Ort ④)

struct ChatInputBar: View {
    @Binding var text: String
    let isThinking: Bool
    var focused: FocusState<Bool>.Binding
    var language: String = "en"
    let onSend: () -> Void

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        HStack(spacing: 10) {
            TextField(language == "de" ? "Nachricht…" : "Message…", text: $text, axis: .vertical)
                .font(SunwakeTypography.callout)
                .foregroundStyle(Color.sunwakeInk)
                .focused(focused)
                .lineLimit(1...5)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .sunwakeWell()

            Button(action: onSend) {
                SunArcButtonLabel(width: 38, height: 25, bottomRadius: 8, systemImage: "arrow.up", iconSize: 12)
                    .opacity(isEmpty || isThinking ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isEmpty || isThinking)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: — Paywall for Chat

struct ChatPaywallView: View {
    var body: some View {
        ContentUnavailableView {
            Label("AI Chat is Premium", systemImage: "bubble.left.and.text.bubble.right")
        } description: {
            Text("Ask your AI assistant about your schedule, lecture notes, or anything on your mind. Available with Sunwake Premium.")
        } actions: {
            NavigationLink(destination: PaywallView()) {
                Text("Unlock Premium")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.sunwakeAccent)
        }
    }
}
