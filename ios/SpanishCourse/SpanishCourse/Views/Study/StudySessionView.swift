import SwiftUI
import SwiftData

struct SessionSummary {
    let dueCount: Int
    let masteredCount: Int
    let totalCount: Int
    let newCount: Int
}

struct StudySessionView: View {
    var lessonId: String? = nil
    var level: Level? = nil
    var graduatedOnly: Bool = false
    var customOnly: Bool = false
    var folderId: UUID? = nil
    var cheatSheet: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Environment(\.appLanguage) private var language
    @State private var viewModel = StudyViewModel()
    @State private var isFlipped = false
    @State private var savedToMyCards = false
    @State private var showingCheatSheet = false
    @State private var explanationText: String = ""
    @State private var isLoadingExplanation = false
    @State private var showExplanationInline = false
    @State private var showingSummary = true
    @State private var summaryStats: SessionSummary?
    @State private var hasLoaded = false

    private var needsCloseButton: Bool {
        lessonId != nil || graduatedOnly || customOnly
    }

    var body: some View {
        Group {
            if showingSummary, let stats = summaryStats {
                summaryView(stats: stats)
            } else if viewModel.sessionComplete {
                StudyCompleteView(
                    correctCount: viewModel.correctCount,
                    incorrectCount: viewModel.incorrectCount,
                    totalCards: viewModel.correctCount + viewModel.incorrectCount,
                    onStudyAgain: {
                        loadCards()
                        buildSummary()
                        showingSummary = true
                    }
                )
            } else if let card = viewModel.currentCard {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.progress)
                            .tint(theme.accentColor)
                        Text("\(viewModel.currentIndex + 1) / \(viewModel.totalCards)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Spacer()

                    FlipCardView(
                        front: card.front,
                        back: card.back,
                        context: card.contextSentence,
                        isFlipped: $isFlipped
                    )
                    .padding(.horizontal)

                    // Save to My Cards (only for lesson cards, not drills)
                    if !card.lessonId.hasPrefix("custom") && !card.lessonId.hasPrefix("drill_") {
                        let alreadySaved = savedToMyCards || isAlreadyInMyCards(card)
                        Button {
                            saveToMyCards(card)
                        } label: {
                            Label(
                                alreadySaved ? "Уже в моих" : "В мои карточки",
                                systemImage: alreadySaved ? "checkmark.circle.fill" : "square.and.arrow.down"
                            )
                            .font(.caption)
                        }
                        .disabled(alreadySaved)
                        .foregroundStyle(alreadySaved ? .green : .teal)
                    }

                    if !showExplanationInline {
                        Spacer()
                    }

                    if viewModel.isShowingAnswer {
                        if showExplanationInline {
                            explanationInlineView
                                .padding(.horizontal)
                        }
                        explainButton(card: card)
                        gradeButtons
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button {
                            withAnimation {
                                isFlipped = true
                                viewModel.showAnswer()
                            }
                        } label: {
                            Text("Показать ответ")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(theme.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            } else {
                ContentUnavailableView {
                    Label("Нет карточек для повторения", systemImage: "checkmark.circle")
                } description: {
                    if let nextDate = viewModel.nextDueDate {
                        Text("Следующее повторение: \(nextDate.formatted(date: .abbreviated, time: .shortened))")
                    } else {
                        Text("Пройдите тест в уроках, чтобы добавить карточки")
                    }
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            if needsCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                }
            }
            if cheatSheet != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCheatSheet = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCheatSheet) {
            if let cheatSheet {
                NavigationStack {
                    ScrollView {
                        Text(cheatSheet)
                            .font(.body)
                            .lineSpacing(6)
                            .padding()
                    }
                    .navigationTitle("Шпаргалка")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Закрыть") { showingCheatSheet = false }
                        }
                    }
                }
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            loadCards()
            buildSummary()
        }
        .onDisappear {
            StatsService.shared.endSession(context: modelContext)
        }
    }

    // MARK: - Summary

    private func summaryView(stats: SessionSummary) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.accentColor)

            Text("Сессия")
                .font(.title.bold())

            VStack(spacing: 12) {
                summaryRow(icon: "clock.badge.exclamationmark", label: "К повторению", value: "\(stats.dueCount)", color: .orange)
                summaryRow(icon: "checkmark.circle", label: "Выучено (≥3 повтора)", value: "\(stats.masteredCount)", color: .green)
                summaryRow(icon: "rectangle.stack", label: "Всего карточек", value: "\(stats.totalCount)", color: .primary)
                if stats.newCount > 0 {
                    summaryRow(icon: "sparkles", label: "Новые", value: "\(stats.newCount)", color: .blue)
                }
            }
            .padding()
            .background(.fill.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

            if stats.dueCount == 0 {
                Text("Нет карточек для повторения")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let next = viewModel.nextDueDate {
                    Text("Следующая: \(next.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if stats.dueCount > 0 {
                Button {
                    showingSummary = false
                    StatsService.shared.startSession()
                } label: {
                    Label("Начать (\(viewModel.totalCards))", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(theme.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
        }
        .padding()
    }

    private func summaryRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }

    private func buildSummary() {
        let now = Date()

        // Total cards in this scope
        let allDescriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { !$0.isTrashed }
        )
        var allCards = (try? modelContext.fetch(allDescriptor)) ?? []

        // Filter by scope
        if let lessonId {
            allCards = allCards.filter { $0.lessonId == lessonId }
        } else if let level {
            let prefix = level.rawValue.lowercased() + "_"
            if graduatedOnly {
                allCards = allCards.filter { $0.lessonId.hasPrefix(prefix) && $0.graduated }
            } else {
                allCards = allCards.filter { $0.lessonId.hasPrefix(prefix) }
            }
        } else if customOnly {
            allCards = allCards.filter { $0.lessonId == Card.customLessonId && $0.graduated && $0.folderId == folderId }
        } else if graduatedOnly {
            allCards = allCards.filter { $0.graduated }
        }

        let dueCount = allCards.filter { $0.nextReviewDate <= now }.count
        let masteredCount = allCards.filter { $0.repetitions >= 3 }.count
        let newCount = allCards.filter { $0.repetitions == 0 }.count

        summaryStats = SessionSummary(
            dueCount: dueCount,
            masteredCount: masteredCount,
            totalCount: allCards.count,
            newCount: newCount
        )
    }

    // MARK: - My Cards

    private func isAlreadyInMyCards(_ card: Card) -> Bool {
        let front = card.front
        let customId = Card.customId(for: language)
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { !$0.isTrashed && $0.front == front }
        )
        let matches = (try? modelContext.fetch(descriptor)) ?? []
        return matches.contains { $0.lessonId == customId || $0.lessonId == Card.customLessonId }
    }

    private func saveToMyCards(_ card: Card) {
        guard !isAlreadyInMyCards(card) else {
            savedToMyCards = true
            return
        }
        let copy = Card(
            lessonId: Card.customId(for: language),
            front: card.front,
            back: card.back,
            contextSentence: card.contextSentence,
            cardType: card.cardType
        )
        copy.graduated = true
        modelContext.insert(copy)
        try? modelContext.save()
        savedToMyCards = true
    }

    private func loadCards() {
        viewModel.loadDueCards(
            context: modelContext,
            lessonId: lessonId,
            level: level,
            graduatedOnly: graduatedOnly,
            customOnly: customOnly,
            folderId: folderId
        )
    }

    private var navigationTitle: String {
        if lessonId != nil { return "Повторение" }
        if customOnly { return "Мои карточки" }
        if let level { return "Учить \(level.rawValue)" }
        return "Учить"
    }

    // MARK: - Explain

    private func explainButton(card: Card) -> some View {
        Button {
            if showExplanationInline {
                withAnimation { showExplanationInline = false }
                return
            }
            if let cached = card.explanation, !cached.isEmpty {
                explanationText = cached
                isLoadingExplanation = false
                withAnimation { showExplanationInline = true }
                return
            }
            let sentence = card.contextSentence.isEmpty ? card.front : card.contextSentence
            explanationText = ""
            isLoadingExplanation = true
            withAnimation { showExplanationInline = true }
            Task {
                do {
                    let lang = language == .english ? "english" : "spanish"
                    let result = try await LLMService.shared.explainSentence(sentence, language: lang)
                    explanationText = result
                    card.explanation = result
                    try? modelContext.save()
                } catch {
                    explanationText = "Ошибка: \(error.localizedDescription)"
                }
                isLoadingExplanation = false
            }
        } label: {
            Label(
                language == .english ? "Explain" : "Explicar",
                systemImage: showExplanationInline ? "xmark.circle" : "sparkles"
            )
            .font(.caption)
        }
        .foregroundStyle(.purple)
    }

    private var explanationInlineView: some View {
        ScrollView {
            if isLoadingExplanation {
                ProgressView("Анализирую...")
                    .padding()
            } else {
                Text(explanationText)
                    .font(.callout)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var gradeButtons: some View {
        HStack(spacing: 8) {
            gradeButton(grade: 1, label: "Снова", color: .red, preview: viewModel.intervalPreview(for: 1))
            gradeButton(grade: 3, label: "Трудно", color: .orange, preview: viewModel.intervalPreview(for: 3))
            gradeButton(grade: 4, label: "Хорошо", color: .green, preview: viewModel.intervalPreview(for: 4))
            gradeButton(grade: 5, label: "Легко", color: .blue, preview: viewModel.intervalPreview(for: 5))
        }
    }

    private func gradeButton(grade: Int, label: String, color: Color, preview: String) -> some View {
        Button {
            withAnimation {
                isFlipped = false
                savedToMyCards = false
                explanationText = ""
                showExplanationInline = false
                viewModel.grade(grade, context: modelContext)
            }
        } label: {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption.bold())
                Text(preview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
