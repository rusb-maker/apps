import SwiftUI

enum Level: String, CaseIterable, Identifiable, Codable {
    case a0 = "A0"
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a0: "A0 — Абсолютный новичок"
        case .a1: "A1 — Начинающий"
        case .a2: "A2 — Элементарный"
        case .b1: "B1 — Средний"
        case .b2: "B2 — Выше среднего"
        }
    }

    var shortName: String {
        switch self {
        case .a0: "Новичок"
        case .a1: "Начинающий"
        case .a2: "Элементарный"
        case .b1: "Средний"
        case .b2: "Выше среднего"
        }
    }

    var lessonFileName: String {
        switch self {
        case .a0: "a0_lessons"
        case .a1: "a1_lessons"
        case .a2: "a2_lessons"
        case .b1: "b1_lessons"
        case .b2: "b2_lessons"
        }
    }

    var color: Color {
        switch self {
        case .a0: .green
        case .a1: .blue
        case .a2: .purple
        case .b1: .orange
        case .b2: .red
        }
    }

    var icon: String {
        switch self {
        case .a0: "leaf.fill"
        case .a1: "book.fill"
        case .a2: "graduationcap.fill"
        case .b1: "flame.fill"
        case .b2: "star.fill"
        }
    }
}
