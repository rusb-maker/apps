import SwiftUI
import SwiftData

struct StudySessionView: View {
    @State private var viewModel = StudyViewModel()
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
            .onAppear {
                viewModel.loadDueCards(context: context)
            }
        }
    }
}

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
