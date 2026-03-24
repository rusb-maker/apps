import Foundation
import SwiftData

@Model
class CardGroup {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Card.group)
    var cards: [Card]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        cards: [Card] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.cards = cards
    }
}
