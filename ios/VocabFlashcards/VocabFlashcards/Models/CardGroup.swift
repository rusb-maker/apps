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

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        cards: [Card] = [],
        isStudyEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.cards = cards
        self.isStudyEnabled = isStudyEnabled
    }
}
