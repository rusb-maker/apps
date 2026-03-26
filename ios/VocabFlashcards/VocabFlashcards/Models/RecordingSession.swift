import Foundation
import SwiftData

@Model
class RecordingSession {
    var id: UUID
    var rawTranscript: String
    var extractedPhrasesData: Data
    var createdAt: Date
    var duration: TimeInterval

    // Soft-delete
    var isTrashed: Bool = false
    var trashedAt: Date?

    // Transient cache — avoids re-decoding JSON on every access
    @Transient private var _cachedPhrases: [ExtractedPhrase]?

    var extractedPhrases: [ExtractedPhrase] {
        get {
            if let cached = _cachedPhrases { return cached }
            let decoded = (try? JSONDecoder().decode([ExtractedPhrase].self, from: extractedPhrasesData)) ?? []
            _cachedPhrases = decoded
            return decoded
        }
        set {
            _cachedPhrases = newValue
            extractedPhrasesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(
        id: UUID = UUID(),
        rawTranscript: String,
        extractedPhrases: [ExtractedPhrase] = [],
        createdAt: Date = Date(),
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.rawTranscript = rawTranscript
        self.extractedPhrasesData = (try? JSONEncoder().encode(extractedPhrases)) ?? Data()
        self.createdAt = createdAt
        self.duration = duration
    }
}

struct ExtractedPhrase: Codable, Identifiable {
    var id: UUID
    var phrase: String
    var translation: String
    var isSelected: Bool
    var cefrLevel: String?

    // Legacy fields kept for backward compatibility with stored data
    var verb: String?
    var contextSentence: String?
    var verbType: VerbType?

    init(
        id: UUID = UUID(),
        phrase: String,
        translation: String,
        isSelected: Bool = true,
        cefrLevel: String? = nil
    ) {
        self.id = id
        self.phrase = phrase
        self.translation = translation
        self.isSelected = isSelected
        self.cefrLevel = cefrLevel
    }
}
