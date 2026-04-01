import SwiftUI
import SwiftData

struct CustomGenerationView: View {
    var folderId: UUID?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @AppStorage("max_cards_per_generation") private var maxCards = 10

    @State private var topic = ""
    @State private var cardCount = 10
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var generatedCount = 0
    @State private var selectedFolderId: UUID?
    @State private var folders: [CardFolder] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Тема") {
                    TextField("Например: числа от 100 до 1000, еда в ресторане...", text: $topic, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Количество") {
                    Stepper("Карточек: \(cardCount)", value: $cardCount, in: 1...maxCards)
                }

                Section("Сохранить в") {
                    Picker("Папка", selection: $selectedFolderId) {
                        Text("Корень (Мои карточки)")
                            .tag(nil as UUID?)
                        ForEach(folders, id: \.id) { folder in
                            Label(folder.name, systemImage: "folder.fill")
                                .tag(folder.id as UUID?)
                        }
                    }
                }

                Section {
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Генерация карточек...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task { await generate() }
                        } label: {
                            Label("Сгенерировать", systemImage: "sparkles")
                        }
                        .disabled(topic.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if generatedCount > 0 {
                    Section {
                        Label("Создано \(generatedCount) карточек", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Генерация (AI)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .disabled(isGenerating)
            .onAppear {
                cardCount = min(cardCount, maxCards)
                selectedFolderId = folderId
                loadFolders()
            }
        }
    }

    private func loadFolders() {
        let descriptor = FetchDescriptor<CardFolder>(sortBy: [SortDescriptor(\.name)])
        folders = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func generate() async {
        isGenerating = true
        errorMessage = nil
        generatedCount = 0

        do {
            let cards = try await LLMService.shared.generateCustomCards(
                topic: topic.trimmingCharacters(in: .whitespaces),
                count: cardCount
            )

            for generated in cards {
                let cardType: CardType
                if let typeStr = generated.type, let parsed = CardType(rawValue: typeStr) {
                    cardType = parsed
                } else {
                    cardType = .vocabulary
                }

                let card = Card(
                    lessonId: Card.customId(for: language),
                    front: generated.front,
                    back: generated.back,
                    contextSentence: generated.context ?? "",
                    cardType: cardType
                )
                card.graduated = true
                card.folderId = selectedFolderId
                modelContext.insert(card)
            }

            try? modelContext.save()
            generatedCount = cards.count
        } catch {
            errorMessage = error.localizedDescription
        }

        isGenerating = false
    }
}
