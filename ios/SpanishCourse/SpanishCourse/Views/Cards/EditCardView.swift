import SwiftUI
import SwiftData

struct EditCardView: View {
    let card: Card
    var onSave: () -> Void = {}
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var front: String = ""
    @State private var back: String = ""
    @State private var context: String = ""
    @State private var cardType: CardType = .vocabulary

    var body: some View {
        NavigationStack {
            Form {
                Section("Лицевая сторона (испанский)") {
                    TextField("Слово или фраза", text: $front, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Обратная сторона (русский)") {
                    TextField("Перевод или ответ", text: $back, axis: .vertical)
                        .lineLimit(2...6)
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
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Сохранить") {
                        save()
                        dismiss()
                    }
                    .disabled(front.trimmingCharacters(in: .whitespaces).isEmpty ||
                              back.trimmingCharacters(in: .whitespaces).isEmpty)
                    .bold()
                }
            }
            .onAppear {
                front = card.front
                back = card.back
                context = card.contextSentence
                cardType = card.cardType
            }
        }
    }

    private func save() {
        card.front = front.trimmingCharacters(in: .whitespacesAndNewlines)
        card.back = back.trimmingCharacters(in: .whitespacesAndNewlines)
        card.contextSentence = context.trimmingCharacters(in: .whitespacesAndNewlines)
        card.cardType = cardType
        try? modelContext.save()
        onSave()
    }
}
