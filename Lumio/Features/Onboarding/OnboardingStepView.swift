import SwiftUI

struct OnboardingStepView: View {
    let step: OnboardingStep
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Spacer().frame(height: 20)
                stepContent
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            WelcomeStepView { viewModel.advance() }
        case .language:
            LanguageStepView(selected: $viewModel.selectedLanguage) { viewModel.advance() }
        case .calendar:
            CalendarStepView(viewModel: viewModel)
        case .notifications:
            NotificationsStepView(viewModel: viewModel)
        case .pdfUpload:
            PDFUploadStepView { viewModel.advance() }
        case .premium:
            PremiumIntroStepView { viewModel.completeOnboarding(appState: appState) }
        }
    }
}

// MARK: — Step: Welcome

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.breathe)

                Text("Lumio")
                    .font(.system(size: 42, weight: .bold, design: .default))
                    .foregroundStyle(.primary)

                Text("Your intelligent morning briefing")
                    .font(LumioTypography.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "calendar", color: .blue, title: "Your day at a glance", subtitle: "All your events, beautifully organized")
                FeatureRow(icon: "doc.text", color: .green, title: "Lecture highlights", subtitle: "Key points from your PDF slides")
                FeatureRow(icon: "waveform", color: .purple, title: "Spoken out loud", subtitle: "Listen while you get ready")
            }
            .padding(.horizontal, 4)

            LumioButton(title: "Get Started", style: .primary, action: onContinue)
        }
    }
}

// MARK: — Step: Language

struct LanguageStepView: View {
    @Binding var selected: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "globe",
                iconColor: .blue,
                title: "Choose your language",
                subtitle: "Lumio speaks both German and English fluently."
            )

            VStack(spacing: 12) {
                LanguageOption(code: "en", name: "English", flag: "🇬🇧", selected: $selected)
                LanguageOption(code: "de", name: "Deutsch", flag: "🇩🇪", selected: $selected)
            }

            LumioButton(title: "Continue", style: .primary, action: onContinue)
        }
    }
}

struct LanguageOption: View {
    let code: String
    let name: String
    let flag: String
    @Binding var selected: String

    var isSelected: Bool { selected == code }

    var body: some View {
        Button {
            withAnimation(.spring(duration: 0.25)) { selected = code }
        } label: {
            HStack(spacing: 16) {
                Text(flag).font(.title2)
                Text(name).font(LumioTypography.body).foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.lumioAccent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.lumioAccent.opacity(0.1) : Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? Color.lumioAccent : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}

// MARK: — Step: Calendar

struct CalendarStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "calendar",
                iconColor: .blue,
                title: "Connect your calendar",
                subtitle: "Lumio reads your calendar to prepare your morning briefing. It never uploads your data."
            )

            VStack(spacing: 12) {
                CalendarProviderButton(
                    name: "Apple Calendar",
                    icon: "applelogo",
                    color: .primary,
                    isLoading: viewModel.isLoading
                ) {
                    Task { await viewModel.connectAppleCalendar() }
                }

                CalendarProviderButton(
                    name: "Google Calendar",
                    icon: "globe",
                    color: .blue,
                    isLoading: false,
                    badge: "Coming soon"
                ) {}

                CalendarProviderButton(
                    name: "Outlook",
                    icon: "envelope.fill",
                    color: .blue,
                    isLoading: false,
                    badge: "Coming soon"
                ) {}
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(LumioTypography.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Skip for now") { viewModel.advance() }
                .font(LumioTypography.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct CalendarProviderButton: View {
    let name: String
    let icon: String
    let color: Color
    let isLoading: Bool
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body.weight(.medium))
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(name)
                    .font(LumioTypography.body)
                    .foregroundStyle(.primary)

                Spacer()

                if let badge {
                    Text(badge)
                        .font(LumioTypography.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.15)))
                } else if isLoading {
                    ProgressView().tint(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(uiColor: .secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .disabled(badge != nil || isLoading)
    }
}

// MARK: — Step: Notifications

struct NotificationsStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "bell.fill",
                iconColor: .orange,
                title: "Wake up to your day",
                subtitle: "Get a morning notification with a preview of your day. Default time: 7:30 AM."
            )

            NotificationPreviewCard()

            LumioButton(
                title: viewModel.isLoading ? "Requesting..." : "Enable notifications",
                style: .primary
            ) {
                Task { await viewModel.requestNotifications() }
            }
            .disabled(viewModel.isLoading)

            Button("Maybe later") { viewModel.advance() }
                .font(LumioTypography.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct NotificationPreviewCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sun.horizon.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Lumio")
                        .font(LumioTypography.caption.weight(.semibold))
                    Spacer()
                    Text("7:30 AM")
                        .font(LumioTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Good morning ☀️")
                    .font(LumioTypography.callout.weight(.semibold))
                Text("09:00 Lecture · 11:30 Study Group · 14:00 Office Hours")
                    .font(LumioTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }
}

// MARK: — Step: PDF Upload

struct PDFUploadStepView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "doc.fill",
                iconColor: .green,
                title: "Upload your lecture slides",
                subtitle: "Add PDFs to get AI-powered summaries in your morning briefing. Everything stays on your device."
            )

            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    FeatureRow(icon: "lock.fill", color: .green, title: "100% private", subtitle: "PDFs never leave your device")
                    Spacer()
                }
                HStack(spacing: 16) {
                    FeatureRow(icon: "icloud.fill", color: .blue, title: "iCloud sync", subtitle: "Available on all your devices")
                    Spacer()
                }
            }

