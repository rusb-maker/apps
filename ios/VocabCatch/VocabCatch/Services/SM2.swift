import Foundation

struct SM2 {

    struct ReviewResult {
        let newEaseFactor: Double
        let newInterval: Int
        let newRepetitions: Int
        let nextReviewDate: Date
    }

    /// grade: 0 = complete failure, 1 = wrong, 2 = wrong but remembered,
    ///        3 = correct with difficulty, 4 = correct, 5 = perfect
    static func review(
        grade: Int,
        currentEaseFactor: Double,
        currentInterval: Int,
        currentRepetitions: Int
    ) -> ReviewResult {
        let grade = max(0, min(5, grade))

        var newInterval: Int
        var newReps: Int

        if grade >= 3 {
            switch currentRepetitions {
            case 0:  newInterval = 1
            case 1:  newInterval = 6
            default: newInterval = Int(round(Double(currentInterval) * currentEaseFactor))
            }
            newReps = currentRepetitions + 1
        } else {
            newInterval = 1
            newReps = 0
        }

        var newEF = currentEaseFactor + (0.1 - Double(5 - grade) * (0.08 + Double(5 - grade) * 0.02))
        newEF = max(1.3, newEF)

        let nextDate = Calendar.current.date(
            byAdding: .day,
            value: newInterval,
            to: Date()
        ) ?? Date()

        return ReviewResult(
            newEaseFactor: newEF,
            newInterval: newInterval,
            newRepetitions: newReps,
            nextReviewDate: nextDate
        )
    }
}
