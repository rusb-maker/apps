import SwiftUI
import SwiftData

struct GroupsListView: View {
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var groups: [CardGroup]
    @Environment(\.modelContext) private var context
    @State private var showNewGroup = false
    @State private var newGroupName = ""

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
                                Text(group.name)
                                    .font(.headline)
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
                    Button {
                        showNewGroup = true
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
                    newGroupName = ""
                }
                Button("Cancel", role: .cancel) { newGroupName = "" }
            }
        }
    }
}
