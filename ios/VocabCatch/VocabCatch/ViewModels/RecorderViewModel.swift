import AVFoundation
import Speech

@Observable
class RecorderViewModel {
    var isRecording = false
    var transcript = ""
    var audioLevel: Float = 0.0
    var errorMessage: String?
    var recordingDuration: TimeInterval = 0

    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?

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

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result {
                self?.transcript = result.bestTranscription.formattedString
            }
            if let error, (error as NSError).domain == "kAFAssistantErrorDomain" && (error as NSError).code != 1101 {
                self?.errorMessage = error.localizedDescription
            }
            if result?.isFinal ?? false {
                self?.stopRecording()
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            self?.updateAudioLevel(buffer: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        recordingStartTime = Date()
        recordingDuration = 0

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            self.recordingDuration = Date().timeIntervalSince(start)
        }
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
        durationTimer?.invalidate()
        durationTimer = nil

        if let start = recordingStartTime {
            recordingDuration = Date().timeIntervalSince(start)
        }
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        var sum: Float = 0
        for i in 0..<frameCount {
            sum += data[i] * data[i]
        }
        let rms = sqrt(sum / Float(frameCount))
        DispatchQueue.main.async {
            self.audioLevel = rms
        }
    }
}
