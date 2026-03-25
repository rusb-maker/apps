import Foundation

enum SourceLanguage: String, CaseIterable, Identifiable {
    case english
    case spanish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: "English"
        case .spanish: "Spanish"
        }
    }

    /// Locale identifier for SFSpeechRecognizer
    var speechLocaleIdentifier: String {
        switch self {
        case .english: "en-US"
        case .spanish: "es-ES"
        }
    }

    /// Used in LLM prompts: "English language tutor helping a Russian-speaking student"
    var tutorDescription: String {
        switch self {
        case .english: "an English language tutor helping a Russian-speaking student"
        case .spanish: "a Spanish language tutor helping a Russian-speaking student"
        }
    }

    /// Used in LLM extraction prompt to describe what to extract
    var expressionsDescription: String {
        switch self {
        case .english: "English expressions, phrasal verbs, idioms, and collocations"
        case .spanish: "Spanish expressions, verb phrases, idioms, and collocations"
        }
    }

    /// Placeholder for text input extract mode
    var textInputPlaceholder: String {
        switch self {
        case .english: "Paste or type English text here\u{2026}"
        case .spanish: "Paste or type Spanish text here\u{2026}"
        }
    }

    /// Example prompt for generate mode
    var generateExample: String {
        switch self {
        case .english: "Example: phrasal verbs with take, sentences up to 5 words"
        case .spanish: "Example: verbos con preposici\u{00F3}n, frases de hasta 5 palabras"
        }
    }
}
