import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appTheme) private var theme
    private var stats: StatsService { StatsService.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Streak card
                streakCard

                // Daily goal
                dailyGoalCard

                // Stats grid
                statsGrid

                // XP
                xpCard

                // Info
                infoCard
            }
            .padding()
        }
        .navigationTitle("Прогресс")
        .background(theme.isCustom ? theme.pageBackground : Color.clear)
        .onAppear {
            stats.load(context: modelContext)
        }
    }

    // MARK: - Streak

    private var streakCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: stats.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 48))
                    .foregroundStyle(streakColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(stats.currentStreak)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(streakColor)
                    Text(streakLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Рекорд")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(stats.longestStreak)")
                        .font(.title2.bold())
                        .foregroundStyle(.orange)
                }
            }

            if stats.currentStreak == 0 {
                Text("Начни учиться сегодня, чтобы запустить серию!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if stats.currentStreak >= 7 {
                Text(streakMotivation)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            // Streak freeze
            if stats.streakFreezeCount > 0 {
                HStack {
                    Image(systemName: "snowflake")
                        .foregroundStyle(.blue)
                    Text("Заморозка: \(stats.streakFreezeCount) шт.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Использовать") {
                        stats.useStreakFreeze(context: modelContext)
                    }
                    .font(.caption)
                    .disabled(stats.currentStreak == 0)
                }
            }
        }
        .padding()
        .background(.fill.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Daily Goal

    private var dailyGoalCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Сегодня")
                    .font(.headline)
                Spacer()
                if stats.dailyGoalReached {
                    Label("Цель!", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            ProgressView(value: stats.todayProgress)
                .tint(stats.dailyGoalReached ? .green : .blue)
                .frame(height: 8)
                .clipShape(Capsule())

            HStack {
                Text("\(stats.todayMinutes) мин")
                    .font(.title3.bold())
                Spacer()
                Text("Цель: \(stats.dailyGoalMinutes) мин")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.fill.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile(icon: "rectangle.stack.fill", value: "\(stats.totalCardsStudied)", label: "Карточек", color: .blue)
            statTile(icon: "book.fill", value: "\(stats.totalLessonsRead)", label: "Уроков", color: .green)
            statTile(icon: "checkmark.seal.fill", value: "\(stats.totalTestsPassed)", label: "Тестов", color: .purple)
            statTile(icon: "clock.fill", value: String(format: "%.1f ч", stats.totalStudyHours), label: "Время", color: .orange)
        }
    }

    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.fill.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - XP

    private var xpCard: some View {
        HStack {
            Image(systemName: "star.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading) {
                Text("\(stats.xpTotal) XP")
                    .font(.title3.bold())
                Text("Очки опыта")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(xpLevel)
                .font(.headline)
                .foregroundStyle(.yellow)
        }
        .padding()
        .background(.fill.opacity(0.7), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Info

    private var infoCard: some View {
        HStack {
            Text("Учишь с \(stats.joinDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            let days = Calendar.current.dateComponents([.day], from: stats.joinDate, to: Date()).day ?? 0
            Text("\(days) дней в приложении")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Helpers

    private var streakColor: Color {
        if stats.currentStreak >= 30 { return .red }
        if stats.currentStreak >= 7 { return .orange }
        if stats.currentStreak > 0 { return .yellow }
        return .gray
    }

    private var streakLabel: String {
        let n = stats.currentStreak
        if n == 0 { return "дней" }
        let mod10 = n % 10
        let mod100 = n % 100
        if mod100 >= 11 && mod100 <= 19 { return "дней подряд" }
        if mod10 == 1 { return "день подряд" }
        if mod10 >= 2 && mod10 <= 4 { return "дня подряд" }
        return "дней подряд"
    }

    private var streakMotivation: String {
        let n = stats.currentStreak
        if n >= 365 { return "Невероятно! Год без пропусков!" }
        if n >= 100 { return "Легенда! 100+ дней!" }
        if n >= 30 { return "Отличная привычка! 30+ дней!" }
        if n >= 7 { return "Неделя подряд! Так держать!" }
        return ""
    }

    private var xpLevel: String {
        let xp = stats.xpTotal
        if xp >= 10000 { return "Мастер" }
        if xp >= 5000 { return "Эксперт" }
        if xp >= 2000 { return "Продвинутый" }
        if xp >= 500 { return "Ученик" }
        return "Новичок"
    }
}
