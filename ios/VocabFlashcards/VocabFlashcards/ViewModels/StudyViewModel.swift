import SwiftData
import Foundation

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

    var currentCard: Card? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var totalCards: Int { cards.count }
    var progress: Double {
        guard totalCards > 0 else { return 0 }
        return Double(currentIndex) / Double(totalCards)
    }

    func loadDueCards(context: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate { $0.nextReviewDate <= now },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        let allDue = (try? context.fetch(descriptor)) ?? []

        // Filter to only cards in study-enabled groups
        cards = allDue.filter { card in
            guard let group = card.group else { return true }
            return group.isStudyEnabled
        }

        currentIndex = 0
        correctCount = 0
        incorrectCount = 0
        sessionComplete = false
        isShowingAnswer = false
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
            currentRepetitions: card.repetitions
        )

        card.easeFactor = result.newEaseFactor
        card.interval = result.newInterval
        card.repetitions = result.newRepetitions
        card.nextReviewDate = result.nextReviewDate

        if grade >= 3 {
            correctCount += 1
        } else {
            incorrectCount += 1
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
            sessionComplete = true
        }
    }
}
