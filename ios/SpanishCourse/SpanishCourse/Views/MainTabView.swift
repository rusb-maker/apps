import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("app_theme") private var themeName: String = AppTheme.system.rawValue
    @AppStorage("app_language") private var languageName: String = AppLanguage.spanish.rawValue

    private var theme: AppTheme {
        AppTheme(rawValue: themeName) ?? .system
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageName) ?? .spanish
    }

    var body: some View {
        TabView {
            Tab("Уроки", systemImage: "book.fill") {
                NavigationStack {
                    LevelListView()
                }
            }

            Tab("Карточки", systemImage: "rectangle.stack.fill") {
                NavigationStack {
                    CardGroupsView()
                }
            }

            Tab("Тренажёры", systemImage: "dumbbell.fill") {
                NavigationStack {
                    DrillsListView()
                }
            }

            Tab("Настройки", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(theme.accentColor)
        .preferredColorScheme(theme.colorScheme)
        .environment(\.appTheme, theme)
        .environment(\.appLanguage, language)
        .task {
            StatsService.shared.load(context: modelContext)
            SpanishTTS.shared.switchLanguage(language)
            cleanupTrashedItems()
        }
        .onChange(of: languageName) { _, newValue in
            if let lang = AppLanguage(rawValue: newValue) {
                SpanishTTS.shared.switchLanguage(lang)
            }
        }
    }

    private func cleanupTrashedItems() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<Card>(
            predicate: #Predicate<Card> { $0.isTrashed && $0.trashedAt != nil }
        )
        guard let trashedCards = try? modelContext.fetch(descriptor) else { return }
        for card in trashedCards {
            if let trashedAt = card.trashedAt, trashedAt < cutoff {
                modelContext.delete(card)
            }
        }
        try? modelContext.save()
    }
}
