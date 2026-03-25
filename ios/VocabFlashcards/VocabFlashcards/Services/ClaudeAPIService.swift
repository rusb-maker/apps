import Foundation

// MARK: - Provider Configuration

enum LLMProvider: String, CaseIterable, Identifiable {
    case gemini
    case groq
    case mistral
    case openRouter
    case deepSeek
    case claude

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: "Google Gemini"
        case .groq: "Groq"
        case .mistral: "Mistral AI"
        case .openRouter: "OpenRouter"
        case .deepSeek: "DeepSeek"
        case .claude: "Claude (Anthropic)"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .gemini: "AIza..."
        case .groq: "gsk_..."
        case .mistral: "..."
        case .openRouter: "sk-or-..."
        case .deepSeek: "sk-..."
        case .claude: "sk-ant-..."
        }
    }

    var apiKeyHelp: String {
        switch self {
        case .gemini:
            "Free: 250 req/day. Get key at aistudio.google.com"
        case .groq:
            "Free: 1,000 req/day (70B). Get key at console.groq.com"
        case .mistral:
            "Free Experiment plan: 1 req/s, 1B tokens/mo. Get key at console.mistral.ai"
        case .openRouter:
            "Free: 200 req/day on free models. Get key at openrouter.ai/settings/keys"
        case .deepSeek:
            "5M free tokens on signup. Get key at platform.deepseek.com"
        case .claude:
            "Paid API. Get key at console.anthropic.com"
        }
    }

    var settingsKey: String {
        switch self {
        case .gemini: "gemini_api_key"
        case .groq: "groq_api_key"
        case .mistral: "mistral_api_key"
        case .openRouter: "openrouter_api_key"
        case .deepSeek: "deepseek_api_key"
        case .claude: "anthropic_api_key"
        }
    }

    /// Badge shown in settings to indicate pricing tier
    var tierBadge: String {
        switch self {
        case .gemini, .groq, .mistral, .openRouter: "FREE"
        case .deepSeek: "5M FREE"
        case .claude: "PAID"
        }
    }

    var tierColor: String {
        switch self {
        case .gemini, .groq, .mistral, .openRouter: "green"
        case .deepSeek: "orange"
        case .claude: "red"
        }
    }
}

// MARK: - CEFR Level

enum CEFRLevel: String, CaseIterable, Identifiable, Comparable {
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"

    var id: String { rawValue }

    private var sortOrder: Int {
        switch self {
        case .b1: 0
        case .b2: 1
        case .c1: 2
        case .c2: 3
        }
    }

    static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Response Models

struct LLMPhrase: Codable {
    let phrase: String
    let translation: String
    let level: String?
}

// MARK: - LLM Service

final class LLMService: Sendable {
    static let shared = LLMService()

    @MainActor
    private var provider: LLMProvider {
        let raw = UserDefaults.standard.string(forKey: "llm_provider") ?? LLMProvider.gemini.rawValue
        return LLMProvider(rawValue: raw) ?? .gemini
    }

    @MainActor
    private var minCEFR: CEFRLevel {
        let raw = UserDefaults.standard.string(forKey: "min_cefr_level") ?? CEFRLevel.b2.rawValue
        return CEFRLevel(rawValue: raw) ?? .b2
    }

    @MainActor
    private func apiKey(for provider: LLMProvider) -> String {
        UserDefaults.standard.string(forKey: provider.settingsKey) ?? ""
    }

    // MARK: - Public API

    func extractPhrases(from transcript: String) async throws -> [ExtractedPhrase] {
        let currentProvider = await provider
        let key = await apiKey(for: currentProvider)
        guard !key.isEmpty else {
            throw LLMError.missingAPIKey(provider: currentProvider)
        }

        let cefrLevel = await minCEFR
        let prompt = buildPrompt(minLevel: cefrLevel)

        switch currentProvider {
        case .claude:
            return try await callClaude(transcript: transcript, systemPrompt: prompt, apiKey: key)
        case .gemini:
            return try await callGemini(transcript: transcript, systemPrompt: prompt, apiKey: key)
        case .groq:
            return try await callOpenAICompatible(
                endpoint: "https://api.groq.com/openai/v1/chat/completions",
                model: "llama-3.3-70b-versatile",
                transcript: transcript, systemPrompt: prompt, apiKey: key,
                supportsJSONMode: true
            )
        case .mistral:
            return try await callOpenAICompatible(
                endpoint: "https://api.mistral.ai/v1/chat/completions",
                model: "mistral-small-latest",
                transcript: transcript, systemPrompt: prompt, apiKey: key,
                supportsJSONMode: true
            )
        case .openRouter:
            return try await callOpenAICompatible(
                endpoint: "https://openrouter.ai/api/v1/chat/completions",
                model: "mistralai/mistral-small-3.1-24b-instruct:free",
                transcript: transcript, systemPrompt: prompt, apiKey: key,
                supportsJSONMode: false
            )
        case .deepSeek:
            return try await callOpenAICompatible(
                endpoint: "https://api.deepseek.com/chat/completions",
                model: "deepseek-chat",
                transcript: transcript, systemPrompt: prompt, apiKey: key,
                supportsJSONMode: true
            )
        }
    }

