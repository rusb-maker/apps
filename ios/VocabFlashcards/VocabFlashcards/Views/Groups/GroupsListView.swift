import SwiftUI
import SwiftData

// MARK: - Folder Row (shared)

struct GroupRowView: View {
    let group: CardGroup

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
                .frame(width: 24)
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
                let parts = [
                    group.hasChildren ? "\(group.children.count) subfolders" : nil,
                    "\(group.totalCardCount) cards"
                ].compactMap { $0 }
                Text(parts.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let dueCount = group.totalDueCount
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
}

// MARK: - Groups List (root level)

struct GroupsListView: View {
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var allGroups: [CardGroup]
    @Environment(\.modelContext) private var context
    @State private var showNewFolder = false
    @State private var newItemName = ""
    @State private var showRenameGroup = false
    @State private var renameGroupName = ""
    @State private var groupToRename: CardGroup?
    @State private var showMerge = false
    @State private var showMoveGroup = false
    @State private var groupToMove: CardGroup?

    private var rootGroups: [CardGroup] {
        allGroups.filter { $0.parent == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if rootGroups.isEmpty {
                    ContentUnavailableView(
                        "No Folders",
                        systemImage: "folder",
                        description: Text("Record a conversation and extract phrases to create your first folder.")
                    )
                }
                ForEach(rootGroups) { group in
                    NavigationLink(value: group) {
                        GroupRowView(group: group)
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
                            groupToMove = group
                            showMoveGroup = true
                        } label: {
                            Label("Move to…", systemImage: "folder.badge.arrow.up")
                        }
                        Button {
                            group.setStudyEnabled(!group.isStudyEnabled)
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
                    let groups = rootGroups
                    for index in offsets {
                        context.delete(groups[index])
                    }
                }
            }
            .navigationTitle("Folders")
            .navigationDestination(for: CardGroup.self) { group in
                FolderContentView(folder: group)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showNewFolder = true
                        } label: {
                            Label("New Folder", systemImage: "folder.badge.plus")
                        }
                        if rootGroups.count >= 2 {
                            Button {
                                showMerge = true
                            } label: {
                                Label("Merge Folders…", systemImage: "arrow.triangle.merge")
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Folder", isPresented: $showNewFolder) {
                TextField("Folder name", text: $newItemName)
                Button("Create") {
                    guard !newItemName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let folder = CardGroup(name: newItemName)
                    context.insert(folder)
                    do { try context.save() } catch { print("[GroupsList] save error: \(error)") }
                    newItemName = ""
                }
                Button("Cancel", role: .cancel) { newItemName = "" }
            }
            .alert("Rename", isPresented: $showRenameGroup) {
                TextField("Name", text: $renameGroupName)
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
                MergeGroupsView(groups: rootGroups, context: context, isPresented: $showMerge)
            }
            .sheet(isPresented: $showMoveGroup) {
                if let group = groupToMove {
                    MoveToFolderView(groupToMove: group)
                }
            }
        }
    }
}

// MARK: - Folder Content View (unified: subfolders + cards)

struct FolderContentView: View {
    @Bindable var folder: CardGroup
    @Environment(\.modelContext) private var context
    @State private var showNewFolder = false
    @State private var newItemName = ""
    @State private var showRenameChild = false
    @State private var renameChildName = ""
    @State private var childToRename: CardGroup?
    @State private var showMerge = false
    @State private var showMoveGroup = false
    @State private var groupToMove: CardGroup?
    @State private var showAddCard = false
    @State private var newFront = ""
    @State private var newContext = ""

