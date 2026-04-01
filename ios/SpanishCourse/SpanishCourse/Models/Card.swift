import Foundation
import SwiftData

@Model
class Card {
    static let customLessonId = "custom" // legacy
    static func customId(for language: AppLanguage) -> String {
        language == .english ? "custom_en" : "custom"
    }
    var id: UUID
    var lessonId: String
    var front: String
    var back: String
    var contextSentence: String
    var cardType: CardType
    var createdAt: Date

    // SM-2 spaced repetition fields
    var easeFactor: Double
    var interval: Int
    var repetitions: Int
    var nextReviewDate: Date

    // Graduated = passed test, visible in Cards tab
    var graduated: Bool = false

    // Folder for custom cards
    var folderId: UUID?

    // Soft delete
    var isTrashed: Bool = false
    var trashedAt: Date?

    init(
        id: UUID = UUID(),
        lessonId: String,
        front: String,
        back: String = "",
        contextSentence: String = "",
        cardType: CardType = .vocabulary,
        createdAt: Date = Date(),
        easeFactor: Double = 2.5,
        interval: Int = 0,
        repetitions: Int = 0,
        nextReviewDate: Date = Date()
    ) {
        self.id = id
        self.lessonId = lessonId
        self.front = front
        self.back = back
        self.contextSentence = contextSentence
        self.cardType = cardType
        self.createdAt = createdAt
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
    }
}
