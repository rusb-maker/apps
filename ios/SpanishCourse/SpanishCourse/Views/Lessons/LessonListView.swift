import SwiftUI

struct LessonListView: View {
    let level: Level
    @Environment(\.appLanguage) private var language

    private var lessons: [Lesson] {
        LessonCatalog.catalog(for: language).lessons(for: level)
    }

    var body: some View {
        List {
            ForEach(lessons) { lesson in
                NavigationLink(value: lesson) {
                    LessonRowView(lesson: lesson)
                }
            }
        }
        .navigationTitle(language.levelDisplayName(for: level))
        .themed()
        .navigationDestination(for: Lesson.self) { lesson in
            LessonDetailView(lesson: lesson)
        }
    }
}

struct LessonRowView: View {
    let lesson: Lesson

    var body: some View {
        HStack(spacing: 12) {
            Text("\(lesson.order)")
                .font(.title3.bold())
                .foregroundStyle(lesson.level.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.headline)
                Text(lesson.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