    private var sortedCards: [Card] {
        folder.cards.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if folder.children.isEmpty && folder.cards.isEmpty {
                ContentUnavailableView(
                    "Empty Folder",
                    systemImage: "folder",
                    description: Text("Add subfolders or cards to this folder.")
                )
            }

            // Subfolders section
            if folder.hasChildren {
                Section("Subfolders") {
                    ForEach(folder.sortedChildren) { child in
                        NavigationLink(value: child) {
                            GroupRowView(group: child)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                renameChildName = child.name
                                childToRename = child
                                showRenameChild = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button {
                                renameChildName = child.name
                                childToRename = child
                                showRenameChild = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button {
                                child.parent = folder.parent
                                do { try context.save() } catch { print("[Folder] move up error: \(error)") }
                            } label: {
                                Label("Move Up", systemImage: "arrow.up.doc")
                            }
                            Button {
                                groupToMove = child
                                showMoveGroup = true
                            } label: {
                                Label("Move to…", systemImage: "folder.badge.arrow.up")
                            }
                            Button {
                                child.setStudyEnabled(!child.isStudyEnabled)
                                do { try context.save() } catch { print("[Folder] toggle save error: \(error)") }
                            } label: {
                                if child.isStudyEnabled {
                                    Label("Disable for Study", systemImage: "pause.circle")
                                } else {
                                    Label("Enable for Study", systemImage: "play.circle")
                                }
                            }
                            Button(role: .destructive) {
                                context.delete(child)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { offsets in
                        let sorted = folder.sortedChildren
                        for index in offsets {
                            context.delete(sorted[index])
                        }
                    }
                }
            }

            // Cards section
            if !folder.cards.isEmpty {
                Section("Cards (\(folder.cards.count))") {
                    ForEach(sortedCards) { card in
                        NavigationLink(value: card) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(card.front)
                                        .font(.headline)
                                    Spacer()
                                    Text(card.verbType == .phrasal ? "phrasal" : "verb")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(card.verbType == .phrasal ? Color.orange.opacity(0.2) : Color.blue.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                                Text(card.contextSentence)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if !card.back.isEmpty {
                                    Text(card.back)
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete { offsets in
                        let cards = sortedCards
                        for index in offsets {
                            context.delete(cards[index])
                        }
                    }
                }
            }
        }
        .navigationTitle(folder.name)
        .navigationDestination(for: CardGroup.self) { group in
            FolderContentView(folder: group)
        }
        .navigationDestination(for: Card.self) { card in
            CardEditView(card: card)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showNewFolder = true
                    } label: {
                        Label("New Subfolder", systemImage: "folder.badge.plus")
                    }
                    Button {
                        showAddCard = true
                    } label: {
                        Label("Add Card", systemImage: "plus.rectangle")
                    }
                    if folder.children.count >= 2 {
                        Button {
                            showMerge = true
                        } label: {
                            Label("Merge…", systemImage: "arrow.triangle.merge")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Subfolder", isPresented: $showNewFolder) {
            TextField("Folder name", text: $newItemName)
            Button("Create") {
                guard !newItemName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let sub = CardGroup(name: newItemName, parent: folder)
                context.insert(sub)
                do { try context.save() } catch { print("[Folder] save error: \(error)") }
                newItemName = ""
            }
            Button("Cancel", role: .cancel) { newItemName = "" }
        }
        .alert("Add Card", isPresented: $showAddCard) {
            TextField("Word or phrase", text: $newFront)
            TextField("Context sentence", text: $newContext)
            Button("Add") {
                guard !newFront.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                let card = Card(
                    front: newFront,
                    contextSentence: newContext,
                    verbType: .regular,
                    group: folder
                )
                context.insert(card)
                do { try context.save() } catch { print("[Folder] save error: \(error)") }
                newFront = ""
                newContext = ""
            }
            Button("Cancel", role: .cancel) {
                newFront = ""
                newContext = ""
            }
        }
        .alert("Rename", isPresented: $showRenameChild) {
            TextField("Name", text: $renameChildName)
            Button("Save") {
                let trimmed = renameChildName.trimmingCharacters(in: .whitespaces)
                if let child = childToRename, !trimmed.isEmpty {
                    child.name = trimmed
                    do { try context.save() } catch { print("[Folder] rename save error: \(error)") }
                }
                renameChildName = ""
                childToRename = nil
            }
            Button("Cancel", role: .cancel) {
                renameChildName = ""
                childToRename = nil
            }
        }
        .sheet(isPresented: $showMerge) {
            MergeGroupsView(groups: folder.sortedChildren, context: context, isPresented: $showMerge, parentFolder: folder)
        }
        .sheet(isPresented: $showMoveGroup) {
            if let group = groupToMove {
                MoveToFolderView(groupToMove: group)
            }
        }
    }
}

// MARK: - Move to Folder

struct MoveToFolderView: View {
    let groupToMove: CardGroup
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var allGroups: [CardGroup]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private var rootGroups: [CardGroup] {
        allGroups.filter { $0.parent == nil }
    }

    /// Check if a group is a descendant of the group being moved (to prevent cycles)
    private func isDescendant(_ group: CardGroup) -> Bool {
        var current: CardGroup? = group
        while let c = current {
            if c.id == groupToMove.id { return true }
            current = c.parent
        }
        return false
    }

    var body: some View {
        NavigationStack {
            List {
                // Option to move to root level
                Button {
                    groupToMove.parent = nil
                    do { try context.save() } catch { print("[Move] save error: \(error)") }
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tray.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text("Root Level")
                            .font(.headline)
                        Spacer()
                        if groupToMove.parent == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .tint(.primary)
                .disabled(groupToMove.parent == nil)

                // Show all root folders as destinations
                ForEach(rootGroups) { group in
                    if group.id != groupToMove.id && !isDescendant(group) {
                        MoveToFolderRowView(
                            folder: group,
                            groupToMove: groupToMove,
                            isDescendant: isDescendant,
                            onMove: { destination in
                                groupToMove.parent = destination
                                do { try context.save() } catch { print("[Move] save error: \(error)") }
                                dismiss()
                            }
                        )
                    }
                }
            }
            .navigationTitle("Move \(groupToMove.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct MoveToFolderRowView: View {
    let folder: CardGroup
    let groupToMove: CardGroup
    let isDescendant: (CardGroup) -> Bool
    let onMove: (CardGroup) -> Void

    private var validChildren: [CardGroup] {
        folder.sortedChildren.filter { $0.id != groupToMove.id && !isDescendant($0) }
    }

    var body: some View {
        if validChildren.isEmpty {
            // No children to expand — just a selectable row
            Button {
                onMove(folder)
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    Text(folder.name)
                        .font(.headline)
                    Spacer()
                    if groupToMove.parent?.id == folder.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .tint(.primary)
            .disabled(groupToMove.parent?.id == folder.id)
        } else {
            // Has valid children — expandable
            DisclosureGroup {
                Button {
                    onMove(folder)
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("Move here")
                            .foregroundStyle(.blue)
                        Spacer()
                        if groupToMove.parent?.id == folder.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .tint(.primary)
                .disabled(groupToMove.parent?.id == folder.id)

                ForEach(validChildren) { child in
                    MoveToFolderRowView(
                        folder: child,
                        groupToMove: groupToMove,
                        isDescendant: isDescendant,
                        onMove: onMove
                    )
                }
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text(folder.name)
                            .font(.headline)
                        Text("\(folder.children.count) subfolders · \(folder.totalCardCount) cards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Merge Groups

struct MergeGroupsView: View {
    let groups: [CardGroup]
    let context: ModelContext
    @Binding var isPresented: Bool
    var parentFolder: CardGroup? = nil
    @State private var selected: Set<UUID> = []
    @State private var targetName = ""

    private var selectedGroups: [CardGroup] {
        groups.filter { selected.contains($0.id) }
    }

    private var totalCards: Int {
        selectedGroups.reduce(0) { $0 + $1.totalCardCount }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Merged folder name", text: $targetName)
                } header: {
                    Text("New Folder Name")
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
                                    Text("\(group.totalCardCount) cards")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .tint(.primary)
                    }
                } header: {
                    Text("Select folders to merge")
                } footer: {
                    if selected.count >= 2 {
                        Text("\(selectedGroups.count) folders, \(totalCards) cards total")
                    }
                }
            }
            .navigationTitle("Merge Folders")
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

        let newGroup = CardGroup(name: trimmed, parent: parentFolder)
        context.insert(newGroup)

        for group in selectedGroups {
            for card in group.cards {
                card.group = newGroup
            }
            for child in group.children {
                child.parent = newGroup
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
