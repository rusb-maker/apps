import Foundation
import SwiftData

@Model
class UserStats {
    var id: UUID = UUID()

    // Streak
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDate: Date?
    var streakFreezeCount: Int = 1

    // Daily goal
    var dailyGoalMinutes: Int = 10
    var todayStudySeconds: Int = 0
    var todayLastReset: Date?

    // Totals
    var totalStudySeconds: Int = 0
    var totalCardsStudied: Int = 0
    var totalLessonsRead: Int = 0
    var totalTestsPassed: Int = 0
    var xpTotal: Int = 0

    // Dates
    var joinDate: Date = Date()

    init() {}
}
