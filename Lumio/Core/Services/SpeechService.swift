import AVFoundation
import MediaPlayer
import SwiftUI
import ActivityKit

@MainActor
final class SpeechService: NSObject, ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var currentItemTitle: String = ""
    @Published private(set) var progress: Double = 0
    @Published private(set) var queue: [SpeechItem] = []
    @Published private(set) var currentIndex: Int = 0

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var lastProgressUpdate: Double = -1
    private let liveActivityService = LiveActivityService()

    override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
        setupRemoteCommandCenter()
    }

    func speak(_ items: [SpeechItem], accentColorHex: String = "FF9500") {
        guard !items.isEmpty else { return }
        queue = items
        currentIndex = 0
        speakCurrent()
        // Start Dynamic Island
        liveActivityService.startActivity(
            totalEvents: items.count,
            firstEvent: items[0].title,
            firstTime: "",
            accentColorHex: accentColorHex
        )
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
        isPlaying = false
        guard currentIndex < queue.count else { return }
        let title = queue[currentIndex].title
        let next = currentIndex + 1 < queue.count ? queue[currentIndex + 1].title : nil
        Task {
            await liveActivityService.update(
                currentTitle: title,
                currentTime: "",
                nextTitle: next,
                nextTime: nil as String?,
                isPlaying: false,
                progress: progress,
                index: currentIndex
            )
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else {
            speakCurrent()
        }
        isPaused = false
        isPlaying = true
        guard currentIndex < queue.count else { return }
        let title = queue[currentIndex].title
        let next: String? = currentIndex + 1 < queue.count ? queue[currentIndex + 1].title : nil
        Task {
            await liveActivityService.update(
                currentTitle: title,
                currentTime: "",
                nextTitle: next,
                nextTime: nil as String?,
                isPlaying: true,
                progress: progress,
                index: currentIndex
            )
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        currentItemTitle = ""
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        Task { await liveActivityService.stop() }
    }

    func skipForward() {
        synthesizer.stopSpeaking(at: .immediate)
        guard currentIndex + 1 < queue.count else {
            stop()
            return
        }
        currentIndex += 1
        speakCurrent()
    }

    func skipBackward() {
        synthesizer.stopSpeaking(at: .immediate)
        guard currentIndex > 0 else {
            speakCurrent()
            return
        }
        currentIndex -= 1
        speakCurrent()
    }

    private func speakCurrent() {
        guard currentIndex < queue.count else {
            isPlaying = false
            return
        }
        let item = queue[currentIndex]
        currentItemTitle = item.title

        // Activate audio session right before each utterance so the route is fresh
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        let utterance = AVSpeechUtterance(string: item.text)
        utterance.voice = bestVoice(for: item.language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        currentUtterance = utterance
        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
        updateNowPlayingInfo()
    }

    // Picks the best natural-sounding downloaded voice for the given language code.
    // Excludes old TTS-bundle Siri voices and novelty voices; prioritises Eloquence voices.
    private func bestVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        let prefix = languageCode.prefix(2).lowercased()
        let all = AVSpeechSynthesisVoice.speechVoices()

        // Filter: richtige Sprache, keine alten TTS-Bundle-Siri-Stimmen, keine Novelty-Stimmen
        let matching = all.filter { voice in
            voice.language.lowercased().hasPrefix(prefix) &&
            !voice.identifier.lowercased().contains("com.apple.ttsbundle.siri") &&
            !voice.identifier.lowercased().contains("novelty")
        }

        // Sorting: Eloquence-Stimmen (com.apple.eloquence) immer zuerst, dann nach Quality-Level
        let sorted = matching.sorted { lhs, rhs in
            let lEloquence = lhs.identifier.lowercased().contains("eloquence")
            let rEloquence = rhs.identifier.lowercased().contains("eloquence")
            if lEloquence != rEloquence { return lEloquence }
            if lhs.quality.rawValue != rhs.quality.rawValue {
                return lhs.quality.rawValue > rhs.quality.rawValue
            }
            return lhs.gender == .female && rhs.gender != .female
        }
        return sorted.first ?? AVSpeechSynthesisVoice(language: languageCode)
    }

    private func setupAudioSession() {
        do {
            // .playback ignores the silent switch; no .mixWithOthers so we own the audio route
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.pause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.skipForward() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in self.skipBackward() }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard currentIndex < queue.count else { return }
        let item = queue[currentIndex]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: "Lumio",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.currentIndex + 1 < self.queue.count {
                self.currentIndex += 1
                self.speakCurrent()
                let next = self.currentIndex + 1 < self.queue.count ? self.queue[self.currentIndex + 1].title : nil
                await self.liveActivityService.update(
                    currentTitle: self.queue[self.currentIndex].title,
                    currentTime: "",
                    nextTitle: next,
                    nextTime: nil,
                    isPlaying: true,
                    progress: Double(self.currentIndex) / Double(self.queue.count),
                    index: self.currentIndex
                )
            } else {
                self.isPlaying = false
                self.currentItemTitle = ""
                await self.liveActivityService.stop()
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let total = Double(utterance.speechString.count)
        guard total > 0 else { return }
        let newProgress = Double(characterRange.location) / total
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard abs(newProgress - self.lastProgressUpdate) >= 0.02 else { return }
            self.lastProgressUpdate = newProgress
            self.progress = newProgress
        }
    }
}

struct SpeechItem: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let language: String
}
