import Foundation

final class LessonCatalog: Sendable {
    static let spanish = LessonCatalog(language: .spanish)
    static let english = LessonCatalog(language: .english)

    static func catalog(for language: AppLanguage) -> LessonCatalog {
        switch language {
        case .spanish: spanish
        case .english: english
        }
    }

    let language: AppLanguage
    private let lessons: [Lesson]
    private let lessonsByLevel: [Level: [Lesson]]
    private let lessonById: [String: Lesson]

    init(language: AppLanguage) {
        self.language = language
        var all: [Lesson] = []
        for level in language.levels {
            let fileName = language.lessonFileName(for: level)
            guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
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
