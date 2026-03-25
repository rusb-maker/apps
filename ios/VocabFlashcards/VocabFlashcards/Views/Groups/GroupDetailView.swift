import SwiftUI
import SwiftData

struct GroupDetailView: View {
    @Bindable var group: CardGroup
    @Environment(\.modelContext) private var context
    @State private var showAddCard = false
    @State private var newFront = ""
    @State private var newContext = ""
    @State private var showRename = false
    @State private var renameText = ""

    private var sortedCards: [Card] {
        group.cards.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if group.cards.isEmpty {
                ContentUnavailableView(
                    "No Cards",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Add cards manually or record a conversation.")
                )
            }
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
        .navigationTitle(group.name)
        .navigationDestination(for: Card.self) { card in
            CardEditView(card: card)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        renameText = group.name
                        showRename = true
                    } label: {
                        Label("Rename Group", systemImage: "pencil")
                    }
                    Button {
                        showAddCard = true
                    } label: {
                        Label("Add Card", systemImage: "plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Group", isPresented: $showRename) {
            TextField("Group name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    group.name = trimmed
                    do { try context.save() } catch { print("[GroupDetail] rename save error: \(error)") }
                }
                renameText = ""
            }
            Button("Cancel", role: .cancel) { renameText = "" }
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
                    group: group
                )
                context.insert(card)
                do { try context.save() } catch { print("[GroupDetail] save error: \(error)") }
                newFront = ""
                newContext = ""
            }
            Button("Cancel", role: .cancel) {
                newFront = ""
                newContext = ""
            }
        }
    }
}

struct CardEditView: View {
    @Bindable var card: Card
    @Environment(\.modelContext) private var context
    @Query(sort: \CardGroup.createdAt, order: .reverse) private var allGroups: [CardGroup]
    @State private var showMoveToGroup = false
    @State private var showResetConfirm = false

    var body: some View {
        Form {
            Section("Front") {
                TextField("Word or phrase", text: $card.front)
            }
            Section("Back (translation/meaning)") {
                TextField("Translation", text: $card.back)
            }
            Section("Context") {
                TextField("Context sentence", text: $card.contextSentence)
            }
            Section("Type") {
                Picker("Verb type", selection: $card.verbType) {
                    Text("Phrasal verb").tag(VerbType.phrasal)
                    Text("Regular verb").tag(VerbType.regular)
                }
                .pickerStyle(.segmented)
            }
            Section("Group") {
                if let group = card.group {
                    LabeledContent("Current group", value: group.name)
                }
                Button("Move to another group…") {
                    showMoveToGroup = true
                }
            }
            Section("SM-2 Progress") {
                LabeledContent("Created", value: card.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Next review", value: card.nextReviewDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Ease factor", value: String(format: "%.2f", card.easeFactor))
                LabeledContent("Interval", value: "\(card.interval) days")
                LabeledContent("Repetitions", value: "\(card.repetitions)")
                Button("Reset progress", role: .destructive) {
                    showResetConfirm = true
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Edit Card")
        .onDisappear {
            do { try context.save() } catch { print("[CardEdit] save on disappear error: \(error)") }
        }
        .confirmationDialog("Reset SM-2 progress?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                card.easeFactor = 2.5
                card.interval = 0
                card.repetitions = 0
                card.nextReviewDate = Date()
                do { try context.save() } catch { print("[CardEdit] reset save error: \(error)") }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset the card to \"new\" status. It will appear in your next study session.")
        }
        .sheet(isPresented: $showMoveToGroup) {
            NavigationStack {
                List(allGroups) { group in
                    Button {
                        card.group = group
                        do { try context.save() } catch { print("[CardEdit] move save error: \(error)") }
                        showMoveToGroup = false
                    } label: {
                        HStack {
                            Text(group.name)
                            Spacer()
                            if card.group?.id == group.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                            Text("\(group.cards.count) cards")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
                .navigationTitle("Move to Group")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showMoveToGroup = false }
                    }
                }
            }
        }
    }
}
