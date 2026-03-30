import Foundation

struct Lesson: Codable, Identifiable, Hashable {
    let id: String
    let level: Level
    let order: Int
    let title: String
    let subtitle: String
    let content: String
    let keyVocabulary: [VocabularyItem]
    let grammarPoints: [String]
    let cardGenerationHints: CardGenerationHints
    let defaultCards: [LessonCard]
}

struct LessonCard: Codable, Hashable {
    let front: String
    let back: String
    let context: String?
    let type: CardType
}

struct VocabularyItem: Codable, Identifiable, Hashable {
    var id: String { spanish }
    let spanish: String
    let russian: String
    let example: String?
}

struct CardGenerationHints: Codable, Hashable {
    let types: [CardType]
    let topicKeywords: [String]
    let defaultCount: Int
    let prompt: String
}
