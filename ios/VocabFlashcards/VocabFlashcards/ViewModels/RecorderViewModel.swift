import AVFoundation
import Speech

@MainActor
@Observable
class RecorderViewModel {
    var isRecording = false
    var transcript = ""
    var audioLevel: Float = 0.0
    var errorMessage: String?
    var recordingDuration: TimeInterval = 0

    var language: SourceLanguage = .english {
        didSet {
            guard language != oldValue else { return }
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language.speechLocaleIdentifier))
        }
    }

    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private var isStopping = false

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: language.speechLocaleIdentifier))
    }

    func requestPermissions() async -> Bool {
        let micPermission = await AVAudioApplication.requestRecordPermission()

        let speechPermission = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }

        return micPermission && speechPermission
    }

    func startRecording() throws {
        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""
        errorMessage = nil
        isStopping = false

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self, !self.isStopping else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if let error, (error as NSError).domain == "kAFAssistantErrorDomain" && (error as NSError).code != 1101 {
                    self.errorMessage = error.localizedDescription
                }
                if result?.isFinal ?? false {
                    self.stopRecording()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            let level = Self.calculateRMS(buffer: buffer)
            Task { @MainActor [weak self] in
                self?.audioLevel = level
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    func stopRecording() {
        guard isRecording, !isStopping else { return }
        isStopping = true

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        durationTimer?.invalidate()
        durationTimer = nil

        if let start = recordingStartTime {
            recordingDuration = Date().timeIntervalSince(start)
        }

        isRecording = false
        audioLevel = 0
    }

    private nonisolated static func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frameCount {
            sum += data[i] * data[i]
        }
        return sqrt(sum / Float(frameCount))
    }
}
