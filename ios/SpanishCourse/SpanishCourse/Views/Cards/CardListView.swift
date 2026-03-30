import SwiftUI
import SwiftData

struct CardListView: View {
    let lesson: Lesson
    @Environment(\.modelContext) private var modelContext
    @Query private var allCards: [Card]

    private var cards: [Card] {
        allCards.filter { $0.lessonId == lesson.id && !$0.isTrashed }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            ForEach(cards, id: \.id) { card in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(card.front)
                            .font(.body.bold())
                            .onLongPressGesture {
                                SpanishTTS.shared.speak(card.front)
                            }
                        SpeakButton(text: card.front, size: .small)
                        Spacer()
                        Text(card.cardType.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.fill)
                            .clipShape(Capsule())
                    }
                    Text(card.back)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !card.contextSentence.isEmpty {
                        Text(card.contextSentence)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                    HStack {
                        if card.repetitions > 0 {
                            Label("\(card.repetitions)x", systemImage: "arrow.counterclockwise")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        Text("Следующий: \(card.nextReviewDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        card.isTrashed = true
                        card.trashedAt = Date()
                        try? modelContext.save()
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("Карточки")
        .themed()
        .overlay {
            if cards.isEmpty {
                ContentUnavailableView(
                    "Нет карточек",
                    systemImage: "rectangle.stack",
                    description: Text("Сгенерируйте карточки на странице урока")
                )
            }
        }
    }
}
