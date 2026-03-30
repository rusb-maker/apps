import SwiftUI
import SwiftData

@Observable
@MainActor
class LessonDetailViewModel {
    let lesson: Lesson
    var cards: [Card] = []
    var progress: LessonProgress?
    var dueCardCount = 0

    init(lesson: Lesson) {
        self.lesson = lesson
    }

    func loadData(context: ModelContext) {
        loadProgress(context: context)
        seedDefaultCardsIfNeeded(context: context)
        loadCards(context: context)
    }

    func loadCards(context: ModelContext) {
        let lessonId = lesson.id
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.lessonId == lessonId && !$0.isTrashed },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        cards = (try? context.fetch(descriptor)) ?? []

        let now = Date()
        dueCardCount = cards.filter { $0.nextReviewDate <= now }.count
    }

    func loadProgress(context: ModelContext) {
        let lessonId = lesson.id
        let descriptor = FetchDescriptor<LessonProgress>(
            predicate: #Predicate<LessonProgress> { $0.lessonId == lessonId }
        )
        progress = try? context.fetch(descriptor).first
    }

    func markAsRead(context: ModelContext) {
        let wasAlreadyRead = progress?.isRead ?? false
        if let progress {
            progress.isRead = true
            progress.readAt = Date()
        } else {
            let newProgress = LessonProgress(lessonId: lesson.id, isRead: true)
            newProgress.readAt = Date()
            context.insert(newProgress)
            self.progress = newProgress
        }
        try? context.save()
        if !wasAlreadyRead {
            StatsService.shared.recordLessonRead(context: context)
        }
    }

    private func seedDefaultCardsIfNeeded(context: ModelContext) {
        guard progress?.cardsGenerated != true else { return }
        guard !lesson.defaultCards.isEmpty else { return }

        // Check if cards already exist for this lesson
        let lessonId = lesson.id
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.lessonId == lessonId }
        )
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for lessonCard in lesson.defaultCards {
            let card = Card(
                lessonId: lesson.id,
                front: lessonCard.front,
                back: lessonCard.back,
                contextSentence: lessonCard.context ?? "",
                cardType: lessonCard.type
            )
            context.insert(card)
        }

        if let progress {
            progress.cardsGenerated = true
        } else {
            let newProgress = LessonProgress(lessonId: lesson.id, cardsGenerated: true)
            context.insert(newProgress)
            self.progress = newProgress
        }

        try? context.save()
    }

    func resetCards(context: ModelContext) {
        for card in cards {
            card.easeFactor = 2.5
            card.interval = 0
            card.repetitions = 0
            card.nextReviewDate = Date()
            card.graduated = false
        }
        try? context.save()
        loadCards(context: context)
    }

    func deleteCard(_ card: Card, context: ModelContext) {
        card.isTrashed = true
        card.trashedAt = Date()
        try? context.save()
        loadCards(context: context)
    }

    var masteredCount: Int {
        cards.filter { $0.repetitions >= 3 }.count
    }

    var masteryPercentage: Double {
        guard !cards.isEmpty else { return 0 }
        return Double(masteredCount) / Double(cards.count)
    }

    var allGraduated: Bool {
        !cards.isEmpty && cards.allSatisfy { $0.graduated }
    }
}
