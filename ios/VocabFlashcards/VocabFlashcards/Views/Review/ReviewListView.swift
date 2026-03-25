import SwiftUI
import SwiftData

struct ReviewListView: View {
    @State private var viewModel = ReviewViewModel()
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var allGroups: [CardGroup]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var rootGroups: [CardGroup] {
        allGroups.filter { $0.parent == nil && !$0.isTrashed }
    }

    private var selectedFolderName: String {
        viewModel.selectedGroup?.name ?? "Auto"
    }

    init(phrases: [ExtractedPhrase]) {
        _viewModel = State(initialValue: {
            let vm = ReviewViewModel()
            vm.phrases = phrases
            return vm
        }())
    }

    var body: some View {
        List {
            // MARK: - Phrases
            Section {
                ForEach(Array(viewModel.phrases.enumerated()), id: \.element.id) { index, phrase in
                    ReviewRow(phrase: phrase)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.phrases[index].isSelected = false
                            } label: {
                                Label("Skip", systemImage: "xmark")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                viewModel.phrases[index].isSelected = true
                            } label: {
                                Label("Keep", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                }
                .onDelete { offsets in
                    viewModel.remove(at: offsets)
                }
            }

            // MARK: - Save to folder
            Section {
                HStack {
                    Text("Save to")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button {
                            showNewFolder = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }

                        if !rootGroups.isEmpty {
                            Divider()
                        }

                        ForEach(rootGroups) { group in
                            Button {
                                viewModel.selectedGroup = group
                            } label: {
                                HStack {
                                    Text(group.name)
                                    if viewModel.selectedGroup?.id == group.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedFolderName)
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Review Phrases")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save \(viewModel.selectedCount)") {
                    viewModel.saveSelectedCards(context: context)
                    dismiss()
                }
                .disabled(viewModel.selectedCount == 0)
            }
        }
        .alert("New Folder", isPresented: $showNewFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Create") {
                let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                let group = CardGroup(name: trimmed)
                context.insert(group)
                try? context.save()
                viewModel.selectedGroup = group
                newFolderName = ""
            }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
    }
}

struct ReviewRow: View {
    let phrase: ExtractedPhrase

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(phrase.phrase)
                    .font(.headline)
                Spacer()
                if let level = phrase.cefrLevel {
                    Text(level)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(cefrColor(level).opacity(0.2))
                        .foregroundStyle(cefrColor(level))
                        .clipShape(Capsule())
                }
            }
            Text(phrase.translation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .opacity(phrase.isSelected ? 1.0 : 0.4)
    }

    private func cefrColor(_ level: String) -> Color {
        switch level.uppercased() {
        case "C2": .purple
        case "C1": .red
        case "B2": .orange
        default: .blue
        }
    }
}
