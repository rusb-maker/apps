import SwiftUI
import SwiftData

@Observable
@MainActor
class StudyViewModel {
    var queue: [Card] = []        // current study queue
    var currentIndex = 0
    var isShowingAnswer = false
    var sessionComplete = false
    var correctCount = 0
    var incorrectCount = 0
    var intervals: StudyIntervals = .fromUserDefaults()

    private var _nextDueDate: Date?

    var currentCard: Card? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var totalCards: Int { queue.count }

    var progress: Double {
        guard totalCards > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCards)
    }

    var reviewedCount: Int { correctCount + incorrectCount }

    var nextDueDate: Date? { _nextDueDate }

    // MARK: - Load

    func loadDueCards(
        context: ModelContext,
        lessonId: String? = nil,
        level: Level? = nil,
        graduatedOnly: Bool = false,
        customOnly: Bool = false,
        folderId: UUID? = nil
    ) {
        let now = Date()
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.nextReviewDate <= now && !$0.isTrashed },
            sortBy: [SortDescriptor(\.nextReviewDate)] // oldest due first (Anki-style)
        )
        var allDue = (try? context.fetch(descriptor)) ?? []

        // Filter by scope
        if customOnly {
            allDue = allDue.filter { $0.lessonId.hasPrefix("custom") && $0.graduated && $0.folderId == folderId }
        } else if let lessonId {
            allDue = allDue.filter { $0.lessonId == lessonId }
        } else if let level {
            let prefix = level.rawValue.lowercased() + "_"
            if graduatedOnly {
                allDue = allDue.filter { $0.lessonId.hasPrefix(prefix) && $0.graduated }
            } else {
                allDue = allDue.filter { $0.lessonId.hasPrefix(prefix) }
            }
        } else if graduatedOnly {
            allDue = allDue.filter { $0.graduated }
        }

        // Apply session limit from settings
        let limit = UserDefaults.standard.integer(forKey: "cards_per_session")
        if limit > 0 && allDue.count > limit {
            queue = Array(allDue.prefix(limit))
        } else {
            queue = allDue
        }

        currentIndex = 0
        isShowingAnswer = false
        sessionComplete = false
        correctCount = 0
        incorrectCount = 0

        // Find next due date for empty state
        if queue.isEmpty {
            let futureDescriptor = FetchDescriptor<Card>(
                predicate: #Predicate<Card> { !$0.isTrashed },
                sortBy: [SortDescriptor(\.nextReviewDate)]
            )
            var futureCards = (try? context.fetch(futureDescriptor)) ?? []
            if customOnly {
                futureCards = futureCards.filter { $0.lessonId.hasPrefix("custom") }
            } else if let lessonId {
                futureCards = futureCards.filter { $0.lessonId == lessonId }
            } else if let level {
                let prefix = level.rawValue.lowercased() + "_"
                futureCards = futureCards.filter { $0.lessonId.hasPrefix(prefix) }
            }
            _nextDueDate = futureCards.first?.nextReviewDate
        }
    }

    // MARK: - Actions

    func showAnswer() {
        isShowingAnswer = true
    }

    func grade(_ grade: Int, context: ModelContext) {
        guard let card = currentCard else { return }

        let result = SM2.review(
            grade: grade,
            currentEaseFactor: card.easeFactor,
            currentInterval: card.interval,
            currentRepetitions: card.repetitions,
            intervals: intervals
        )

        card.easeFactor = result.newEaseFactor
        card.interval = result.newInterval
        card.repetitions = result.newRepetitions
        card.nextReviewDate = result.nextReviewDate

        if grade >= 3 {
            correctCount += 1
        } else {
            incorrectCount += 1
            // "Again" → card goes to end of queue (Anki-style)
            queue.append(card)
        }

        StatsService.shared.recordCardStudied(correct: grade >= 3, context: context)
        try? context.save()
        advance()
    }

    func intervalPreview(for grade: Int) -> String {
        guard let card = currentCard else { return "" }
        return SM2.previewInterval(
            grade: grade,
            currentEaseFactor: card.easeFactor,
            currentInterval: card.interval,
            currentRepetitions: card.repetitions,
            intervals: intervals
        )
    }

    // MARK: - Private

    private func advance() {
        isShowingAnswer = false
        currentIndex += 1

        if currentIndex >= queue.count {
            sessionComplete = true
        }
    }
}
