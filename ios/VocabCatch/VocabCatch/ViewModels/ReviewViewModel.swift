import SwiftData
import Foundation

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
                front: phrase.verb,
                contextSentence: phrase.contextSentence,
                verbType: phrase.verbType,
                group: group
            )
            context.insert(card)
        }
        try? context.save()
    }

    private func createDefaultGroup(context: ModelContext) -> CardGroup {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let group = CardGroup(name: "Session \(formatter.string(from: Date()))")
        context.insert(group)
        return group
    }
}
