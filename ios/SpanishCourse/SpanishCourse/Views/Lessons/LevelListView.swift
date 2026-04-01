import SwiftUI

struct LevelListView: View {
    @Environment(\.appLanguage) private var language
    @AppStorage("app_language") private var languageName: String = AppLanguage.spanish.rawValue

    private var catalog: LessonCatalog {
        LessonCatalog.catalog(for: language)
    }

    var body: some View {
        List {
            // Language switcher
            Section {
                HStack(spacing: 12) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button {
                            languageName = lang.rawValue
                        } label: {
                            VStack(spacing: 4) {
                                Text(lang.flag)
                                    .font(.title)
                                Text(lang.displayName)
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(lang.rawValue == languageName ? .blue.opacity(0.15) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(lang.rawValue == languageName ? .blue : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Levels
            ForEach(language.levels) { level in
                NavigationLink(value: level) {
                    LevelRowView(
                        level: level,
                        lessonCount: catalog.lessons(for: level).count,
                        language: language
                    )
                }
            }
        }
        .navigationTitle(language == .spanish ? "Испанский" : "English IT")
        .navigationDestination(for: Level.self) { level in
            LessonListView(level: level)
        }
    }
}

struct LevelRowView: View {
    let level: Level
    let lessonCount: Int
    var language: AppLanguage = .spanish

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: level.icon)
                .font(.title)
                .foregroundStyle(level.color)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(language.levelDisplayName(for: level))
                    .font(.headline)
                Text("\(lessonCount) уроков")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
