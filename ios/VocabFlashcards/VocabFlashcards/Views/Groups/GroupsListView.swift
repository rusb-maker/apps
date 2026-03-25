import SwiftUI
import SwiftData

struct GroupsListView: View {
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var groups: [CardGroup]
    @Environment(\.modelContext) private var context
    @State private var showNewGroup = false
    @State private var newGroupName = ""
    @State private var showRenameGroup = false
    @State private var renameGroupName = ""
    @State private var groupToRename: CardGroup?
    @State private var showMerge = false
    @State private var mergeSelection: Set<UUID> = []
    @State private var mergeTargetName = ""

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "folder",
                        description: Text("Record a conversation and extract phrases to create your first group.")
                    )
                }
                ForEach(groups) { group in
                    NavigationLink(value: group) {
                        HStack {
                            VStack(alignment: .leading) {
                                HStack(spacing: 6) {
                                    Text(group.name)
                                        .font(.headline)
                                    if !group.isStudyEnabled {
                                        Image(systemName: "pause.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text("\(group.cards.count) cards")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            let dueCount = group.cards.filter { $0.nextReviewDate <= Date() }.count
                            if dueCount > 0 {
                                Text("\(dueCount) due")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.orange.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            renameGroupName = group.name
                            groupToRename = group
                            showRenameGroup = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            renameGroupName = group.name
                            groupToRename = group
                            showRenameGroup = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button {
                            group.isStudyEnabled.toggle()
                            do { try context.save() } catch { print("[GroupsList] toggle save error: \(error)") }
                        } label: {
                            if group.isStudyEnabled {
                                Label("Disable for Study", systemImage: "pause.circle")
                            } else {
                                Label("Enable for Study", systemImage: "play.circle")
                            }
                        }
                        Button(role: .destructive) {
                            context.delete(group)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(groups[index])
                    }
                }
            }
            .navigationTitle("Groups")
            .navigationDestination(for: CardGroup.self) { group in
                GroupDetailView(group: group)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showNewGroup = true
                        } label: {
                            Label("New Group", systemImage: "plus")
                        }
                        if groups.count >= 2 {
                            Button {
                                mergeSelection = []
                                mergeTargetName = ""
                                showMerge = true
                            } label: {
                                Label("Merge Groups…", systemImage: "arrow.triangle.merge")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Group", isPresented: $showNewGroup) {
                TextField("Group name", text: $newGroupName)
                Button("Create") {
                    guard !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let group = CardGroup(name: newGroupName)
                    context.insert(group)
                    do { try context.save() } catch { print("[GroupsList] save error: \(error)") }
                    newGroupName = ""
                }
                Button("Cancel", role: .cancel) { newGroupName = "" }
            }
            .alert("Rename Group", isPresented: $showRenameGroup) {
                TextField("Group name", text: $renameGroupName)
                Button("Save") {
                    let trimmed = renameGroupName.trimmingCharacters(in: .whitespaces)
                    if let group = groupToRename, !trimmed.isEmpty {
                        group.name = trimmed
                        do { try context.save() } catch { print("[GroupsList] rename save error: \(error)") }
                    }
                    renameGroupName = ""
                    groupToRename = nil
                }
                Button("Cancel", role: .cancel) {
                    renameGroupName = ""
                    groupToRename = nil
                }
            }
            .sheet(isPresented: $showMerge) {
                MergeGroupsView(groups: groups, context: context, isPresented: $showMerge)
            }
        }
    }
}

// MARK: - Merge Groups

struct MergeGroupsView: View {
    let groups: [CardGroup]
    let context: ModelContext
    @Binding var isPresented: Bool
    @State private var selected: Set<UUID> = []
    @State private var targetName = ""

    private var selectedGroups: [CardGroup] {
        groups.filter { selected.contains($0.id) }
    }

    private var totalCards: Int {
        selectedGroups.reduce(0) { $0 + $1.cards.count }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Merged group name", text: $targetName)
                } header: {
                    Text("New Group Name")
                }

                Section {
                    ForEach(groups) { group in
                        Button {
                            if selected.contains(group.id) {
                                selected.remove(group.id)
                            } else {
                                selected.insert(group.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(group.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(group.id) ? .blue : .secondary)
                                VStack(alignment: .leading) {
                                    Text(group.name)
                                        .foregroundStyle(.primary)
                                    Text("\(group.cards.count) cards")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text("Select groups to merge")
                } footer: {
                    if selected.count >= 2 {
                        Text("\(selectedGroups.count) groups, \(totalCards) cards total")
                    }
                }
            }
            .navigationTitle("Merge Groups")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merge") {
                        mergeGroups()
                        isPresented = false
                    }
                    .bold()
                    .disabled(selected.count < 2 || targetName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let first = groups.first, let second = groups.dropFirst().first {
                    targetName = "\(first.name) + \(second.name)"
                }
            }
        }
    }

    private func mergeGroups() {
        let trimmed = targetName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, selected.count >= 2 else { return }

        let newGroup = CardGroup(name: trimmed)
        context.insert(newGroup)

        for group in selectedGroups {
            for card in group.cards {
                card.group = newGroup
            }
            context.delete(group)
        }

        do {
            try context.save()
        } catch {
            print("[MergeGroupsView] Failed to save merge: \(error)")
        }
    }
}
