import Foundation
import AVFoundation
import VocablyServices

// Live text-to-speech (HANDOFF §7). Wraps AVSpeechSynthesizer behind the SpeechService
// protocol so Word Detail can pronounce a term in the deck's language.
final class LiveSpeechService: SpeechService, @unchecked Sendable {
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String, language: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.bcp47(language))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        synth.speak(utterance)
    }

    /// Map a bare ISO code ("es") to a voice locale ("es-ES").
    static func bcp47(_ code: String) -> String {
        if code.contains("-") { return code }
        let map = ["es": "es-ES", "fr": "fr-FR", "de": "de-DE", "it": "it-IT",
                   "ja": "ja-JP", "pt": "pt-PT", "en": "en-US", "zh": "zh-CN", "ru": "ru-RU"]
        return map[code] ?? code
    }
}
