import SwiftUI
import SwiftData

// MARK: - Question Model

private enum QuestionType {
    case flashcard
    case listening
}

private struct TestQuestion: Identifiable {
    let id = UUID()
    let card: Card
    let type: QuestionType
    /// For listening: 4 options (1 correct + 3 distractors)
    var options: [String] = []
    var correctOptionIndex: Int = 0
}

// MARK: - View

struct LessonTestView: View {
    let lesson: Lesson
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    @State private var questions: [TestQuestion] = []
    @State private var currentIndex = 0
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    @State private var testComplete = false
    @State private var passed = false

    // Flashcard state
    @State private var showingAnswer = false
    @State private var isFlipped = false

    // Listening state
    @State private var selectedOption: Int? = nil
    @State private var listeningAnswered = false

    private var currentQuestion: TestQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    private var passingScore: Double { 0.7 }

    var body: some View {
        NavigationStack {
            Group {
                if testComplete {
                    testResultView
                } else if let question = currentQuestion {
                    switch question.type {
                    case .flashcard:
                        flashcardView(card: question.card)
                    case .listening:
                        listeningView(question: question)
                    }
                } else {
                    ContentUnavailableView(
                        "Нет карточек",
                        systemImage: "rectangle.stack",
                        description: Text("Сначала откройте урок, чтобы создать карточки")
                    )
                }
            }
            .navigationTitle("Тест: \(lesson.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") {
                        SpanishTTS.shared.stop()
                        dismiss()
                    }
                }
            }
        }
        .onAppear { buildQuestions() }
        .onDisappear { SpanishTTS.shared.stop() }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(value: Double(currentIndex), total: Double(questions.count))
                .tint(theme.accentColor)
            HStack {
                Text("\(currentIndex + 1) / \(questions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let q = currentQuestion, q.type == .listening {
                    Label("Аудирование", systemImage: "ear.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Flashcard Question

    private func flashcardView(card: Card) -> some View {
        VStack(spacing: 24) {
            progressHeader

            Spacer()

            FlipCardView(
                front: card.front,
                back: card.back,
                context: card.contextSentence,
                isFlipped: $isFlipped
            )
            .padding(.horizontal)

            Spacer()

            if showingAnswer {
                HStack(spacing: 16) {
                    Button { answerFlashcard(correct: false) } label: {
                        Label("Не знаю", systemImage: "xmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Button { answerFlashcard(correct: true) } label: {
                        Label("Знаю", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
            } else {
                Button {
                    withAnimation {
                        isFlipped = true
                        showingAnswer = true
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
    }

    // MARK: - Listening Question

    private func listeningView(question: TestQuestion) -> some View {
        VStack(spacing: 24) {
            progressHeader

            Spacer()

            // Audio play area
            VStack(spacing: 16) {
                Image(systemName: "ear.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)

                Text("Что вы слышите?")
                    .font(.title2.bold())

                Button {
                    SpanishTTS.shared.speak(question.card.front)
                } label: {
                    Label("Прослушать", systemImage: "speaker.wave.2.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }
            .onAppear {
                // Auto-play on appear
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    SpanishTTS.shared.speak(question.card.front)
                }
            }

            Spacer()

            // 4 options
            VStack(spacing: 10) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        guard !listeningAnswered else { return }
                        selectedOption = index
                        listeningAnswered = true

                        let isCorrect = index == question.correctOptionIndex
                        if isCorrect { correctCount += 1 } else { incorrectCount += 1 }

                        // Auto-advance after delay
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            advanceToNext()
                        }
                    } label: {
                        HStack {
                            Text(option)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if listeningAnswered {
                                if index == question.correctOptionIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if index == selectedOption {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding()
                        .background(optionBackground(index: index, correct: question.correctOptionIndex))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(listeningAnswered)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private func optionBackground(index: Int, correct: Int) -> some ShapeStyle {
        if !listeningAnswered {
            return AnyShapeStyle(Color(.systemGray6))
        }
        if index == correct {
            return AnyShapeStyle(Color.green.opacity(0.2))
        }
        if index == selectedOption {
            return AnyShapeStyle(Color.red.opacity(0.2))
        }
        return AnyShapeStyle(Color(.systemGray6))
    }

    // MARK: - Results

    private var testResultView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: passed ? "star.fill" : "arrow.counterclockwise")
                .font(.system(size: 64))
                .foregroundStyle(passed ? .yellow : .orange)

            Text(passed ? "Тест пройден!" : "Попробуйте ещё раз")
                .font(.title.bold())

            let accuracy = questions.isEmpty ? 0 : Double(correctCount) / Double(questions.count)
            VStack(spacing: 12) {
                statRow("Правильно", "\(correctCount)/\(questions.count)", .green)
                statRow("Точность", "\(Int(accuracy * 100))%", accuracy >= passingScore ? .green : .red)
                statRow("Для прохождения", "\(Int(passingScore * 100))%", .secondary)
            }
            .padding()
            .background(.fill.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

            if passed {
                Text("Карточки добавлены в раздел \(lesson.level.rawValue)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if passed { dismiss() } else { resetTest() }
            } label: {
                Text(passed ? "Готово" : "Пройти ещё раз")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(passed ? .blue : .orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }

    private func statRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.headline).foregroundStyle(color)
        }
    }

    // MARK: - Logic

    private func buildQuestions() {
        let lessonId = lesson.id
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.lessonId == lessonId && !$0.isTrashed },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let allCards = ((try? modelContext.fetch(descriptor)) ?? []).shuffled()
        guard !allCards.isEmpty else { return }

        // ~10% listening, rest flashcard
        let listeningCount = max(1, allCards.count / 10)
        let listeningIndices = Set(Array(allCards.indices.shuffled().prefix(listeningCount)))

        // Collect all fronts for distractors
        let allFronts = allCards.map(\.front)

        questions = allCards.enumerated().map { index, card in
            if listeningIndices.contains(index) && allFronts.count >= 4 {
                // Build listening question with 4 options
                var distractors = allFronts.filter { $0 != card.front }.shuffled().prefix(3)
                // If not enough distractors, fill from vocabulary
                while distractors.count < 3 {
                    let fallback = lesson.keyVocabulary.map(\.spanish).filter { $0 != card.front }
                    distractors.append(contentsOf: fallback.prefix(3 - distractors.count))
                }
                var options = Array(distractors.prefix(3)) + [card.front]
                options.shuffle()
                let correctIndex = options.firstIndex(of: card.front) ?? 0
                return TestQuestion(card: card, type: .listening, options: options, correctOptionIndex: correctIndex)
            } else {
                return TestQuestion(card: card, type: .flashcard)
            }
        }
    }

    private func answerFlashcard(correct: Bool) {
        if correct { correctCount += 1 } else { incorrectCount += 1 }
        advanceToNext()
    }

    private func advanceToNext() {
        withAnimation {
            isFlipped = false
            showingAnswer = false
            selectedOption = nil
            listeningAnswered = false
            currentIndex += 1

            if currentIndex >= questions.count {
                let accuracy = Double(correctCount) / Double(max(questions.count, 1))
                passed = accuracy >= passingScore
                if passed { graduateCards() }
                testComplete = true
            }
        }
    }

    private func graduateCards() {
        for q in questions {
            q.card.graduated = true
        }
        try? modelContext.save()
        StatsService.shared.recordTestPassed(context: modelContext)
    }

    private func resetTest() {
        questions.shuffle()
        currentIndex = 0
        correctCount = 0
        incorrectCount = 0
        showingAnswer = false
        isFlipped = false
        selectedOption = nil
        listeningAnswered = false
        testComplete = false
        passed = false
    }
}
