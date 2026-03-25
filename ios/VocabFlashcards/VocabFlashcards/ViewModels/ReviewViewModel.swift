import SwiftData
import Foundation

@MainActor
@Observable
class ReviewViewModel {
    var phrases: [ExtractedPhrase] = []
    var selectedGroup: CardGroup?

    var selectedCount: Int {
        phrases.filter(\.isSelected).count
    }

    func toggleSelection(for phrase: ExtractedPhrase) {
        guard let index = phrases.firstIndex(where: { $0.id == phrase.id }) else { return }
        phrases[index].isSelected.toggle()
    }

    func remove(at offsets: IndexSet) {
        phrases.remove(atOffsets: offsets)
    }

    func saveSelectedCards(context: ModelContext) {
        let group = selectedGroup ?? createDefaultGroup(context: context)
        for phrase in phrases where phrase.isSelected {
            let card = Card(
                front: phrase.phrase,
                back: phrase.translation,
                contextSentence: phrase.contextSentence ?? phrase.phrase,
                verbType: phrase.verbType ?? .regular,
                group: group
            )
            context.insert(card)
        }
        do {
            try context.save()
        } catch {
            print("[ReviewViewModel] Failed to save cards: \(error)")
        }
    }

    private func createDefaultGroup(context: ModelContext) -> CardGroup {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let group = CardGroup(name: "Session \(formatter.string(from: Date()))")
        context.insert(group)
        do {
            try context.save()
        } catch {
            print("[ReviewViewModel] Failed to save default group: \(error)")
        }
        return group
    }
}
