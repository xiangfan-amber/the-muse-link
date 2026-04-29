//
//  SpeechPlayer.swift
//  The Muse-Link
//
//  Tiny wrapper around AVSpeechSynthesizer used by the Audio Guide button on
//  curator replies. One speaker is shared across the chat so a new "Listen"
//  tap interrupts whatever is currently being read.
//

import Foundation
import Combine
import AVFoundation

@MainActor
final class SpeechPlayer: NSObject, ObservableObject {
    static let shared = SpeechPlayer()

    @Published private(set) var nowSpeakingID: String?
    @Published private(set) var isPaused: Bool = false

    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    func toggle(_ text: String, id: String) {
        if nowSpeakingID == id {
            if isPaused {
                synth.continueSpeaking()
                isPaused = false
            } else if synth.isSpeaking {
                synth.pauseSpeaking(at: .word)
                isPaused = true
            } else {
                speak(text, id: id)
            }
        } else {
            stop()
            speak(text, id: id)
        }
    }

    func stop() {
        if synth.isSpeaking || synth.isPaused {
            synth.stopSpeaking(at: .immediate)
        }
        nowSpeakingID = nil
        isPaused = false
    }

    private func speak(_ text: String, id: String) {
        let utterance = AVSpeechUtterance(string: text)
        // Slightly slower than default; calmer for a museum context.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.05
        // Pick a "Premium" or "Enhanced" voice when available; fall back to default.
        if let v = preferredVoice() {
            utterance.voice = v
        }
        nowSpeakingID = id
        isPaused = false
        synth.speak(utterance)
    }

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        let language = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        // Prefer enhanced English voices; fallback to system default.
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { v in
            v.language.hasPrefix("en") && (v.quality == .enhanced || v.quality == .premium)
        }
        if let exact = candidates.first(where: { $0.language.hasPrefix(language.prefix(2)) }) {
            return exact
        }
        return candidates.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

extension SpeechPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.nowSpeakingID = nil
            self.isPaused = false
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.nowSpeakingID = nil
            self.isPaused = false
        }
    }
}
