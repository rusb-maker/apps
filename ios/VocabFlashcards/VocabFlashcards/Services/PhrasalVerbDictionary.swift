import Foundation

struct PhrasalVerbDictionary {
    static let shared = PhrasalVerbDictionary()

    let verbs: Set<String>

    private init() {
        guard let url = Bundle.main.url(forResource: "phrasal_verbs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([String].self, from: data)
        else {
            verbs = []
            return
        }
        verbs = Set(list.map { $0.lowercased() })
    }

    func contains(_ phrase: String) -> Bool {
        verbs.contains(phrase.lowercased())
    }
}
