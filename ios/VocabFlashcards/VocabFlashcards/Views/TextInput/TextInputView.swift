import SwiftUI
import SwiftData

struct TextInputView: View {
    @State private var inputText = ""
    @State private var isExtracting = false
    @State private var extractionError: String?
    @State private var extractedPhrases: [ExtractedPhrase] = []
    @State private var showReview = false
    @Environment(\.modelContext) private var context

    private var trimmedText: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Text editor
                TextEditor(text: $inputText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
                    .frame(minHeight: 200)
                    .overlay(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text("Paste or type English text here…")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }

                // Word count
                if !trimmedText.isEmpty {
                    Text("\(trimmedText.split(separator: " ").count) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Action buttons
                if isExtracting {
                    ProgressView("Analyzing with AI...")
                        .padding()
                } else {
                    HStack(spacing: 12) {
                        Button {
                            inputText = ""
                            extractionError = nil
                        } label: {
                            Label("Clear", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(inputText.isEmpty)

                        if UIPasteboard.general.hasStrings {
                            Button {
                                if let text = UIPasteboard.general.string {
                                    inputText = text
                                }
                            } label: {
                                Label("Paste", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }

                        Button {
                            Task { await extractPhrases() }
                        } label: {
                            Label("Extract", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(trimmedText.isEmpty)
                    }
                }

                if let error = extractionError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Text Input")
            .navigationDestination(isPresented: $showReview) {
                ReviewListView(phrases: extractedPhrases)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
            }
        }
    }

    private func extractPhrases() async {
        guard !trimmedText.isEmpty else { return }
        isExtracting = true
        extractionError = nil

        do {
            let phrases = try await LLMService.shared.extractPhrases(from: inputText)

            // Save as recording session for history
            let session = RecordingSession(
                rawTranscript: inputText,
                extractedPhrases: phrases
            )
            context.insert(session)
            do {
                try context.save()
            } catch {
                print("[TextInputView] Failed to save session: \(error)")
            }

            extractedPhrases = phrases
            showReview = true
        } catch {
            extractionError = error.localizedDescription
        }
        isExtracting = false
    }
}
