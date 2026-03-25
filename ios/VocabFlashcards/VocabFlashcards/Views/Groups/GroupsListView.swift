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
                    group.hasChildren ? "\(group.activeChildren.count) subfolders" : nil,
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
    @State private var groupToMove: CardGroup?
    @State private var groupToDelete: CardGroup?
    @State private var showDeleteConfirm = false

    private var rootGroups: [CardGroup] {
        allGroups.filter { $0.parent == nil && !$0.isTrashed }
    }

    private var trashedCount: Int {
        allGroups.filter { $0.isTrashed }.count
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
                            groupToDelete = group
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    let groups = rootGroups
                    if let index = offsets.first {
                        groupToDelete = groups[index]
                        showDeleteConfirm = true
                    }
                }

                // Trash row
                NavigationLink {
                    TrashView()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text("Trash")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if trashedCount > 0 {
                            Text("\(trashedCount)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
            .sheet(item: $groupToMove) { group in
                MoveToFolderView(groupToMove: group)
            }
            .alert("Move to Trash?", isPresented: $showDeleteConfirm) {
                Button("Move to Trash", role: .destructive) {
                    if let group = groupToDelete {
                        group.moveToTrash()
                        try? context.save()
                    }
                    groupToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    groupToDelete = nil
                }
            } message: {
                if let group = groupToDelete {
                    Text("'\(group.name)' and all its contents will be moved to Trash. Items in Trash are deleted after 7 days.")
                }
            }
        }
    }
}

// MARK: - Folder Content View (unified: subfolders + cards)

struct FolderContentView: View {
    @Bindable var folder: CardGroup
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showNewFolder = false
    @State private var newItemName = ""
    @State private var showRenameChild = false
    @State private var renameChildName = ""
    @State private var childToRename: CardGroup?
    @State private var showMerge = false
    @State private var groupToMove: CardGroup?
    @State private var showAddCard = false
    @State private var newFront = ""
    @State private var newContext = ""
    @State private var showRenameFolder = false
    @State private var renameFolderName = ""
    @State private var showMoveSelf = false
    @State private var cardToMove: Card?
    @State private var isSelecting = false
    @State private var selectedCards: Set<UUID> = []
    @State private var showMoveSelected = false
    @State private var childToDelete: CardGroup?
    @State private var showDeleteChildConfirm = false
    @State private var cardToDelete: Card?
    @State private var showDeleteCardConfirm = false
    @State private var showDeleteBulkConfirm = false

    private var sortedCards: [Card] {
        folder.activeCards.sorted { $0.createdAt > $1.createdAt }
    }

