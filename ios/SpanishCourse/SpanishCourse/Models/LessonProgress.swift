import Foundation
import SwiftData

@Model
class LessonProgress {
    var id: UUID
    var lessonId: String
    var isRead: Bool
    var readAt: Date?
    var cardsGenerated: Bool
    var lastStudiedAt: Date?
    var totalStudySessions: Int

    init(
        id: UUID = UUID(),
        lessonId: String,
        isRead: Bool = false,
        cardsGenerated: Bool = false,
        totalStudySessions: Int = 0
    ) {
        self.id = id
        self.lessonId = lessonId
        self.isRead = isRead
        self.cardsGenerated = cardsGenerated
        self.totalStudySessions = totalStudySessions
    }
}
