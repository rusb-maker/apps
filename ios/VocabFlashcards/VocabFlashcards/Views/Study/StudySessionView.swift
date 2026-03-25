import SwiftUI
import SwiftData

struct StudySessionView: View {
    @State private var viewModel = StudyViewModel()
    @State private var showGroupFilter = false
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.sessionComplete {
                    StudyCompleteView(
                        correct: viewModel.correctCount,
                        incorrect: viewModel.incorrectCount,
                        total: viewModel.totalCards
                    ) {
                        viewModel.loadDueCards(context: context)
                    }
                } else if let card = viewModel.currentCard {
                    VStack(spacing: 20) {
                        // Progress
                        ProgressView(value: viewModel.progress)
                            .padding(.horizontal)

                        Text("\(viewModel.currentIndex + 1) / \(viewModel.totalCards)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Card
                        FlipCardView(
                            front: card.front,
                            back: card.back.isEmpty ? card.contextSentence : card.back,
                            context: card.contextSentence,
                            isFlipped: viewModel.isShowingAnswer
                        )
                        .padding(.horizontal)

                        Spacer()

                        if viewModel.isShowingAnswer {
                            // Grade buttons
                            VStack(spacing: 12) {
                                Text("How well did you know it?")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 12) {
                                    GradeButton(label: "Again", grade: 0, color: .red) {
                                        viewModel.grade(0, context: context)
                                    }
                                    GradeButton(label: "Hard", grade: 3, color: .orange) {
                                        viewModel.grade(3, context: context)
                                    }
                                    GradeButton(label: "Good", grade: 4, color: .green) {
                                        viewModel.grade(4, context: context)
                                    }
                                    GradeButton(label: "Easy", grade: 5, color: .blue) {
                                        viewModel.grade(5, context: context)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            Button("Show Answer") {
                                viewModel.showAnswer()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }

                        Spacer()
                    }
                } else {
                    ContentUnavailableView(
                        "No Cards Due",
                        systemImage: "checkmark.circle",
                        description: Text("All caught up! Record a conversation to add new cards.")
                    )
                }
            }
            .navigationTitle("Study")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showGroupFilter = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .onAppear {
                viewModel.loadDueCards(context: context)
            }
            .sheet(isPresented: $showGroupFilter) {
                StudyGroupFilterView {
                    viewModel.loadDueCards(context: context)
                }
            }
        }
    }
}

// MARK: - Group Filter

struct StudyGroupFilterView: View {
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var groups: [CardGroup]
    @Environment(\.dismiss) private var dismiss
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "folder",
                        description: Text("Create groups by recording conversations or pasting text.")
                    )
                } else {
                    Section {
                        ForEach(groups) { group in
                            StudyGroupRow(group: group)
                        }
                    } header: {
                        Text("Toggle groups for study sessions")
                    } footer: {
                        let enabledCount = groups.filter(\.isStudyEnabled).count
                        Text("\(enabledCount) of \(groups.count) groups active")
                    }

                    Section {
                        Button("Enable All") {
                            for group in groups { group.isStudyEnabled = true }
                        }
                        .disabled(groups.allSatisfy(\.isStudyEnabled))

                        Button("Disable All") {
                            for group in groups { group.isStudyEnabled = false }
                        }
                        .disabled(groups.allSatisfy { !$0.isStudyEnabled })
                    }
                }
            }
            .navigationTitle("Study Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StudyGroupRow: View {
    @Bindable var group: CardGroup

    private var dueCount: Int {
        group.cards.filter { $0.nextReviewDate <= Date() }.count
    }

    var body: some View {
        Toggle(isOn: $group.isStudyEnabled) {
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.body)
                HStack(spacing: 8) {
                    Text("\(group.cards.count) cards")
                    if dueCount > 0 {
                        Text("·")
                        Text("\(dueCount) due")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Grade Button

struct GradeButton: View {
    let label: String
    let grade: Int
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
