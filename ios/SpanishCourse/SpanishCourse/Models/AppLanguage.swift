import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case spanish
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spanish: "Испанский"
        case .english: "Английский"
        }
    }

    var flag: String {
        switch self {
        case .spanish: "🇪🇸"
        case .english: "🇬🇧"
        }
    }

    var subtitle: String {
        switch self {
        case .spanish: "A0 — B2 • Общий курс"
        case .english: "B2 — C1 • Business IT"
        }
    }

    var levels: [Level] {
        switch self {
        case .spanish: [.a0, .a1, .a2, .b1, .b2]
        case .english: [.b2, .c1]
        }
    }

    var ttsLanguage: String {
        switch self {
        case .spanish: "es-ES"
        case .english: "en-GB"
        }
    }

    /// Lesson file prefix: "a0_lessons" for spanish, "en_b2_lessons" for english
    func lessonFileName(for level: Level) -> String {
        switch self {
        case .spanish:
            return "\(level.rawValue.lowercased())_lessons"
        case .english:
            return "en_\(level.rawValue.lowercased())_lessons"
        }
    }

    /// Level display name customized per language
    func levelDisplayName(for level: Level) -> String {
        if self == .english {
            switch level {
            case .b2: return "B2 — Business IT (Upper-Intermediate)"
            case .c1: return "C1 — Business IT (Advanced)"
            default: return level.displayName
            }
        }
        return level.displayName
    }
}

// MARK: - Environment

struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .spanish
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
