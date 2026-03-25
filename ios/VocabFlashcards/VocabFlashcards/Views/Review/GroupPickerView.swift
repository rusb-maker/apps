import SwiftUI
import SwiftData

struct GroupPickerView: View {
    @Binding var selected: CardGroup?
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var allGroups: [CardGroup]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var newFolderName = ""
    @State private var showNewFolder = false

    private var rootGroups: [CardGroup] {
        allGroups.filter { $0.parent == nil && !$0.isTrashed }
    }

    var body: some View {
        NavigationStack {
            List {
                if rootGroups.isEmpty {
                    Text("No folders yet. Create one below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(rootGroups) { group in
                    GroupPickerItemView(
                        group: group,
                        selected: $selected,
                        onSelect: { dismiss() }
                    )
                }
            }
            .navigationTitle("Choose Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Folder") { showNewFolder = true }
                }
            }
            .alert("New Folder", isPresented: $showNewFolder) {
                TextField("Folder name", text: $newFolderName)
                Button("Create") {
                    guard !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let group = CardGroup(name: newFolderName)
                    context.insert(group)
                    do { try context.save() } catch { print("[GroupPicker] save error: \(error)") }
                    selected = group
                    newFolderName = ""
                    dismiss()
                }
                Button("Cancel", role: .cancel) { newFolderName = "" }
            }
        }
    }
}

// MARK: - Picker item (recursive)

struct GroupPickerItemView: View {
    let group: CardGroup
    @Binding var selected: CardGroup?
    let onSelect: () -> Void

    var body: some View {
        if group.hasChildren {
            // Has subfolders — expandable, and itself is selectable
            DisclosureGroup {
                // Select this folder
                Button {
                    selected = group
                    onSelect()
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text("Select this folder")
                            .foregroundStyle(.blue)
                        Spacer()
                        if selected?.id == group.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                .tint(.primary)

                // Show children
                ForEach(group.sortedChildren) { child in
                    GroupPickerItemView(
                        group: child,
                        selected: $selected,
                        onSelect: onSelect
                    )
                }
            } label: {
                GroupPickerRowView(group: group, isSelected: selected?.id == group.id)
            }
        } else {
            // No children — just selectable
            Button {
                selected = group
                onSelect()
            } label: {
                GroupPickerRowView(group: group, isSelected: selected?.id == group.id)
            }
            .tint(.primary)
        }
    }
}

// MARK: - Picker row

struct GroupPickerRowView: View {
    let group: CardGroup
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(group.name)
                    .font(.headline)
                Text("\(group.totalCardCount) cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
    }
}
