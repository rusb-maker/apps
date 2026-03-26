import SwiftData
import Foundation

@MainActor
@Observable
class StudyViewModel {
    var cards: [Card] = []
    var currentIndex = 0
    var isShowingAnswer = false
    var sessionComplete = false

    // Session stats
    var correctCount = 0
    var incorrectCount = 0
    var reviewedCount: Int { correctCount + incorrectCount }

    // Cards that were graded "Again" — re-queued for this session
    private var failedCards: [Card] = []

    // Configurable intervals from settings
    var intervals: StudyIntervals = .fromUserDefaults()

    var currentCard: Card? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var totalCards: Int { cards.count }
    var progress: Double {
        guard totalCards > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCards)
    }

    /// Next review date across all cards (for showing on empty state)
    var nextDueDate: Date? {
        _nextDueDate
    }
    private var _nextDueDate: Date?

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

    func loadDueCards(context: ModelContext) {
        intervals = .fromUserDefaults()
        let now = Date()
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.nextReviewDate <= now && !$0.isTrashed },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        let allDue = (try? context.fetch(descriptor)) ?? []

        // Filter to cards in study-enabled, non-trashed groups
        cards = allDue.filter { card in
            guard let group = card.group else { return true }
            return group.isStudyEnabled && !group.isTrashed
        }

        failedCards = []
        currentIndex = 0
        correctCount = 0
        incorrectCount = 0
        sessionComplete = false
        isShowingAnswer = false

        // Find next due date for empty state
        if cards.isEmpty {
            loadNextDueDate(context: context)
        }
    }

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
            // Re-queue failed card for later in this session
            failedCards.append(card)
        }

        do {
            try context.save()
        } catch {
            print("[StudyViewModel] Failed to save grade: \(error)")
        }
        advance()
    }

    private func advance() {
        currentIndex += 1
        isShowingAnswer = false
        if currentIndex >= cards.count {
            if !failedCards.isEmpty {
                // Append failed cards for another round
                let requeue = failedCards
                failedCards = []
                cards.append(contentsOf: requeue)
            } else {
                sessionComplete = true
            }
        }
    }

    private func loadNextDueDate(context: ModelContext) {
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { !$0.isTrashed },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        guard let allCards = try? context.fetch(descriptor) else {
            _nextDueDate = nil
            return
        }

        _nextDueDate = allCards
            .first { card in
                guard let group = card.group else { return true }
                return group.isStudyEnabled && !group.isTrashed
            }?
            .nextReviewDate
    }
}
