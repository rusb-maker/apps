import Foundation

enum CardType: String, Codable, CaseIterable, Identifiable {
    case vocabulary
    case conjugation
    case phrase
    case fillBlank

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vocabulary: "Словарь"
        case .conjugation: "Спряжение"
        case .phrase: "Фраза"
        case .fillBlank: "Заполни пропуск"
        }
    }

    var icon: String {
        switch self {
        case .vocabulary: "textbook"
        case .conjugation: "arrow.triangle.branch"
        case .phrase: "text.bubble"
        case .fillBlank: "pencil.line"
        }
    }
}
