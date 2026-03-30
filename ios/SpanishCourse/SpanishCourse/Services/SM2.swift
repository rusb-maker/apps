import Foundation

struct StudyIntervals {
    /// All values stored in minutes
    var againMinutes: Int
    var hardMinutes: Int
    var goodMinutes: Int
    var easyMinutes: Int

    static let `default` = StudyIntervals(
        againMinutes: 0,
        hardMinutes: 2,
        goodMinutes: 1440,   // 1 day
        easyMinutes: 2880    // 2 days
    )

    static func fromUserDefaults() -> StudyIntervals {
        let defaults = UserDefaults.standard
        return StudyIntervals(
            againMinutes: defaults.object(forKey: "study_again_minutes") as? Int ?? 0,
            hardMinutes: defaults.object(forKey: "study_hard_minutes") as? Int ?? 2,
            goodMinutes: defaults.object(forKey: "study_good_minutes") as? Int ?? 1440,
            easyMinutes: defaults.object(forKey: "study_easy_minutes") as? Int ?? 2880
        )
    }
}

struct SM2 {

    struct ReviewResult {
        let newEaseFactor: Double
        let newInterval: Int  // in minutes
        let newRepetitions: Int
        let nextReviewDate: Date
    }

    static func review(
        grade: Int,
        currentEaseFactor: Double,
        currentInterval: Int,
        currentRepetitions: Int,
        intervals: StudyIntervals = .default
    ) -> ReviewResult {
        let grade = max(0, min(5, grade))

        var newInterval: Int  // minutes
        var newReps: Int
        var nextDate: Date

        if grade >= 4 {
            let baseMinutes = grade == 5 ? intervals.easyMinutes : intervals.goodMinutes
            if currentRepetitions == 0 {
                newInterval = baseMinutes
            } else {
                let calculated = Double(max(currentInterval, 1)) * currentEaseFactor
                let multiplier = grade == 5 ? 1.3 : 1.0
                // Never less than the configured base interval
                newInterval = max(baseMinutes, Int(round(calculated * multiplier)))
            }
            newReps = currentRepetitions + 1
            nextDate = Calendar.current.date(byAdding: .minute, value: newInterval, to: Date()) ?? Date()
        } else if grade == 3 {
            newInterval = intervals.hardMinutes
            newReps = currentRepetitions + 1
            nextDate = Calendar.current.date(byAdding: .minute, value: intervals.hardMinutes, to: Date()) ?? Date()
        } else {
            newInterval = intervals.againMinutes
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

        let baseMinutes = grade == 5 ? intervals.easyMinutes : intervals.goodMinutes
        let minutes: Int
        if currentRepetitions == 0 {
            minutes = baseMinutes
        } else {
            let calculated = Double(max(currentInterval, 1)) * currentEaseFactor
            let multiplier = grade == 5 ? 1.3 : 1.0
            minutes = max(baseMinutes, Int(round(calculated * multiplier)))
        }

        return formatMinutes(minutes)
    }

    static func formatMinutes(_ mins: Int) -> String {
        if mins == 0 { return "0м" }
        if mins < 60 { return "\(mins)м" }
        if mins < 1440 {
            let h = mins / 60
            let m = mins % 60
            if m == 0 { return "\(h)ч" }
            return "\(h)ч\(m)м"
        }
        let days = mins / 1440
        let rem = mins % 1440
        if rem == 0 { return "\(days)д" }
        let h = rem / 60
        if h > 0 { return "\(days)д\(h)ч" }
        return "\(days)д"
    }
}
