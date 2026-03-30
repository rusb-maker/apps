import Foundation

final class LessonCatalog: Sendable {
    static let shared = LessonCatalog()

    private let lessons: [Lesson]
    private let lessonsByLevel: [Level: [Lesson]]
    private let lessonById: [String: Lesson]

    init() {
        var all: [Lesson] = []
        for level in Level.allCases {
            guard let url = Bundle.main.url(forResource: level.lessonFileName, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let lessons = try? JSONDecoder().decode([Lesson].self, from: data) else {
                continue
            }
            all.append(contentsOf: lessons)
        }
        self.lessons = all.sorted { ($0.level.rawValue, $0.order) < ($1.level.rawValue, $1.order) }
        self.lessonsByLevel = Dictionary(grouping: self.lessons, by: \.level)
        self.lessonById = Dictionary(uniqueKeysWithValues: self.lessons.map { ($0.id, $0) })
    }

    func lessons(for level: Level) -> [Lesson] {
        lessonsByLevel[level] ?? []
    }

    func lesson(id: String) -> Lesson? {
        lessonById[id]
    }

    var allLessons: [Lesson] { lessons }
}
