import AVFoundation

final class SpanishTTS: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = SpanishTTS()

    private let synthesizer = AVSpeechSynthesizer()
    private(set) var selectedVoice: AVSpeechSynthesisVoice?
    private(set) var voiceQualityName: String = "нет"
    private var audioSessionConfigured = false

    override init() {
        super.init()
        synthesizer.delegate = self
        selectBestVoice()
    }

    // MARK: - Public

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        configureAudioSession()
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
        utterance.pitchMultiplier = 1.05
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    private(set) var currentLanguage: String = "es"

    /// Re-scan voices (call after user downloads new voices)
    func refreshVoice() {
        selectBestVoice()
    }

    /// Switch TTS language (es-ES or en-GB)
    func switchLanguage(_ language: AppLanguage) {
        currentLanguage = language == .english ? "en" : "es"
        selectBestVoice()
    }

    /// Whether a premium or enhanced voice is available
    var hasPremiumVoice: Bool {
        guard let v = selectedVoice else { return false }
        return v.quality == .premium || v.quality == .enhanced
    }

    /// List available voices for current language
    var availableVoices: [(name: String, quality: String, identifier: String)] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(currentLanguage) }
            .sorted { ($0.quality.rawValue, $0.name) > ($1.quality.rawValue, $1.name) }
            .map { voice in
                let q: String
                switch voice.quality {
                case .premium: q = "Premium"
                case .enhanced: q = "Enhanced"
                default: q = "Default"
                }
                return (name: voice.name, quality: q, identifier: voice.identifier)
            }
    }

    // MARK: - Private

    private func selectBestVoice() {
        let langPrefix = currentLanguage
        let preferredFull = langPrefix == "en" ? "en-GB" : "es-ES"

        let allVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(langPrefix) }

        // Strictly prefer preferred locale first
        let preferred = allVoices.filter { $0.language == preferredFull }
        let other = allVoices.filter { $0.language != preferredFull }

        // Within each group: premium > enhanced > default
        let ranked = (preferred.sorted { $0.quality.rawValue > $1.quality.rawValue })
            + (other.sorted { $0.quality.rawValue > $1.quality.rawValue })

        selectedVoice = ranked.first

        if let v = selectedVoice {
            switch v.quality {
            case .premium: voiceQualityName = "Premium"
            case .enhanced: voiceQualityName = "Enhanced"
            default: voiceQualityName = "Default"
            }
        } else {
            // Fallback
            selectedVoice = AVSpeechSynthesisVoice(language: "es-ES")
            voiceQualityName = "Default"
        }
    }

    private func configureAudioSession() {
        guard !audioSessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            audioSessionConfigured = true
        } catch {
            print("Audio session error: \(error)")
        }
    }
}
