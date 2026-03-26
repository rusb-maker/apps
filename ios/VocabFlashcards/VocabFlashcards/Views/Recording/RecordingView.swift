import SwiftUI
import SwiftData

struct RecordingView: View {
    @State private var viewModel = RecorderViewModel()
    @State private var selectedLanguage: SourceLanguage = .english
    @State private var showReview = false
    @State private var extractedPhrases: [ExtractedPhrase] = []
    @State private var permissionsGranted = false
    @State private var isExtracting = false
    @State private var extractionError: String?
    @State private var showSavedConfirmation = false
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Language picker
                HStack {
                    Picker("Language", selection: $selectedLanguage) {
                        ForEach(SourceLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    .font(.subheadline)
                    Spacer()
                }
                .padding(.horizontal)
                .disabled(viewModel.isRecording || isExtracting)
                .onChange(of: selectedLanguage) {
                    viewModel.language = selectedLanguage
                }

                Spacer()

                // Waveform visualization
                WaveformView(level: viewModel.audioLevel, isRecording: viewModel.isRecording)
                    .frame(height: 100)
                    .padding(.horizontal)

                // Duration
                if viewModel.isRecording || viewModel.recordingDuration > 0 {
                    Text(viewModel.recordingDuration.formattedDuration)
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                // Transcript preview
                if !viewModel.transcript.isEmpty {
                    ScrollView {
                        Text(viewModel.transcript)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }

                Spacer()

                // Record button
                Button {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        do {
                            try viewModel.startRecording()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Circle()
                        .fill(viewModel.isRecording ? .red : .blue)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                }
                .disabled(!permissionsGranted || isExtracting)

                // Action buttons
                if !viewModel.isRecording && !viewModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if isExtracting {
                        ProgressView("Analyzing with AI...")
                            .padding()
                    } else {
                        HStack(spacing: 16) {
                            Button {
                                saveRecording()
                            } label: {
                                Label("Save", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)

                            Button("Extract Phrases") {
                                Task {
                                    await extractWithLLM()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                }

                if let error = extractionError ?? viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Record")
            .navigationDestination(isPresented: $showReview) {
                ReviewListView(phrases: extractedPhrases)
            }
            .task {
                permissionsGranted = await viewModel.requestPermissions()
            }
            .overlay {
                if showSavedConfirmation {
                    savedConfirmationOverlay
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: showSavedConfirmation)
        }
    }

    private var savedConfirmationOverlay: some View {
        VStack {
            Text("Recording saved")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.green, in: Capsule())
                .foregroundStyle(.white)
                .padding(.top, 8)
            Spacer()
        }
    }

    private func saveRecording() {
        let trimmed = viewModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let session = RecordingSession(
            rawTranscript: viewModel.transcript,
            duration: viewModel.recordingDuration
        )
        context.insert(session)
        do {
            try context.save()
        } catch {
            print("[RecordingView] Failed to save recording: \(error)")
        }

        viewModel.transcript = ""
        viewModel.recordingDuration = 0

        showSavedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            showSavedConfirmation = false
        }
    }

    @MainActor private func extractWithLLM() async {
        let trimmed = viewModel.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isExtracting = true
        extractionError = nil
        do {
            let phrases = try await LLMService.shared.extractPhrases(from: viewModel.transcript, language: selectedLanguage)

            // Save recording session with extracted phrases
            let session = RecordingSession(
                rawTranscript: viewModel.transcript,
                extractedPhrases: phrases,
                duration: viewModel.recordingDuration
            )
            context.insert(session)
            do {
                try context.save()
            } catch {
                print("[RecordingView] Failed to save session: \(error)")
            }

            extractedPhrases = phrases
            showReview = true
        } catch {
            extractionError = error.localizedDescription
        }
        isExtracting = false
    }

}
