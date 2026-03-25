import Foundation
import SwiftData

enum VerbType: String, Codable {
    case phrasal
    case regular
}

@Model
class Card {
    var id: UUID
    var front: String
    var back: String
    var contextSentence: String
    var verbType: VerbType
    var createdAt: Date

    // SM-2 parameters
    var easeFactor: Double
    var interval: Int
    var repetitions: Int
    var nextReviewDate: Date

    var group: CardGroup?

    init(
        id: UUID = UUID(),
        front: String,
        back: String = "",
        contextSentence: String,
        verbType: VerbType,
        createdAt: Date = Date(),
        easeFactor: Double = 2.5,
        interval: Int = 0,
        repetitions: Int = 0,
        nextReviewDate: Date = Date(),
        group: CardGroup? = nil
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.contextSentence = contextSentence
        self.verbType = verbType
        self.createdAt = createdAt
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
        self.group = group
    }
}