    // MARK: - Prompt

    private func buildPrompt(minLevel level: CEFRLevel) -> String {
        return """
        You are an English language tutor helping a Russian-speaking student. \
        Analyze the conversation transcript and extract useful English expressions, \
        phrasal verbs, idioms, and collocations worth learning.

        IMPORTANT: Only include expressions at CEFR level \(level.rawValue) or higher. \
        Skip basic expressions that a \(belowLevel(level)) learner would already know. \
        Focus on advanced phrasal verbs, idiomatic expressions, formal/academic collocations, \
        and nuanced vocabulary.

        Return a JSON array. Each item has:
        - "phrase": the English expression with enough context to understand usage (5-10 words)
        - "translation": natural Russian translation
        - "level": estimated CEFR level (B1, B2, C1, or C2)

        Focus on expressions that are:
        - Non-trivial (skip basic verbs like "is", "have", "go", "get")
        - At CEFR level \(level.rawValue) or above
        - Include enough surrounding words to show how the expression is used

        Return ONLY a valid JSON array, no markdown, no code fences, no other text.
        """
    }

    private func belowLevel(_ level: CEFRLevel) -> String {
        switch level {
        case .b1: "A2"
        case .b2: "B1"
        case .c1: "B2"
        case .c2: "C1"
        }
    }

    // MARK: - Claude (custom format)

    private func callClaude(transcript: String, systemPrompt: String, apiKey: String) async throws -> [ExtractedPhrase] {
        let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
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
        try validateHTTPResponse(response, data: data)

        let apiResponse = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let textBlock = apiResponse.content.first(where: { $0.type == "text" }),
              let jsonData = textBlock.text.data(using: .utf8) else {
            throw LLMError.emptyResponse
        }

        return try decodePhrases(from: jsonData)
    }

    // MARK: - Gemini (custom format)

    private func callGemini(transcript: String, systemPrompt: String, apiKey: String) async throws -> [ExtractedPhrase] {
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "parts": [["text": "Transcript:\n\n\(transcript)"]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 2048,
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text,
              let jsonData = text.data(using: .utf8) else {
            throw LLMError.emptyResponse
        }

        return try decodePhrases(from: jsonData)
    }

    // MARK: - OpenAI-Compatible (Groq, Mistral, OpenRouter, DeepSeek)

    private func callOpenAICompatible(
        endpoint: String,
        model: String,
        transcript: String,
        systemPrompt: String,
        apiKey: String,
        supportsJSONMode: Bool
    ) async throws -> [ExtractedPhrase] {
        let url = URL(string: endpoint)!

        var body: [String: Any] = [
            "model": model,
            "temperature": 0.3,
            "max_tokens": 2048,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Transcript:\n\n\(transcript)"]
            ]
        ]

        if supportsJSONMode {
            body["response_format"] = ["type": "json_object"]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices?.first?.message?.content,
              let jsonData = content.data(using: .utf8) else {
            throw LLMError.emptyResponse
        }

        return try decodePhrases(from: jsonData)
    }

    // MARK: - Shared Helpers

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
    }

    private func decodePhrases(from jsonData: Data) throws -> [ExtractedPhrase] {
        // Try direct array first
        if let llmPhrases = try? JSONDecoder().decode([LLMPhrase].self, from: jsonData) {
            return llmPhrases.map { mapPhrase($0) }
        }
        // Try wrapped {"phrases": [...]} (common with json_object mode)
        if let wrapper = try? JSONDecoder().decode(PhrasesWrapper.self, from: jsonData) {
            return wrapper.phrases.map { mapPhrase($0) }
        }
        // Try other common wrappers: {"results": [...]}, {"data": [...]}
        if let wrapper = try? JSONDecoder().decode(ResultsWrapper.self, from: jsonData) {
            return wrapper.results.map { mapPhrase($0) }
        }
        throw LLMError.emptyResponse
    }

    private func mapPhrase(_ llm: LLMPhrase) -> ExtractedPhrase {
        ExtractedPhrase(
            phrase: llm.phrase,
            translation: llm.translation,
            cefrLevel: llm.level
        )
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

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent?
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]?
}

private struct GeminiPart: Codable {
    let text: String?
}

private struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]?
}

private struct OpenAIChoice: Codable {
    let message: OpenAIMessage?
}

private struct OpenAIMessage: Codable {
    let content: String?
}

private struct PhrasesWrapper: Codable {
    let phrases: [LLMPhrase]
}

private struct ResultsWrapper: Codable {
    let results: [LLMPhrase]
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case missingAPIKey(provider: LLMProvider)
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            "\(provider.displayName) API key not set. Go to Settings to add it."
        case .invalidResponse:
            "Invalid response from API."
        case .apiError(let code, let message):
            "API error (\(code)): \(message)"
        case .emptyResponse:
            "Empty response from API."
        }
    }
}

// Keep backward compatibility alias
typealias ClaudeAPIService = LLMService
typealias ClaudeAPIError = LLMError
