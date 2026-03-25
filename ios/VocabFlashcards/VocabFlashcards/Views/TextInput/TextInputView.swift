import SwiftUI
import SwiftData

private enum InputMode: String, CaseIterable {
    case extract = "Extract"
    case generate = "Generate"
}

struct TextInputView: View {
    @State private var mode: InputMode = .extract
    @State private var selectedLanguage: SourceLanguage = .english
    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var extractedPhrases: [ExtractedPhrase] = []
    @State private var showReview = false
    @State private var cardCount = 5
    @Environment(\.modelContext) private var context

    @State private var wordCount = 0

    private var hasText: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Mode picker
                Picker("Mode", selection: $mode) {
                    ForEach(InputMode.allCases, id: \.self) { m in
                        Text(m.rawValue)
                    }
                }
                .pickerStyle(.segmented)

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
                .disabled(isProcessing)

                if mode == .extract {
                    extractModeContent
                } else {
                    generateModeContent
                }

                // Progress / Error
                if isProcessing {
                    ProgressView(mode == .extract ? "Analyzing with AI..." : "Generating cards...")
                        .padding()
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()
            }
            .padding()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(mode == .extract ? "Text Input" : "Generate Cards")
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

    // MARK: - Extract Mode

    @ViewBuilder
    private var extractModeContent: some View {
        TextEditor(text: $inputText)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
            .frame(minHeight: 200)
            .overlay(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text(selectedLanguage.textInputPlaceholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: inputText) {
                wordCount = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    .split(separator: " ").count
            }

        if wordCount > 0 {
            Text("\(wordCount) words")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if !isProcessing {
            HStack(spacing: 12) {
                Button {
                    inputText = ""
                    errorMessage = nil
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
                .disabled(!hasText)
            }
        }
    }

    // MARK: - Generate Mode

    @ViewBuilder
    private var generateModeContent: some View {
        TextField("Describe what cards to generate…", text: $inputText, axis: .vertical)
            .font(.body)
            .lineLimit(3...8)
            .padding(12)
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))

        Text(selectedLanguage.generateExample)
            .font(.caption)
            .foregroundStyle(.secondary)

        Stepper("Cards: \(cardCount)", value: $cardCount, in: 1...10)
            .padding(.horizontal, 4)

        if !isProcessing {
            HStack(spacing: 12) {
                Button {
                    inputText = ""
                    errorMessage = nil
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(inputText.isEmpty)

                Button {
                    Task { await generateCards() }
                } label: {
                    Label("Generate", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!hasText)
            }
        }
    }

    // MARK: - Actions

    private func extractPhrases() async {
        guard hasText else { return }
        isProcessing = true
        errorMessage = nil

        do {
            let phrases = try await LLMService.shared.extractPhrases(from: inputText, language: selectedLanguage)

            let session = RecordingSession(
                rawTranscript: inputText,
                extractedPhrases: phrases
            )
            context.insert(session)
            try? context.save()

            extractedPhrases = phrases
            showReview = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }

    private func generateCards() async {
        guard hasText else { return }
        isProcessing = true
        errorMessage = nil

        do {
            let phrases = try await LLMService.shared.generateCards(prompt: inputText, count: cardCount, language: selectedLanguage)
            extractedPhrases = phrases
            showReview = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isProcessing = false
    }
}
