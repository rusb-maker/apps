import SwiftUI

struct RecordingView: View {
    @State private var viewModel = RecorderViewModel()
    @State private var showReview = false
    @State private var extractedPhrases: [ExtractedPhrase] = []
    @State private var permissionsGranted = false

    private let nlpProcessor = NLPProcessor()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Waveform visualization
                WaveformView(level: viewModel.audioLevel, isRecording: viewModel.isRecording)
                    .frame(height: 100)
                    .padding(.horizontal)

                // Duration
                if viewModel.isRecording || viewModel.recordingDuration > 0 {
                    Text(formatDuration(viewModel.recordingDuration))
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
                .disabled(!permissionsGranted)

                // Extract button
                if !viewModel.isRecording && !viewModel.transcript.isEmpty {
                    Button("Extract Phrases") {
                        extractedPhrases = nlpProcessor.extractPhrases(from: viewModel.transcript)
                        showReview = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if let error = viewModel.errorMessage {
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
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
