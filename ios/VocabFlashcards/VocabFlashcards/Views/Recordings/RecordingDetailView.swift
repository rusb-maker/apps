import SwiftUI
import SwiftData

struct RecordingDetailView: View {
    @Bindable var session: RecordingSession
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
                    Label(session.duration.formattedDuration, systemImage: "clock")
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
                    .disabled(session.rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                                HStack {
                                    Text(phrase.phrase)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    if let level = phrase.cefrLevel {
                                        Text(level)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(cefrColor(level).opacity(0.2))
                                            .foregroundStyle(cefrColor(level))
                                            .clipShape(Capsule())
                                    }
                                }
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

    @MainActor private func extractWithLLM() async {
        isExtracting = true
        extractionError = nil
        do {
            let phrases = try await LLMService.shared.extractPhrases(from: session.rawTranscript)

            // Update session with extracted phrases
            session.extractedPhrases = phrases
            do {
                try context.save()
            } catch {
                print("[RecordingDetailView] Failed to save phrases: \(error)")
            }

            extractedPhrases = phrases
            showReview = true
        } catch {
            extractionError = error.localizedDescription
        }
        isExtracting = false
    }

    private func cefrColor(_ level: String) -> Color {
        switch level.uppercased() {
        case "C2": .purple
        case "C1": .red
        case "B2": .orange
        default: .blue
        }
    }

}
