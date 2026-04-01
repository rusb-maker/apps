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
    @State private var showingTener = false
    @State private var showingTenerCheatSheet = false
    // English drills
    @State private var showingPhrasalVerbs = false
    @State private var showingPhrasalVerbsCheatSheet = false
    @State private var showingITIdioms = false
    @State private var showingITIdiomsCheatSheet = false
    @State private var showingEmails = false
    @State private var showingEmailsCheatSheet = false
    @State private var showingMeetings = false
    @State private var showingMeetingsCheatSheet = false
    @State private var showingFalseFriends = false
    @State private var showingFalseFriendsCheatSheet = false
    @State private var showingCodeReview = false
    @State private var showingCodeReviewCheatSheet = false
    @State private var showingStandup = false
    @State private var showingStandupCheatSheet = false

    @Environment(\.appLanguage) private var language

    var body: some View {
        List {
            // Level groups
            Section("По уровням") {
                ForEach(language.levels) { level in
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
            /*Section("Тренажёры_OLD") {
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

                // TENER drill
                let tenerCards = drillCardsForPack("drill_tener")
                let tenerDue = dueCount(tenerCards)

                HStack {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TENER — выражения")
                            .font(.headline)
                        Text("\(tenerCards.count) карточек (SM-2)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if tenerDue > 0 {
                        Button {
                            showingTener = true
                        } label: {
                            Text("Учить \(tenerDue)")
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
                    seedTenerDrillIfNeeded()
                }

                Button {
                    showingTenerCheatSheet = true
                } label: {
                    Label("Шпаргалка: TENER", systemImage: "questionmark.circle")
                        .font(.subheadline)
                }
            }*/

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
        .fullScreenCover(isPresented: $showingPhrasalVerbs) {
            NavigationStack {
                StudySessionView(lessonId: "drill_phrasal_verbs", cheatSheet: PhrasalVerbsDrill.cheatSheet)
            }
        }
        .fullScreenCover(isPresented: $showingITIdioms) {
            NavigationStack {
                StudySessionView(lessonId: "drill_it_idioms", cheatSheet: ITIdiomsDrill.cheatSheet)
            }
        }
        .sheet(isPresented: $showingPhrasalVerbsCheatSheet) {
            NavigationStack {
                ScrollView {
                    Text(PhrasalVerbsDrill.cheatSheet).font(.body).lineSpacing(6).padding()
                }
                .navigationTitle("Phrasal Verbs").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { showingPhrasalVerbsCheatSheet = false } } }
            }
        }
        .sheet(isPresented: $showingITIdiomsCheatSheet) {
            NavigationStack {
                ScrollView {
                    Text(ITIdiomsDrill.cheatSheet).font(.body).lineSpacing(6).padding()
                }
                .navigationTitle("IT Idioms").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { showingITIdiomsCheatSheet = false } } }
            }
        }
        .fullScreenCover(isPresented: $showingEmails) {
            NavigationStack { StudySessionView(lessonId: "drill_emails", cheatSheet: EmailDrill.cheatSheet) }
        }
        .fullScreenCover(isPresented: $showingMeetings) {
            NavigationStack { StudySessionView(lessonId: "drill_meetings", cheatSheet: MeetingDrill.cheatSheet) }
        }
        .fullScreenCover(isPresented: $showingStandup) {
            NavigationStack { StudySessionView(lessonId: "drill_standup", cheatSheet: StandupDrill.cheatSheet) }
        }
        .fullScreenCover(isPresented: $showingCodeReview) {
            NavigationStack { StudySessionView(lessonId: "drill_code_review", cheatSheet: CodeReviewDrill.cheatSheet) }
        }
        .fullScreenCover(isPresented: $showingFalseFriends) {
            NavigationStack { StudySessionView(lessonId: "drill_false_friends", cheatSheet: FalseFriendsDrill.cheatSheet) }
        }
        .fullScreenCover(isPresented: $showingTener) {
            NavigationStack {
                StudySessionView(lessonId: "drill_tener", cheatSheet: TenerDrill.cheatSheet)
            }
        }
        .sheet(isPresented: $showingTenerCheatSheet) {
            NavigationStack {
                ScrollView {
                    Text(TenerDrill.cheatSheet)
                        .font(.body)
                        .lineSpacing(6)
                        .padding()
                }
                .navigationTitle("TENER")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Закрыть") { showingTenerCheatSheet = false }
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

    // MARK: - Spanish Drills Section

    private var spanishDrillsSection: some View {
        Section("Тренажёры") {
            drillRow(packId: "drill_ser_estar", title: "SER vs ESTAR", color: .green,
                     showStudy: $showingSerEstar, showCheat: $showingSerEstarCheatSheet, seedCards: SerEstarDrill.cards)
            drillRow(packId: "drill_pronouns", title: "Местоимения", color: .purple,
                     showStudy: $showingPronouns, showCheat: $showingPronounsCheatSheet, seedCards: PronounsDrill.cards)
            drillRow(packId: "drill_tener", title: "TENER — выражения", color: .orange,
                     showStudy: $showingTener, showCheat: $showingTenerCheatSheet, seedCards: TenerDrill.cards)
        }
    }

    // MARK: - English Drills Section

    private var englishDrillsSection: some View {
        Section("Drills") {
            drillRow(packId: "drill_emails", title: "Email Templates", color: .blue,
                     showStudy: $showingEmails, showCheat: $showingEmailsCheatSheet, seedCards: EmailDrill.cards)
            drillRow(packId: "drill_meetings", title: "Meeting Phrases", color: .green,
                     showStudy: $showingMeetings, showCheat: $showingMeetingsCheatSheet, seedCards: MeetingDrill.cards)
            drillRow(packId: "drill_standup", title: "Daily Standup", color: .orange,
                     showStudy: $showingStandup, showCheat: $showingStandupCheatSheet, seedCards: StandupDrill.cards)
            drillRow(packId: "drill_code_review", title: "Code Review & Git", color: .purple,
                     showStudy: $showingCodeReview, showCheat: $showingCodeReviewCheatSheet, seedCards: CodeReviewDrill.cards)
            drillRow(packId: "drill_phrasal_verbs", title: "Phrasal Verbs", color: .teal,
                     showStudy: $showingPhrasalVerbs, showCheat: $showingPhrasalVerbsCheatSheet, seedCards: PhrasalVerbsDrill.cards)
            drillRow(packId: "drill_it_idioms", title: "IT Idioms", color: .mint,
                     showStudy: $showingITIdioms, showCheat: $showingITIdiomsCheatSheet, seedCards: ITIdiomsDrill.cards)
            drillRow(packId: "drill_false_friends", title: "False Friends (рус↔англ)", color: .red,
                     showStudy: $showingFalseFriends, showCheat: $showingFalseFriendsCheatSheet, seedCards: FalseFriendsDrill.cards)
        }
    }

    // MARK: - Reusable Drill Row

    private func drillRow(packId: String, title: String, color: Color, showStudy: Binding<Bool>, showCheat: Binding<Bool>, seedCards: [DrillCard]) -> some View {
        let cards = drillCardsForPack(packId)
        let due = dueCount(cards)

        return HStack {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(color)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text("\(cards.count) карточек (SM-2)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if due > 0 {
                Button { showStudy.wrappedValue = true } label: {
                    Text("Учить \(due)")
                        .font(.caption.bold())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.orange.opacity(0.2))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear { seedDrillPack(packId, cards: seedCards) }
    }

    // MARK: - Helpers

    private func cardsForLevel(_ level: Level) -> [Card] {
        let prefix = level.rawValue.lowercased() + "_"
        return graduatedCards.filter { $0.lessonId.hasPrefix(prefix) }
    }

    private var customCards: [Card] {
        let customId = Card.customId(for: language)
        return graduatedCards.filter { $0.lessonId == customId || (language == .spanish && $0.lessonId == Card.customLessonId) }
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

    private func seedTenerDrillIfNeeded() {
        seedDrillPack("drill_tener", cards: TenerDrill.cards)
    }

    private func seedDrillPack(_ packId: String, cards drillCards: [DrillCard]) {
        let existing = drillCardsForPack(packId)

        // Reseed if count changed OR format is old (contextSentence doesn't have full Spanish)
        if !existing.isEmpty && existing.count == drillCards.count {
            // Check if already in new format (contextSentence has Spanish, not Russian)
            if let first = existing.first,
               !first.contextSentence.isEmpty,
               !first.contextSentence.contains(where: { $0 >= "\u{0400}" && $0 <= "\u{04FF}" }) {
                return // Already new format
            }
        }

        // Delete old cards and reseed
        for card in existing {
            modelContext.delete(card)
        }

        for drillCard in drillCards {
            // back = answer + rule + Russian translation
            var backText = drillCard.back
            if let translation = drillCard.translation, !translation.isEmpty {
                backText += "\n\(translation)"
            }

            let card = Card(
                lessonId: packId,
                front: drillCard.front,
                back: backText,
                contextSentence: drillCard.fullSentence  // full Spanish sentence
            )
            card.cardType = .fillBlank
            modelContext.insert(card)
        }
        try? modelContext.save()
    }
}
