import SwiftUI
import SwiftData

struct CardEditView: View {
    @Bindable var card: Card
    @Environment(\.modelContext) private var context
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
            GroupPickerView(selected: Binding(
                get: { card.group },
                set: { newGroup in
                    card.group = newGroup
                    do { try context.save() } catch { print("[CardEdit] move save error: \(error)") }
                }
            ))
        }
    }
}
