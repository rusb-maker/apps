import Foundation

struct LLMPhrase: Codable {
    let phrase: String
    let translation: String
}

actor ClaudeAPIService {

    static let shared = ClaudeAPIService()

    private let model = "claude-sonnet-4-20250514"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "anthropic_api_key") ?? ""
    }

    func extractPhrases(from transcript: String) async throws -> [ExtractedPhrase] {
        guard !apiKey.isEmpty else {
            throw ClaudeAPIError.missingAPIKey
        }

        let systemPrompt = """
        You are an English language tutor helping a Russian-speaking student. \
        Analyze the conversation transcript and extract useful English expressions, \
        phrasal verbs, idioms, and collocations worth learning.

        Return a JSON array. Each item has:
        - "phrase": the English expression with enough context to understand usage (5-10 words)
        - "translation": natural Russian translation

        Focus on expressions that are:
        - Non-trivial (skip basic verbs like "is", "have", "go", "get")
        - Useful for intermediate English learners
        - Include enough surrounding words to show how the expression is used

        Return ONLY a valid JSON array, no markdown, no other text.
        """

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": "Transcript:\n\n\(transcript)"]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeAPIError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let apiResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let textBlock = apiResponse.content.first(where: { $0.type == "text" }),
              let jsonData = textBlock.text.data(using: .utf8) else {
            throw ClaudeAPIError.emptyResponse
        }

        let llmPhrases = try JSONDecoder().decode([LLMPhrase].self, from: jsonData)

        return llmPhrases.map { llm in
            ExtractedPhrase(
                phrase: llm.phrase,
                translation: llm.translation
            )
        }
    }
}

// MARK: - API Response Models

private struct ClaudeResponse: Codable {
    let content: [ContentBlock]
}

private struct ContentBlock: Codable {
    let type: String
    let text: String
}

// MARK: - Errors

enum ClaudeAPIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Anthropic API key not set. Go to Settings to add it."
        case .invalidResponse:
            "Invalid response from API."
        case .apiError(let code, let message):
            "API error (\(code)): \(message)"
        case .emptyResponse:
            "Empty response from API."
        }
    }
}
