import SwiftUI
import SwiftData

struct DrillsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appLanguage) private var language

    // Spanish
    @State private var showingSerEstar = false
    @State private var showingPronouns = false
    @State private var showingTener = false
    @State private var showingTenerA1 = false
    @State private var showingNumbers = false
    // English
    @State private var showingEmails = false
    @State private var showingMeetings = false
    @State private var showingStandup = false
    @State private var showingCodeReview = false
    @State private var showingPhrasalVerbs = false
    @State private var showingITIdioms = false
    @State private var showingFalseFriends = false

    var body: some View {
        List {
            if language == .spanish {
                Section {
                    drillRow(packId: "drill_ser_estar", title: "SER vs ESTAR", subtitle: "Спряжение и различия", color: .green, showStudy: $showingSerEstar, seedCards: SerEstarDrill.cards, cheatSheet: SerEstarDrill.cheatSheet)
                    drillRow(packId: "drill_pronouns", title: "Местоимения", subtitle: "lo/la/le, me/te/se, двойные", color: .purple, showStudy: $showingPronouns, seedCards: PronounsDrill.cards, cheatSheet: PronounsDrill.cheatSheet)
                    drillRow(packId: "drill_tener", title: "TENER — база", subtitle: "спряжение, возраст, hambre/sed/frío/calor/sueño/miedo", color: .orange, showStudy: $showingTener, seedCards: TenerDrill.cards, cheatSheet: TenerDrill.cheatSheet)
                    drillRow(packId: "drill_numbers", title: "Числа, цены, время, даты", subtitle: "1-1.000.000, 15,95€, 3:15, el 25 de diciembre", color: .blue, showStudy: $showingNumbers, seedCards: NumbersDrill.cards, cheatSheet: NumbersDrill.cheatSheet)
                } header: {
                    Label("A0 — Базовый", systemImage: "leaf.fill")
                }
                Section {
                    drillRow(packId: "drill_tener_a1", title: "TENER — выражения", subtitle: "tener que, Ten, prisa/razón/suerte/ganas de, идиомы", color: .orange, showStudy: $showingTenerA1, seedCards: TenerA1Drill.cards, cheatSheet: TenerA1Drill.cheatSheet)
                } header: {
                    Label("A1 — Элементарный", systemImage: "leaf.fill")
                }
                // A2, B1, B2 — пока пусто, будут добавлены позже
            } else {
                Section {
                    drillRow(packId: "drill_emails", title: "Email Templates", subtitle: "Formal openings, requests, closings", color: .blue, showStudy: $showingEmails, seedCards: EmailDrill.cards, cheatSheet: EmailDrill.cheatSheet)
                    drillRow(packId: "drill_meetings", title: "Meeting Phrases", subtitle: "Agenda, opinions, action items", color: .green, showStudy: $showingMeetings, seedCards: MeetingDrill.cards, cheatSheet: MeetingDrill.cheatSheet)
                    drillRow(packId: "drill_standup", title: "Daily Standup", subtitle: "Yesterday, today, blockers", color: .orange, showStudy: $showingStandup, seedCards: StandupDrill.cards, cheatSheet: StandupDrill.cheatSheet)
                    drillRow(packId: "drill_code_review", title: "Code Review & Git", subtitle: "LGTM, nit, rebase, CI", color: .purple, showStudy: $showingCodeReview, seedCards: CodeReviewDrill.cards, cheatSheet: CodeReviewDrill.cheatSheet)
                    drillRow(packId: "drill_phrasal_verbs", title: "Phrasal Verbs", subtitle: "roll out, ramp up, phase out", color: .teal, showStudy: $showingPhrasalVerbs, seedCards: PhrasalVerbsDrill.cards, cheatSheet: PhrasalVerbsDrill.cheatSheet)
                    drillRow(packId: "drill_it_idioms", title: "IT Idioms", subtitle: "low-hanging fruit, bandwidth", color: .mint, showStudy: $showingITIdioms, seedCards: ITIdiomsDrill.cards, cheatSheet: ITIdiomsDrill.cheatSheet)
                    drillRow(packId: "drill_false_friends", title: "False Friends (рус↔англ)", subtitle: "actual≠актуальный, data≠дата", color: .red, showStudy: $showingFalseFriends, seedCards: FalseFriendsDrill.cards, cheatSheet: FalseFriendsDrill.cheatSheet)
                } header: {
                    Label("B2 — Business IT", systemImage: "star.fill")
                }
            }
        }
        .navigationTitle("Тренажёры")
        .themed()
    }

    // MARK: - Drill Row

    private func drillRow(packId: String, title: String, subtitle: String, color: Color, showStudy: Binding<Bool>, seedCards: [DrillCard], cheatSheet: String) -> some View {
        let cards = drillCardsForPack(packId)
        let due = dueCount(cards)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(color)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack {
                if cards.isEmpty {
                    Text("Загрузка...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("\(cards.count) карточек")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if due > 0 {
                        Text("• \(due) к повтору")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                Button {
                    showStudy.wrappedValue = true
                } label: {
                    Text(due > 0 ? "Учить \(due)" : "Начать")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(due > 0 ? .orange.opacity(0.2) : color.opacity(0.15))
                        .foregroundStyle(due > 0 ? .orange : color)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear { seedDrillPack(packId, cards: seedCards) }
        .fullScreenCover(isPresented: showStudy) {
            NavigationStack {
                StudySessionView(lessonId: packId, cheatSheet: cheatSheet)
            }
        }
    }

    // MARK: - Data

    private func drillCardsForPack(_ packId: String) -> [Card] {
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.lessonId == packId && !$0.isTrashed }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func dueCount(_ cards: [Card]) -> Int {
        let now = Date()
        return cards.filter { $0.nextReviewDate <= now }.count
    }

    private func seedDrillPack(_ packId: String, cards drillCards: [DrillCard]) {
        let existing = drillCardsForPack(packId)
        if !existing.isEmpty && existing.count == drillCards.count {
            if let first = existing.first,
               !first.contextSentence.isEmpty,
               !first.contextSentence.contains(where: { $0 >= "\u{0400}" && $0 <= "\u{04FF}" }) {
                return
            }
        }
        for card in existing { modelContext.delete(card) }
        for drillCard in drillCards {
            var backText = drillCard.back
            if let translation = drillCard.translation, !translation.isEmpty {
                backText += "\n\(translation)"
            }
            let card = Card(
                lessonId: packId,
                front: drillCard.front,
                back: backText,
                contextSentence: drillCard.fullSentence
            )
            card.cardType = .fillBlank
            modelContext.insert(card)
        }
        try? modelContext.save()
    }
}
