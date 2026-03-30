import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class StatsService {
    static let shared = StatsService()

    private var stats: UserStats?
    private var sessionStartTime: Date?

    // MARK: - Public read

    var currentStreak: Int { stats?.currentStreak ?? 0 }
    var longestStreak: Int { stats?.longestStreak ?? 0 }
    var xpTotal: Int { stats?.xpTotal ?? 0 }
    var todayMinutes: Int { (stats?.todayStudySeconds ?? 0) / 60 }
    var dailyGoalMinutes: Int { stats?.dailyGoalMinutes ?? 10 }
    var dailyGoalReached: Bool { todayMinutes >= dailyGoalMinutes }
    var totalCardsStudied: Int { stats?.totalCardsStudied ?? 0 }
    var totalLessonsRead: Int { stats?.totalLessonsRead ?? 0 }
    var totalTestsPassed: Int { stats?.totalTestsPassed ?? 0 }
    var totalStudyHours: Double { Double(stats?.totalStudySeconds ?? 0) / 3600.0 }
    var joinDate: Date { stats?.joinDate ?? Date() }
    var streakFreezeCount: Int { stats?.streakFreezeCount ?? 0 }
    var todayProgress: Double {
        guard dailyGoalMinutes > 0 else { return 1 }
        return min(1.0, Double(todayMinutes) / Double(dailyGoalMinutes))
    }

    // MARK: - Setup

    func load(context: ModelContext) {
        let descriptor = FetchDescriptor<UserStats>()
        stats = try? context.fetch(descriptor).first
        if stats == nil {
            let newStats = UserStats()
            context.insert(newStats)
            try? context.save()
            stats = newStats
        }
        resetTodayIfNeeded()
        updateStreak()
        try? context.save()
    }

    // MARK: - Actions

    func startSession() {
        sessionStartTime = Date()
    }

    func endSession(context: ModelContext) {
        guard let start = sessionStartTime else { return }
        let seconds = Int(Date().timeIntervalSince(start))
        guard seconds > 0 else { return }
        sessionStartTime = nil

        resetTodayIfNeeded()
        stats?.todayStudySeconds += seconds
        stats?.totalStudySeconds += seconds
        updateStreak()
        try? context.save()
    }

    func recordCardStudied(correct: Bool, context: ModelContext) {
        stats?.totalCardsStudied += 1
        if correct {
            addXP(2, context: context)
        }
    }

    func recordLessonRead(context: ModelContext) {
        stats?.totalLessonsRead += 1
        addXP(10, context: context)
        markTodayActive(context: context)
    }

    func recordTestPassed(context: ModelContext) {
        stats?.totalTestsPassed += 1
        addXP(50, context: context)
        markTodayActive(context: context)
    }

    func useStreakFreeze(context: ModelContext) {
        guard let s = stats, s.streakFreezeCount > 0 else { return }
        s.streakFreezeCount -= 1
        // Pretend yesterday was active
        s.lastActiveDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        updateStreak()
        try? context.save()
    }

    func setDailyGoal(_ minutes: Int, context: ModelContext) {
        stats?.dailyGoalMinutes = max(1, min(60, minutes))
        try? context.save()
    }

    // MARK: - Private

    private func addXP(_ amount: Int, context: ModelContext) {
        stats?.xpTotal += amount
        markTodayActive(context: context)
    }

    private func markTodayActive(context: ModelContext) {
        resetTodayIfNeeded()
        let today = Calendar.current.startOfDay(for: Date())
        let lastActive = stats?.lastActiveDate.flatMap { Calendar.current.startOfDay(for: $0) }

        if lastActive != today {
            stats?.lastActiveDate = Date()
            updateStreak()

            // Streak day bonus (use updated streak value)
            let updatedStreak = stats?.currentStreak ?? 0
            if updatedStreak > 0 {
                stats?.xpTotal += 5 * min(updatedStreak, 10)
            }

            // Refresh weekly freeze
            if Calendar.current.component(.weekday, from: Date()) == 2 { // Monday
                stats?.streakFreezeCount = min((stats?.streakFreezeCount ?? 0) + 1, 2)
            }
        }
        try? context.save()
    }

    private func updateStreak() {
        guard let s = stats else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        guard let lastActive = s.lastActiveDate else {
            s.currentStreak = 0
            return
        }

        let lastDay = cal.startOfDay(for: lastActive)
        let diff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0

        if diff == 0 {
            // Same day — streak already counted
        } else if diff == 1 {
            // Consecutive day
            s.currentStreak += 1
        } else {
            // Gap > 1 day — streak broken
            s.currentStreak = 0
        }

        s.longestStreak = max(s.longestStreak, s.currentStreak)
    }

    private func resetTodayIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastReset = stats?.todayLastReset.flatMap { Calendar.current.startOfDay(for: $0) }
        if lastReset != today {
            stats?.todayStudySeconds = 0
            stats?.todayLastReset = Date()
        }
    }
}
