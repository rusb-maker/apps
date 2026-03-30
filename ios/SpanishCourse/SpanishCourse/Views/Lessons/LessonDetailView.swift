import SwiftUI
import SwiftData

struct LessonDetailView: View {
    let lesson: Lesson
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LessonDetailViewModel
    @State private var showingContent = false
    @State private var showingCardGeneration = false
    @State private var showingStudy = false
    @State private var showingTest = false
    @State private var vocabExpanded = false
    @State private var showingResetAlert = false

    init(lesson: Lesson) {
        self.lesson = lesson
        self._viewModel = State(initialValue: LessonDetailViewModel(lesson: lesson))
    }

    var body: some View {
        List {
            // Lesson info section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(lesson.level.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(lesson.level.color.opacity(0.2))
                            .foregroundStyle(lesson.level.color)
                            .clipShape(Capsule())
                        Text("Урок \(lesson.order)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(lesson.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showingContent = true
                } label: {
                    Label(
                        viewModel.progress?.isRead == true ? "Перечитать урок" : "Читать урок",
                        systemImage: "book.fill"
                    )
                }
            }

            // Key vocabulary — expandable
            Section {
                DisclosureGroup(isExpanded: $vocabExpanded) {
                    ForEach(Array(lesson.keyVocabulary)) { vocab in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(vocab.spanish)
                                    .font(.body.bold())
                                    .onLongPressGesture {
                                        SpanishTTS.shared.speak(vocab.spanish)
                                    }
                                SpeakButton(text: vocab.spanish, size: .small)
                                Spacer()
                                Text(vocab.russian)
                                    .foregroundStyle(.secondary)
                            }
                            if let example = vocab.example, !example.isEmpty {
                                HStack {
                                    Text(example)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .italic()
                                        .onLongPressGesture {
                                            SpanishTTS.shared.speak(example)
                                        }
                                    SpeakButton(text: example, size: .small)
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Label("Ключевая лексика", systemImage: "textbook")
                        Spacer()
                        Text("\(lesson.keyVocabulary.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Grammar points
            if !lesson.grammarPoints.isEmpty {
                Section("Грамматика") {
                    ForEach(lesson.grammarPoints, id: \.self) { point in
                        Label(point, systemImage: "lightbulb")
                            .font(.subheadline)
                    }
                }
            }

            // Cards section
            Section("Карточки") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(viewModel.cards.count) карточек")
                            .font(.headline)
                        if viewModel.dueCardCount > 0 {
                            Text("\(viewModel.dueCardCount) к повторению")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    if !viewModel.cards.isEmpty {
                        ProgressRingView(progress: viewModel.masteryPercentage, size: 40)
                    }
                }

                if !viewModel.cards.isEmpty {
                    NavigationLink("Все карточки") {
                        CardListView(lesson: lesson)
                    }
                }

                if viewModel.dueCardCount > 0 {
                    Button {
                        showingStudy = true
                    } label: {
                        Label("Учить (\(viewModel.dueCardCount))", systemImage: "brain.head.profile")
                    }
                }

                Button {
                    showingCardGeneration = true
                } label: {
                    Label("Сгенерировать ещё (AI)", systemImage: "sparkles")
                }

                if !viewModel.cards.isEmpty {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Сбросить прогресс", systemImage: "arrow.counterclockwise")
                    }
                }
            }

            // Test section
            if !viewModel.cards.isEmpty {
                Section("Тест") {
                    Button {
                        showingTest = true
                    } label: {
                        Label(
                            viewModel.allGraduated ? "Пройти тест заново" : "Пройти тест",
                            systemImage: "checkmark.seal"
                        )
                    }

                    if viewModel.allGraduated {
                        Label("Тест пройден — карточки в разделе \(lesson.level.rawValue)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Пройдите тест, чтобы карточки попали в раздел «Карточки»")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Stats
            if let progress = viewModel.progress {
                Section("Статистика") {
                    if progress.isRead {
                        Label("Урок прочитан", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    if progress.totalStudySessions > 0 {
                        LabeledContent("Сессий повторения", value: "\(progress.totalStudySessions)")
                    }
                    if let lastStudied = progress.lastStudiedAt {
                        LabeledContent("Последнее повторение", value: lastStudied.formatted(date: .abbreviated, time: .shortened))
                    }
                    if !viewModel.cards.isEmpty {
                        LabeledContent("Усвоено", value: "\(viewModel.masteredCount)/\(viewModel.cards.count)")
                    }
                }
            }
        }
        .navigationTitle(lesson.title)
        .themed()
        .onAppear {
            viewModel.loadData(context: modelContext)
        }
        .sheet(isPresented: $showingContent) {
            viewModel.markAsRead(context: modelContext)
        } content: {
            LessonContentView(lesson: lesson)
        }
        .sheet(isPresented: $showingCardGeneration) {
            viewModel.loadData(context: modelContext)
        } content: {
            CardGenerationView(lesson: lesson)
        }
        .fullScreenCover(isPresented: $showingStudy) {
            viewModel.loadData(context: modelContext)
        } content: {
            NavigationStack {
                StudySessionView(lessonId: lesson.id)
            }
        }
        .fullScreenCover(isPresented: $showingTest) {
            viewModel.loadData(context: modelContext)
        } content: {
            LessonTestView(lesson: lesson)
        }
        .alert("Сбросить прогресс?", isPresented: $showingResetAlert) {
            Button("Сбросить", role: .destructive) {
                viewModel.resetCards(context: modelContext)
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Прогресс всех карточек урока будет сброшен. Карточки будут удалены из раздела «Карточки».")
        }
    }
}
