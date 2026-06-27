import Foundation
import SwiftUI

// Apple Foundation Models is conditionally available on iPhone 15 Pro+ / iPhone 16+
// We use availability checks and graceful fallback throughout.

enum AICapabilityStatus {
    case available
    case deviceNotSupported
    case modelNotDownloaded
    case unknown

    var isAvailable: Bool { self == .available }

    var userMessage: LocalizedStringKey {
        switch self {
        case .available:
            return "AI features are available on this device."
        case .deviceNotSupported:
            return "AI features require iPhone 15 Pro or newer (or any iPhone 16/17). Your other Lumio features work perfectly without it."
        case .modelNotDownloaded:
            return "The AI model is downloading. Check back in a few minutes."
        case .unknown:
            return "AI availability could not be determined."
        }
    }
}

@MainActor
final class AIService: ObservableObject {
    @Published private(set) var capabilityStatus: AICapabilityStatus = .unknown
    @Published private(set) var isGenerating: Bool = false

    init() {
        Task { await checkCapability() }
    }

    func checkCapability() async {
        // Foundation Models availability check
        // Uses compile-time and runtime availability
        if #available(iOS 26.0, *) {
            capabilityStatus = await detectFoundationModelsAvailability()
        } else {
            capabilityStatus = .deviceNotSupported
        }
    }

    // Returns a summary of the briefing text using Foundation Models if available,
    // or a plain text fallback
    func summarizeBriefing(events: [CalendarEvent], pdfTexts: [String]) async -> String {
        guard capabilityStatus == .available else {
            return buildFallbackSummary(events: events)
        }
        if #available(iOS 26.0, *) {
            return await generateAISummary(events: events, pdfTexts: pdfTexts)
        }
        return buildFallbackSummary(events: events)
    }

    func answerQuestion(_ question: String, context: BriefingContext) async -> String {
        guard capabilityStatus == .available else {
            return String(localized: "AI chat requires iPhone 15 Pro or newer.")
        }
        if #available(iOS 26.0, *) {
            return await generateAIAnswer(question: question, context: context)
        }
        return String(localized: "AI chat is not available on this device.")
    }

    // MARK: — Private

    @available(iOS 26.0, *)
    private func detectFoundationModelsAvailability() async -> AICapabilityStatus {
        // Apple Foundation Models framework availability detection
        // The actual import and usage is wrapped here to avoid compile errors on older SDKs
        // For now we check device capability via a known approach
        let processInfo = ProcessInfo.processInfo
        let isSimulator = processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
        if isSimulator {
            return .deviceNotSupported
        }
        // Real device check: Foundation Models available on A17 Pro+ (iPhone 15 Pro) and A18+ (iPhone 16+)
        // We attempt to check via the framework's availability at runtime
        return checkFoundationModelsFramework()
    }

    private func checkFoundationModelsFramework() -> AICapabilityStatus {
        // Dynamic check: try to load the FoundationModels framework class
        if NSClassFromString("FoundationModels.LanguageModel") != nil ||
           NSClassFromString("_FoundationModels.LanguageModel") != nil {
            return .available
        }
        // Fallback: check by chip generation via supported feature
        return .deviceNotSupported
    }

    @available(iOS 26.0, *)
    private func generateAISummary(events: [CalendarEvent], pdfTexts: [String]) async -> String {
        isGenerating = true
        defer { isGenerating = false }
        // Foundation Models integration will be wired here when the framework API is finalized
        // Currently returns an intelligent rule-based summary as placeholder
        return buildEnhancedSummary(events: events, pdfTexts: pdfTexts)
    }

    @available(iOS 26.0, *)
    private func generateAIAnswer(question: String, context: BriefingContext) async -> String {
        isGenerating = true
        defer { isGenerating = false }
        return buildRuleBasedAnswer(question: question, context: context)
    }

    private func buildFallbackSummary(events: [CalendarEvent]) -> String {
        guard !events.isEmpty else {
            return String(localized: "You have a clear day today. Enjoy the focus time.")
        }
        let count = events.count
        let first = events.first!
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return String(localized: "You have \(count) event(s) today. First up: \(first.title) at \(formatter.string(from: first.startDate)).")
    }

    private func buildEnhancedSummary(events: [CalendarEvent], pdfTexts: [String]) -> String {
        var parts: [String] = []
        if !events.isEmpty {
            parts.append(buildFallbackSummary(events: events))
        }
        if !pdfTexts.isEmpty {
            parts.append(String(localized: "You have \(pdfTexts.count) lecture document(s) with recent content."))
        }
        return parts.joined(separator: " ")
    }

    private func buildRuleBasedAnswer(question: String, context: BriefingContext) -> String {
        let q = question.lowercased()
        if q.contains("today") || q.contains("heute") {
            return buildFallbackSummary(events: context.todayEvents)
        }
        return String(localized: "I can help you with questions about your calendar and lecture notes. Try asking about today's events.")
    }
}

struct BriefingContext {
    let todayEvents: [CalendarEvent]
    let pdfSummaries: [String]
    let date: Date
}