    @ViewBuilder
    private var cardsSection: some View {
        Section {
            if isSelecting {
                HStack {
                    Button(selectedCards.count == sortedCards.count ? "Deselect All" : "Select All") {
                        if selectedCards.count == sortedCards.count {
                            selectedCards.removeAll()
                        } else {
                            selectedCards = Set(sortedCards.map(\.id))
                        }
                    }
                    .font(.subheadline)
                    Spacer()
                    Text("\(selectedCards.count) selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(sortedCards) { card in
                if isSelecting {
                    Button {
                        if selectedCards.contains(card.id) {
                            selectedCards.remove(card.id)
                        } else {
                            selectedCards.insert(card.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedCards.contains(card.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedCards.contains(card.id) ? .blue : .secondary)
                                .font(.title3)
                            CardRowContent(card: card)
                        }
                    }
                    .tint(.primary)
                } else {
                    NavigationLink(value: card) {
                        CardRowContent(card: card)
                    }
                    .contextMenu {
                        Button {
                            cardToMove = card
                        } label: {
                            Label("Move to…", systemImage: "folder.badge.arrow.up")
                        }
                        Button(role: .destructive) {
                            cardToDelete = card
                            showDeleteCardConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .onDelete { offsets in
                guard !isSelecting else { return }
                let cards = sortedCards
                if let index = offsets.first {
                    cardToDelete = cards[index]
                    showDeleteCardConfirm = true
                }
            }
        } header: {
            Text("Cards (\(folder.activeCards.count))")
        }
    }

    @ViewBuilder
    private var subfoldersSection: some View {
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
                        childToDelete = child
                        showDeleteChildConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                let sorted = folder.sortedChildren
                if let index = offsets.first {
                    childToDelete = sorted[index]
                    showDeleteChildConfirm = true
                }
            }
        }
    }

    var body: some View {
        List {
            if folder.activeChildren.isEmpty && folder.activeCards.isEmpty {
                ContentUnavailableView(
                    "Empty Folder",
                    systemImage: "folder",
                    description: Text("Add subfolders or cards to this folder.")
                )
            }

            // Subfolders section
            if folder.hasChildren {
                subfoldersSection
            }

            // Cards section
            if !folder.activeCards.isEmpty {
                cardsSection
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
            if !folder.activeCards.isEmpty {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedCards.removeAll()
                        }
                    }
                    if isSelecting {
                        Button {
                            showMoveSelected = true
                        } label: {
                            Image(systemName: "folder")
                        }
                        .disabled(selectedCards.isEmpty)

                        Button {
                            showDeleteBulkConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .disabled(selectedCards.isEmpty)
                    }
                }
            }

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

                    Divider()

                    Button {
                        renameFolderName = folder.name
                        showRenameFolder = true
                    } label: {
                        Label("Rename Folder", systemImage: "pencil")
                    }
                    Button {
                        showMoveSelf = true
                    } label: {
                        Label("Move Folder…", systemImage: "folder.badge.arrow.up")
                    }
                    if folder.parent != nil {
                        Button {
                            folder.parent = folder.parent?.parent
                            do { try context.save() } catch { print("[Folder] move up error: \(error)") }
                            dismiss()
                        } label: {
                            Label("Move Up One Level", systemImage: "arrow.up.doc")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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
        .sheet(item: $groupToMove) { group in
            MoveToFolderView(groupToMove: group)
        }
        .sheet(isPresented: $showMoveSelf) {
            MoveToFolderView(groupToMove: folder)
        }
        .sheet(item: $cardToMove) { card in
            GroupPickerView(selected: Binding(
                get: { card.group },
                set: { newGroup in
                    if let newGroup {
                        card.group = newGroup
                        do { try context.save() } catch { print("[Folder] move card error: \(error)") }
                    }
                }
            ))
        }
        .sheet(isPresented: $showMoveSelected) {
            MoveCardsToFolderView(
                cards: sortedCards.filter { selectedCards.contains($0.id) },
                onComplete: {
                    selectedCards.removeAll()
                    isSelecting = false
                }
            )
        }
        .alert("Rename Folder", isPresented: $showRenameFolder) {
            TextField("Name", text: $renameFolderName)
            Button("Save") {
                let trimmed = renameFolderName.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    folder.name = trimmed
                    do { try context.save() } catch { print("[Folder] rename save error: \(error)") }
                }
                renameFolderName = ""
            }
            Button("Cancel", role: .cancel) {
                renameFolderName = ""
            }
        }
        .alert("Move to Trash?", isPresented: $showDeleteChildConfirm) {
            Button("Move to Trash", role: .destructive) {
                if let child = childToDelete {
                    child.moveToTrash()
                    try? context.save()
                }
                childToDelete = nil
            }
            Button("Cancel", role: .cancel) { childToDelete = nil }
        } message: {
            if let child = childToDelete {
                Text("'\(child.name)' and all its contents will be moved to Trash.")
            }
        }
        .alert("Move to Trash?", isPresented: $showDeleteCardConfirm) {
            Button("Move to Trash", role: .destructive) {
                if let card = cardToDelete {
                    card.isTrashed = true
                    card.trashedAt = Date()
                    try? context.save()
                }
                cardToDelete = nil
            }
            Button("Cancel", role: .cancel) { cardToDelete = nil }
        } message: {
            if let card = cardToDelete {
                Text("'\(card.front)' will be moved to Trash.")
            }
        }
        .alert("Move \(selectedCards.count) Cards to Trash?", isPresented: $showDeleteBulkConfirm) {
            Button("Move to Trash", role: .destructive) {
                let now = Date()
                let cardsToTrash = sortedCards.filter { selectedCards.contains($0.id) }
                for card in cardsToTrash {
                    card.isTrashed = true
                    card.trashedAt = now
                }
                try? context.save()
                selectedCards.removeAll()
                if sortedCards.isEmpty {
                    isSelecting = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(selectedCards.count) cards will be moved to Trash.")
        }
    }
}

// MARK: - Card Row Content

private struct CardRowContent: View {
    let card: Card

    var body: some View {
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

// MARK: - Move Cards to Folder (bulk)

struct MoveCardsToFolderView: View {
    let cards: [Card]
    let onComplete: () -> Void
    @State private var selectedFolder: CardGroup?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        GroupPickerView(selected: Binding(
            get: { selectedFolder },
            set: { newFolder in
                if let newFolder {
                    selectedFolder = newFolder
                    for card in cards {
                        card.group = newFolder
                    }
                    do { try context.save() } catch { print("[MoveCards] save error: \(error)") }
                    onComplete()
                }
            }
        ))
    }
}

// MARK: - Move to Folder

struct MoveToFolderView: View {
    let groupToMove: CardGroup
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var allGroups: [CardGroup]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private var rootGroups: [CardGroup] {
        allGroups.filter { $0.parent == nil && !$0.isTrashed }
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
