import Foundation

struct StudyIntervals {
    var againMinutes: Int
    var hardMinutes: Int
    var goodDays: Int
    var easyDays: Int

    static let `default` = StudyIntervals(againMinutes: 0, hardMinutes: 2, goodDays: 1, easyDays: 2)

    static func fromUserDefaults() -> StudyIntervals {
        let defaults = UserDefaults.standard
        return StudyIntervals(
            againMinutes: defaults.object(forKey: "study_again_minutes") as? Int ?? 0,
            hardMinutes: defaults.object(forKey: "study_hard_minutes") as? Int ?? 2,
            goodDays: defaults.object(forKey: "study_good_days") as? Int ?? 1,
            easyDays: defaults.object(forKey: "study_easy_days") as? Int ?? 2
        )
    }
}

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
        currentRepetitions: Int,
        intervals: StudyIntervals = .default
    ) -> ReviewResult {
        let grade = max(0, min(5, grade))

        var newInterval: Int
        var newReps: Int
        var nextDate: Date

        if grade >= 4 {
            // Good / Easy — interval in days
            if currentRepetitions == 0 {
                newInterval = grade == 5 ? intervals.easyDays : intervals.goodDays
            } else {
                let base = Double(max(currentInterval, 1)) * currentEaseFactor
                let multiplier = grade == 5 ? 1.3 : 1.0
                newInterval = max(1, Int(round(base * multiplier)))
            }
            newReps = currentRepetitions + 1
            nextDate = Calendar.current.date(byAdding: .day, value: newInterval, to: Date()) ?? Date()
        } else if grade == 3 {
            // Hard — short interval in minutes, keep repetitions progressing
            newInterval = 0
            newReps = currentRepetitions + 1
            nextDate = Calendar.current.date(byAdding: .minute, value: intervals.hardMinutes, to: Date()) ?? Date()
        } else {
            // Again — shortest interval in minutes, reset repetitions
            newInterval = 0
            newReps = 0
            nextDate = Calendar.current.date(byAdding: .minute, value: intervals.againMinutes, to: Date()) ?? Date()
        }

        var newEF = currentEaseFactor + (0.1 - Double(5 - grade) * (0.08 + Double(5 - grade) * 0.02))
        newEF = max(1.3, newEF)

        return ReviewResult(
            newEaseFactor: newEF,
            newInterval: newInterval,
            newRepetitions: newReps,
            nextReviewDate: nextDate
        )
    }

    /// Returns a human-readable interval preview for a grade button
    static func previewInterval(
        grade: Int,
        currentEaseFactor: Double,
        currentInterval: Int,
        currentRepetitions: Int,
        intervals: StudyIntervals = .default
    ) -> String {
        if grade < 3 {
            return formatMinutes(intervals.againMinutes)
        }

        if grade == 3 {
            return formatMinutes(intervals.hardMinutes)
        }

        // Good / Easy — days
        let days: Int
        if currentRepetitions == 0 {
            days = grade == 5 ? intervals.easyDays : intervals.goodDays
        } else {
            let base = Double(max(currentInterval, 1)) * currentEaseFactor
            let multiplier = grade == 5 ? 1.3 : 1.0
            days = max(1, Int(round(base * multiplier)))
        }

        if days < 30 { return "\(days)d" }
        if days < 365 { return "\(days / 30)mo" }
        return String(format: "%.1fy", Double(days) / 365.0)
    }

    private static func formatMinutes(_ mins: Int) -> String {
        if mins == 0 { return "0m" }
        if mins < 60 { return "\(mins)m" }
        let hours = mins / 60
        let remainMins = mins % 60
        if remainMins == 0 { return "\(hours)h" }
        return "\(hours)h\(remainMins)m"
    }
}