            LumioButton(title: "Continue", style: .primary, action: onContinue)
            Text("You can upload PDFs anytime in the Library tab.")
                .font(LumioTypography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: — Step: Premium Intro

struct PremiumIntroStepView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            StepHeader(
                icon: "star.fill",
                iconColor: .yellow,
                title: "Free & Premium",
                subtitle: "Lumio is free to use. Premium unlocks the full experience."
            )

            VStack(spacing: 8) {
                PremiumComparisonRow(feature: "Calendar integration", freeValue: "1 calendar", premiumValue: "Unlimited")
                PremiumComparisonRow(feature: "PDF library", freeValue: "5 per folder · 20 pages", premiumValue: "Unlimited")
                PremiumComparisonRow(feature: "Text-to-speech", freeValue: "Events only", premiumValue: "Events + PDFs")
                PremiumComparisonRow(feature: "AI Chatbot", freeValue: "—", premiumValue: "✓ Included")
                PremiumComparisonRow(feature: "Widget", freeValue: "—", premiumValue: "✓ Included")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(uiColor: .secondarySystemBackground)))

            VStack(spacing: 10) {
                LumioButton(title: "Start for free", style: .primary, action: onComplete)
                Text("Premium from €2.00/month · Upgrade anytime")
                    .font(LumioTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PremiumComparisonRow: View {
    let feature: String
    let freeValue: String
    let premiumValue: String

    var body: some View {
        HStack {
            Text(feature)
                .font(LumioTypography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(freeValue)
                .font(LumioTypography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .center)

            Text(premiumValue)
                .font(LumioTypography.caption.weight(.medium))
                .foregroundStyle(Color.lumioAccent)
                .frame(width: 100, alignment: .center)
        }
    }
}

// MARK: — Shared sub-components

struct StepHeader: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(iconColor)
                .symbolEffect(.bounce, value: true)

            Text(title)
                .font(LumioTypography.title2)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(LumioTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(LumioTypography.callout.weight(.medium))
                Text(subtitle)
                    .font(LumioTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct LumioButton: View {
    let title: LocalizedStringKey
    let style: ButtonStyle
    let action: () -> Void

    enum ButtonStyle { case primary, secondary }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(LumioTypography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    style == .primary
                        ? AnyShapeStyle(Color.lumioAccent)
                        : AnyShapeStyle(Color(uiColor: .secondarySystemBackground))
                )
                .foregroundStyle(style == .primary ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
