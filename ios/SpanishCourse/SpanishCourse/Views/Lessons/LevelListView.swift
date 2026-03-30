import SwiftUI

struct LevelListView: View {
    var body: some View {
        List {
            ForEach(Level.allCases) { level in
                NavigationLink(value: level) {
                    LevelRowView(
                        level: level,
                        lessonCount: LessonCatalog.shared.lessons(for: level).count
                    )
                }
            }
        }
        .navigationTitle("Испанский")
        .themed()
        .navigationDestination(for: Level.self) { level in
            LessonListView(level: level)
        }
    }
}

struct LevelRowView: View {
    let level: Level
    let lessonCount: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: level.icon)
                .font(.title)
                .foregroundStyle(level.color)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(level.displayName)
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
