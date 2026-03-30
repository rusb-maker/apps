import SwiftUI
import SwiftData

struct CardGroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Card> { $0.graduated && !$0.isTrashed }) private var graduatedCards: [Card]
    @State private var studyLevel: Level?
    @State private var studyCustom = false
    @State private var showingSerEstar = false
    @State private var showingSerEstarCheatSheet = false
    @State private var showingPronouns = false
    @State private var showingPronounsCheatSheet = false

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

            // Drill packs
            Section("Тренажёры") {
                let drillCards = drillCardsForPack("drill_ser_estar")
                let drillDue = dueCount(drillCards)

                HStack {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(.green)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SER vs ESTAR")
                            .font(.headline)
                        Text("\(drillCards.count) карточек (SM-2)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if drillDue > 0 {
                        Button {
                            showingSerEstar = true
                        } label: {
                            Text("Учить \(drillDue)")
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
                .onAppear {
                    seedDrillIfNeeded()
                }

                Button {
                    showingSerEstarCheatSheet = true
                } label: {
                    Label("Шпаргалка SER vs ESTAR", systemImage: "questionmark.circle")
                        .font(.subheadline)
                }

                // Pronouns drill
                let pronounCards = drillCardsForPack("drill_pronouns")
                let pronounDue = dueCount(pronounCards)

                HStack {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Местоимения")
                            .font(.headline)
                        Text("\(pronounCards.count) карточек (SM-2)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if pronounDue > 0 {
                        Button {
                            showingPronouns = true
                        } label: {
                            Text("Учить \(pronounDue)")
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
                .onAppear {
                    seedPronounsDrillIfNeeded()
                }

                Button {
                    showingPronounsCheatSheet = true
                } label: {
                    Label("Шпаргалка: местоимения", systemImage: "questionmark.circle")
                        .font(.subheadline)
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
        .fullScreenCover(isPresented: $showingSerEstar) {
            NavigationStack {
                StudySessionView(lessonId: "drill_ser_estar", cheatSheet: SerEstarDrill.cheatSheet)
            }
        }
        .fullScreenCover(isPresented: $showingPronouns) {
            NavigationStack {
                StudySessionView(lessonId: "drill_pronouns", cheatSheet: PronounsDrill.cheatSheet)
            }
        }
        .sheet(isPresented: $showingPronounsCheatSheet) {
            NavigationStack {
                ScrollView {
                    Text(PronounsDrill.cheatSheet)
                        .font(.body)
                        .lineSpacing(6)
                        .padding()
                }
                .navigationTitle("Местоимения")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showingPronounsCheatSheet = false }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSerEstarCheatSheet) {
            NavigationStack {
                ScrollView {
                    Text(SerEstarDrill.cheatSheet)
                        .font(.body)
                        .lineSpacing(6)
                        .padding()
                }
                .navigationTitle("SER vs ESTAR")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showingSerEstarCheatSheet = false }
                    }
                }
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

    // MARK: - Drill Packs

    private func drillCardsForPack(_ packId: String) -> [Card] {
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.lessonId == packId && !$0.isTrashed }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func seedDrillIfNeeded() {
        seedDrillPack("drill_ser_estar", cards: SerEstarDrill.cards)
    }

    private func seedPronounsDrillIfNeeded() {
        seedDrillPack("drill_pronouns", cards: PronounsDrill.cards)
    }

    private func seedDrillPack(_ packId: String, cards drillCards: [DrillCard]) {
        let existing = drillCardsForPack(packId)
        guard existing.isEmpty else { return }

        for drillCard in drillCards {
            let card = Card(
                lessonId: packId,
                front: drillCard.front,
                back: drillCard.back,
                contextSentence: drillCard.translation ?? drillCard.context ?? ""
            )
            card.cardType = .fillBlank
            modelContext.insert(card)
        }
        try? modelContext.save()
    }
}
