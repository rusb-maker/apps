import SwiftUI
import SwiftData

struct GroupPickerView: View {
    @Binding var selected: CardGroup?
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var groups: [CardGroup]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var newGroupName = ""
    @State private var showNewGroup = false

    var body: some View {
        NavigationStack {
            List {
                if groups.isEmpty {
                    Text("No groups yet. Create one below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(groups) { group in
                    Button {
                        selected = group
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(group.name)
                                    .font(.headline)
                                Text("\(group.cards.count) cards")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selected?.id == group.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("Choose Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Group") { showNewGroup = true }
                }
            }
            .alert("New Group", isPresented: $showNewGroup) {
                TextField("Group name", text: $newGroupName)
                Button("Create") {
                    guard !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let group = CardGroup(name: newGroupName)
                    context.insert(group)
                    selected = group
                    newGroupName = ""
                    dismiss()
                }
                Button("Cancel", role: .cancel) { newGroupName = "" }
            }
        }
    }
}
