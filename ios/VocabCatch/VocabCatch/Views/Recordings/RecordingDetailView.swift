import SwiftUI
import SwiftData

struct RecordingDetailView: View {
    let session: RecordingSession
    @State private var showReview = false
    @State private var extractedPhrases: [ExtractedPhrase] = []
    @State private var isExtracting = false
    @State private var extractionError: String?
    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata
                HStack {
                    Label(formatDuration(session.duration), systemImage: "clock")
                    Spacer()
                    Text(session.createdAt, style: .date)
                    Text(session.createdAt, style: .time)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                // Transcript
                Text(session.rawTranscript)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))

                // Extract button
                if isExtracting {
                    ProgressView("Analyzing with AI...")
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Button {
                        Task { await extractWithLLM() }
                    } label: {
                        Label("Extract Phrases", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if let error = extractionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                // Previously extracted phrases
                if !session.extractedPhrases.isEmpty {
                    Section {
                        ForEach(session.extractedPhrases) { phrase in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(phrase.phrase)
                                    .font(.subheadline.weight(.medium))
                                Text(phrase.translation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Extracted Phrases")
                            .font(.headline)
                            .padding(.top, 8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Recording")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showReview) {
            ReviewListView(phrases: extractedPhrases)
        }
    }

    private func extractWithLLM() async {
        isExtracting = true
        extractionError = nil
        do {
            let phrases = try await ClaudeAPIService.shared.extractPhrases(from: session.rawTranscript)

            // Update session with extracted phrases
            session.extractedPhrases = phrases
            try? context.save()

            extractedPhrases = phrases
            showReview = true
        } catch {
            extractionError = error.localizedDescription
        }
        isExtracting = false
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
