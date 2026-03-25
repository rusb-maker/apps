import Foundation
import SwiftData

@Model
class CardGroup {
    var id: UUID
    var name: String
    var createdAt: Date
    var isStudyEnabled: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \Card.group)
    var cards: [Card]

    // Soft-delete
    var isTrashed: Bool = false
    var trashedAt: Date?

    // MARK: - Hierarchy

    var parent: CardGroup?

    @Relationship(deleteRule: .cascade, inverse: \CardGroup.parent)
    var children: [CardGroup]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        cards: [Card] = [],
        children: [CardGroup] = [],
        parent: CardGroup? = nil,
        isStudyEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.cards = cards
        self.children = children
        self.parent = parent
        self.isStudyEnabled = isStudyEnabled
    }

    // MARK: - Computed Helpers

    /// Active (non-trashed) cards
    var activeCards: [Card] {
        cards.filter { !$0.isTrashed }
    }

    /// Active (non-trashed) children
    var activeChildren: [CardGroup] {
        children.filter { !$0.isTrashed }
    }

    /// Whether this folder has non-trashed subfolders
    var hasChildren: Bool {
        !activeChildren.isEmpty
    }

    /// Active children sorted by createdAt descending
    var sortedChildren: [CardGroup] {
        activeChildren.sorted { $0.createdAt > $1.createdAt }
    }

    /// Total card count across this group and all active descendants
    var totalCardCount: Int {
        activeCards.count + activeChildren.reduce(0) { $0 + $1.totalCardCount }
    }

    /// Total due card count across this group and all active descendants
    var totalDueCount: Int {
        let now = Date()
        let ownDue = activeCards.filter { $0.nextReviewDate <= now }.count
        return ownDue + activeChildren.reduce(0) { $0 + $1.totalDueCount }
    }

    /// All active cards from this group and all active descendants (flattened)
    var allCards: [Card] {
        activeCards + activeChildren.flatMap { $0.allCards }
    }

    /// Cascade study-enable to all descendants
    func setStudyEnabled(_ enabled: Bool) {
        isStudyEnabled = enabled
        for child in children {
            child.setStudyEnabled(enabled)
        }
    }

    // MARK: - Trash

    /// Recursively move this folder, all children, and all cards to trash
    func moveToTrash() {
        let now = Date()
        isTrashed = true
        trashedAt = now
        for card in cards {
            card.isTrashed = true
            card.trashedAt = now
        }
        for child in children {
            child.moveToTrash()
        }
    }

    /// Recursively restore this folder, all children, and all cards from trash
    func restoreFromTrash() {
        isTrashed = false
        trashedAt = nil
        for card in cards {
            card.isTrashed = false
            card.trashedAt = nil
        }
        for child in children {
            child.restoreFromTrash()
        }
    }
}
