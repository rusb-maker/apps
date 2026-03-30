import SwiftUI
import SwiftData

struct CardGroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Card> { $0.graduated && !$0.isTrashed }) private var graduatedCards: [Card]
    @State private var studyLevel: Level?
    @State private var studyCustom = false

    var body: some View {
        List {
            // Level groups
            Section("По уровням") {
                ForEach(Level.allCases) { level in
                    let cards = cardsForLevel(level)
                    let due = dueCount(cards)
                    HStack {
                        Image(systemName: level.icon)
                            .foregroundStyle(level.color)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.rawValue)
                                .font(.headline)
                            Text("\(cards.count) карточек")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if due > 0 {
                            Button {
                                studyLevel = level
                            } label: {
                                Text("Учить \(due)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // My cards — link to folder browser
            Section("Мои карточки") {
                NavigationLink(value: "my_cards") {
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.teal)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Мои карточки")
                                .font(.headline)
                            let count = customCards.count
                            Text("\(count) карточек")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 4)

                let customDue = dueCount(customCards)
                if customDue > 0 {
                    Button {
                        studyCustom = true
                    } label: {
                        Label("Учить мои (\(customDue))", systemImage: "brain.head.profile")
                    }
                }
            }

            // Study all
            let totalDue = dueCountAll
            if totalDue > 0 {
                Section {
                    Button {
                        studyLevel = nil
                    } label: {
                        Label("Учить все (\(totalDue))", systemImage: "brain.head.profile")
                            .font(.headline)
                    }
                }
            }
        }
        .navigationTitle("Карточки")
        .themed()
        .navigationDestination(for: String.self) { _ in
            FolderListView()
        }
        .fullScreenCover(item: $studyLevel) { level in
            NavigationStack {
                StudySessionView(level: level, graduatedOnly: true)
            }
        }
        .fullScreenCover(isPresented: $studyCustom) {
            NavigationStack {
                StudySessionView(customOnly: true)
            }
        }
    }

    private func cardsForLevel(_ level: Level) -> [Card] {
        let prefix = level.rawValue.lowercased() + "_"
        return graduatedCards.filter { $0.lessonId.hasPrefix(prefix) }
    }

    private var customCards: [Card] {
        graduatedCards.filter { $0.lessonId == Card.customLessonId }
    }

    private func dueCount(_ cards: [Card]) -> Int {
        let now = Date()
        return cards.filter { $0.nextReviewDate <= now }.count
    }

    private var dueCountAll: Int {
        let now = Date()
        return graduatedCards.filter { $0.nextReviewDate <= now }.count
    }
}
