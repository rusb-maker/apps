import SwiftUI
import SwiftData

struct GroupDetailView: View {
    let group: CardGroup
    @Environment(\.modelContext) private var context
    @State private var showAddCard = false
    @State private var newFront = ""
    @State private var newContext = ""

    var body: some View {
        List {
            if group.cards.isEmpty {
                ContentUnavailableView(
                    "No Cards",
                    systemImage: "rectangle.on.rectangle",
                    description: Text("Add cards manually or record a conversation.")
                )
            }
            ForEach(group.cards.sorted(by: { $0.createdAt > $1.createdAt })) { card in
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
                let sorted = group.cards.sorted(by: { $0.createdAt > $1.createdAt })
                for index in offsets {
                    context.delete(sorted[index])
                }
            }
        }
        .navigationTitle(group.name)
        .navigationDestination(for: Card.self) { card in
            CardEditView(card: card)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddCard = true
                } label: {
                    Image(systemName: "plus")
                }
            }
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
            Section("Info") {
                LabeledContent("Type", value: card.verbType == .phrasal ? "Phrasal verb" : "Regular verb")
                LabeledContent("Created", value: card.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Next review", value: card.nextReviewDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Ease factor", value: String(format: "%.2f", card.easeFactor))
                LabeledContent("Interval", value: "\(card.interval) days")
                LabeledContent("Repetitions", value: "\(card.repetitions)")
            }
        }
        .navigationTitle("Edit Card")
    }
}
