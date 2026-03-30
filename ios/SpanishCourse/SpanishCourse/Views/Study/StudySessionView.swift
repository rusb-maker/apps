import SwiftUI
import SwiftData

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
    @State private var viewModel = StudyViewModel()
    @State private var isFlipped = false
    @State private var savedToMyCards = false
    @State private var showingCheatSheet = false

    private var needsCloseButton: Bool {
        lessonId != nil || graduatedOnly || customOnly
    }

    var body: some View {
        Group {
            if viewModel.sessionComplete {
                StudyCompleteView(
                    correctCount: viewModel.correctCount,
                    incorrectCount: viewModel.incorrectCount,
                    totalCards: viewModel.correctCount + viewModel.incorrectCount,
                    hasMoreBatches: viewModel.hasMoreBatches,
                    onStudyAgain: { loadCards() },
                    onNextBatch: { viewModel.continueWithNextBatch() }
                )
            } else if let card = viewModel.currentCard {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        ProgressView(value: viewModel.progress)
                            .tint(theme.accentColor)
                        HStack {
                            Text("\(viewModel.currentIndex + 1) / \(viewModel.totalCards)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !viewModel.sessionLabel.isEmpty {
                                Spacer()
                                Text(viewModel.sessionLabel)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
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

                    // Save to My Cards (only for lesson cards)
                    if card.lessonId != Card.customLessonId {
                        Button {
                            saveToMyCards(card)
                        } label: {
                            Label(
                                savedToMyCards ? "Сохранено" : "В мои карточки",
                                systemImage: savedToMyCards ? "checkmark.circle.fill" : "square.and.arrow.down"
                            )
                            .font(.caption)
                        }
                        .disabled(savedToMyCards)
                        .foregroundStyle(savedToMyCards ? .green : .teal)
                    }

                    Spacer()

                    if viewModel.isShowingAnswer {
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
            loadCards()
            StatsService.shared.startSession()
        }
        .onDisappear {
            StatsService.shared.endSession(context: modelContext)
        }
    }

    private func saveToMyCards(_ card: Card) {
        let copy = Card(
            lessonId: Card.customLessonId,
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
