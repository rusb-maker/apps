import SwiftUI
import SwiftData

struct CustomCardView: View {
    var folderId: UUID? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var front = ""
    @State private var back = ""
    @State private var context = ""
    @State private var cardType: CardType = .vocabulary

    var body: some View {
        NavigationStack {
            Form {
                Section("Лицевая сторона (испанский)") {
                    TextField("Слово или фраза на испанском", text: $front, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Обратная сторона (русский)") {
                    TextField("Перевод или ответ", text: $back, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Контекст (необязательно)") {
                    TextField("Пример предложения", text: $context, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Тип карточки") {
                    Picker("Тип", selection: $cardType) {
                        ForEach(CardType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Новая карточка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        saveCard()
                        dismiss()
                    }
                    .disabled(front.isEmpty || back.isEmpty)
                    .bold()
                }
            }
        }
    }

    private func saveCard() {
        let card = Card(
            lessonId: Card.customLessonId,
            front: front.trimmingCharacters(in: .whitespacesAndNewlines),
            back: back.trimmingCharacters(in: .whitespacesAndNewlines),
            contextSentence: context.trimmingCharacters(in: .whitespacesAndNewlines),
            cardType: cardType
        )
        card.graduated = true
        card.folderId = folderId
        modelContext.insert(card)
        try? modelContext.save()
    }
}
