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
                            isFlipped: $viewModel.isShowingAnswer
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
                                    GradeButton(label: "Again", subtitle: viewModel.intervalPreview(for: 0), color: .red) {
                                        viewModel.grade(0, context: context)
                                    }
                                    GradeButton(label: "Hard", subtitle: viewModel.intervalPreview(for: 3), color: .orange) {
                                        viewModel.grade(3, context: context)
                                    }
                                    GradeButton(label: "Good", subtitle: viewModel.intervalPreview(for: 4), color: .green) {
                                        viewModel.grade(4, context: context)
                                    }
                                    GradeButton(label: "Easy", subtitle: viewModel.intervalPreview(for: 5), color: .blue) {
                                        viewModel.grade(5, context: context)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }

                        Spacer()
                    }
                } else {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No Cards Due")
                            .font(.title2.bold())
                        if let nextDate = viewModel.nextDueDate {
                            Text("Next review: \(nextDate, style: .relative)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Record a conversation or generate cards to start studying.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        Spacer()
                    }
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
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var allGroups: [CardGroup]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var onDismiss: () -> Void

    private var rootGroups: [CardGroup] {
        allGroups.filter { $0.parent == nil && !$0.isTrashed }
    }

    var body: some View {
        NavigationStack {
            List {
                if rootGroups.isEmpty {
                    ContentUnavailableView(
                        "No Folders",
                        systemImage: "folder",
                        description: Text("Create folders by recording conversations or pasting text.")
                    )
                } else {
                    Section {
                        ForEach(rootGroups) { group in
                            StudyGroupTreeRow(group: group)
                        }
                    } header: {
                        Text("Toggle folders for study sessions")
                    } footer: {
                        let enabledCount = allGroups.filter(\.isStudyEnabled).count
                        Text("\(enabledCount) of \(allGroups.count) folders active")
                    }

                    Section {
                        Button("Enable All") {
                            for group in allGroups { group.isStudyEnabled = true }
                            try? context.save()
                        }
                        .disabled(allGroups.allSatisfy(\.isStudyEnabled))

                        Button("Disable All") {
                            for group in allGroups { group.isStudyEnabled = false }
                            try? context.save()
                        }
                        .disabled(allGroups.allSatisfy { !$0.isStudyEnabled })
                    }
                }
            }
            .navigationTitle("Study Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? context.save()
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StudyGroupTreeRow: View {
    @Bindable var group: CardGroup
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Toggle(isOn: Binding(
                get: { group.isStudyEnabled },
                set: { newValue in
                    group.setStudyEnabled(newValue)
                    try? context.save()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Text(group.name)
                            .font(.body)
                    }
                    HStack(spacing: 8) {
                        Text("\(group.totalCardCount) cards")
                        let dueCount = group.totalDueCount
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

            if group.hasChildren {
                DisclosureGroup {
                    ForEach(group.sortedChildren) { child in
                        StudyGroupTreeRow(group: child)
                    }
                } label: {
                    Text("\(group.children.count) subfolders")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 20)
            }
        }
    }
}

// MARK: - Grade Button

struct GradeButton: View {
    let label: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
