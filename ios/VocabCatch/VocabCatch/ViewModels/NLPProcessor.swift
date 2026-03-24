import NaturalLanguage

class NLPProcessor {

    private let phrasalVerbs: Set<String> = {
        guard let url = Bundle.main.url(forResource: "phrasal_verbs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let verbs = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(verbs.map { $0.lowercased() })
    }()

    func extractPhrases(from text: String) -> [ExtractedPhrase] {
        let sentences = splitIntoSentences(text)
        var results: [ExtractedPhrase] = []

        for sentence in sentences {
            let foundPhrasals = findPhrasalVerbs(in: sentence)
            for phrasal in foundPhrasals {
                let context = extractContext(around: phrasal, in: sentence, windowSize: 5...8)
                results.append(ExtractedPhrase(
                    phrase: phrasal,
                    verb: phrasal,
                    contextSentence: context,
                    verbType: .phrasal
                ))
            }

            if foundPhrasals.isEmpty {
                let verbs = findRegularVerbs(in: sentence)
                for verb in verbs {
                    let context = extractContext(around: verb, in: sentence, windowSize: 5...8)
                    results.append(ExtractedPhrase(
                        phrase: verb,
                        verb: verb,
                        contextSentence: context,
                        verbType: .regular
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Sentence Splitting

    private func splitIntoSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines))
            return true
        }
        return sentences
    }

    // MARK: - Find Phrasal Verbs

    private func findPhrasalVerbs(in sentence: String) -> [String] {
        let words = sentence.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var found: [String] = []

        for i in 0..<words.count {
            // Three-word phrasal verbs first (longer match wins)
            if i + 2 < words.count {
                let triple = "\(words[i]) \(words[i+1]) \(words[i+2])"
                let cleanTriple = triple.filter { $0.isLetter || $0 == " " }
                if phrasalVerbs.contains(cleanTriple) {
                    found.append(cleanTriple)
                    continue
                }
            }
            // Two-word phrasal verbs
            if i + 1 < words.count {
                let pair = "\(words[i]) \(words[i+1])"
                let cleanPair = pair.filter { $0.isLetter || $0 == " " }
                if phrasalVerbs.contains(cleanPair) {
                    found.append(cleanPair)
                }
            }
        }

        return found
    }

    // MARK: - Find Regular Verbs (POS Tagging)

    private func findRegularVerbs(in sentence: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = sentence
        var verbs: [String] = []

        let auxiliaries: Set<String> = [
            "is", "am", "are", "was", "were",
            "be", "been", "being", "have", "has", "had",
            "do", "does", "did", "will", "would", "shall",
            "should", "can", "could", "may", "might", "must"
        ]

        tagger.enumerateTags(
            in: sentence.startIndex..<sentence.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, range in
            if tag == .verb {
                let word = String(sentence[range])
                if !auxiliaries.contains(word.lowercased()) {
                    verbs.append(word)
                }
            }
            return true
        }

        return verbs
    }

    // MARK: - Extract Context Window

    private func extractContext(
        around target: String,
        in sentence: String,
        windowSize: ClosedRange<Int>
    ) -> String {
        let words = sentence
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if words.count <= windowSize.upperBound {
            return words.joined(separator: " ")
        }

        let targetWords = target.lowercased().components(separatedBy: " ")
        guard let startIdx = words.indices.first(where: { idx in
            let remaining = words.count - idx
            guard remaining >= targetWords.count else { return false }
            return (0..<targetWords.count).allSatisfy { offset in
                words[idx + offset].lowercased()
                    .filter { $0.isLetter }
                    .hasPrefix(targetWords[offset])
            }
        }) else {
            return words.prefix(windowSize.upperBound).joined(separator: " ")
        }

        let targetEnd = startIdx + targetWords.count
        let desiredTotal = windowSize.upperBound
        let contextBefore = max(0, (desiredTotal - targetWords.count) / 2)
        let windowStart = max(0, startIdx - contextBefore)
        let windowEnd = min(words.count, windowStart + desiredTotal)

        return words[windowStart..<windowEnd].joined(separator: " ")
    }
}
