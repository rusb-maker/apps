import Foundation
import SwiftData

@Model
class RecordingSession {
    var id: UUID
    var rawTranscript: String
    var extractedPhrasesData: Data
    var createdAt: Date
    var duration: TimeInterval

    var extractedPhrases: [ExtractedPhrase] {
        get {
            (try? JSONDecoder().decode([ExtractedPhrase].self, from: extractedPhrasesData)) ?? []
        }
        set {
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
    var verb: String
    var contextSentence: String
    var verbType: VerbType
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        phrase: String,
        verb: String,
        contextSentence: String,
        verbType: VerbType,
        isSelected: Bool = true
    ) {
        self.id = id
        self.phrase = phrase
        self.verb = verb
        self.contextSentence = contextSentence
        self.verbType = verbType
        self.isSelected = isSelected
    }
}
