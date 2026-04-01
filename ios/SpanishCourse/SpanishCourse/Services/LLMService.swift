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
        case .gemini: "Free: 250 req/day. Get key at aistudio.google.com"
        case .groq: "Free: 1,000 req/day (70B). Get key at console.groq.com"
        case .mistral: "Free Experiment plan: 1 req/s, 1B tokens/mo. Get key at console.mistral.ai"
        case .openRouter: "Free: 200 req/day on free models. Get key at openrouter.ai/settings/keys"
        case .deepSeek: "5M free tokens on signup. Get key at platform.deepseek.com"
        case .claude: "Paid API. Get key at console.anthropic.com"
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

// MARK: - Response Models

struct GeneratedCard: Codable {
    let front: String
    let back: String
    let context: String?
    let type: String?
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
    private func apiKey(for provider: LLMProvider) -> String {
        UserDefaults.standard.string(forKey: provider.settingsKey) ?? ""
    }

    // MARK: - Public API

    func generateLessonCards(
        lesson: Lesson,
        count: Int = 10,
        additionalPrompt: String? = nil
    ) async throws -> [GeneratedCard] {
        let systemPrompt = buildLessonPrompt(lesson: lesson, count: count)
        var userMessage = "Создай \(count) карточек для урока: \(lesson.title)"
        if let additional = additionalPrompt, !additional.isEmpty {
            userMessage += "\n\nДополнительные инструкции: \(additional)"
        }
        return try await callLLM(systemPrompt: systemPrompt, userMessage: userMessage)
    }

    func generateCustomCards(topic: String, count: Int = 10) async throws -> [GeneratedCard] {
        let systemPrompt = """
        Ты — преподаватель испанского языка, создающий флеш-карточки для русскоязычного ученика.

        Создай ровно \(count) флеш-карточек на тему: \(topic)

        Верни JSON-массив. Каждый элемент содержит:
        - "front": испанский текст (сторона вопроса — слово, фраза или предложение с пропуском)
        - "back": русский текст (сторона ответа — перевод или ответ)
        - "context": полное испанское предложение-пример (или null)
        - "type": один из "vocabulary", "conjugation", "phrase", "fillBlank"

        Карточки должны быть с нарастающей сложностью. Весь русский текст должен быть естественным.
        Верни ТОЛЬКО валидный JSON-массив, без markdown, без code fences.
        """
        let userMessage = "Создай \(count) карточек на тему: \(topic)"
        return try await callLLM(systemPrompt: systemPrompt, userMessage: userMessage)
    }

    func explainSentence(_ sentence: String, language: String = "spanish") async throws -> String {
        let targetLang = language == "english" ? "английского" : "испанского"
        let systemPrompt = """
        Ты — преподаватель \(targetLang) языка для русскоязычного ученика.
        Дай ОЧЕНЬ короткий разбор предложения — максимум 6-8 строк.

        Формат:
        <предложение>
        • слово1 — часть речи (перевод)
        • слово2 — часть речи (перевод)
        ...

        👉 Вместе: «перевод на русский»

        📌 Структура (если есть грамматический паттерн):
        [паттерн]

        Примеры (1-2 аналогичных предложения с переводом)

        НЕ добавляй лишних объяснений. Только разбор. Без markdown-форматирования, без code fences.
        """
        let userMessage = "Разбери предложение: \(sentence)"
        return try await callLLMText(systemPrompt: systemPrompt, userMessage: userMessage)
    }

    // MARK: - LLM Router (Text)

    private func callLLMText(systemPrompt: String, userMessage: String) async throws -> String {
        let currentProvider = await provider
        let key = await apiKey(for: currentProvider)
        guard !key.isEmpty else {
            throw LLMError.missingAPIKey(provider: currentProvider)
        }

        switch currentProvider {
        case .claude:
            return try await callClaudeText(userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key)
        case .gemini:
            return try await callGeminiText(userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key)
        case .groq:
            return try await callOpenAICompatibleText(
                endpoint: "https://api.groq.com/openai/v1/chat/completions",
                model: "llama-3.3-70b-versatile",
                userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key
            )
        case .mistral:
            return try await callOpenAICompatibleText(
                endpoint: "https://api.mistral.ai/v1/chat/completions",
                model: "mistral-small-latest",
                userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key
            )
        case .openRouter:
            return try await callOpenAICompatibleText(
                endpoint: "https://openrouter.ai/api/v1/chat/completions",
                model: "mistralai/mistral-small-3.1-24b-instruct:free",
                userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key
            )
        case .deepSeek:
            return try await callOpenAICompatibleText(
                endpoint: "https://api.deepseek.com/chat/completions",
                model: "deepseek-chat",
                userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key
            )
        }
    }

    // MARK: - LLM Router (Cards)

    private func callLLM(systemPrompt: String, userMessage: String) async throws -> [GeneratedCard] {
        let currentProvider = await provider
        let key = await apiKey(for: currentProvider)
        guard !key.isEmpty else {
            throw LLMError.missingAPIKey(provider: currentProvider)
        }

        switch currentProvider {
        case .claude:
            return try await callClaude(userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key)
        case .gemini:
            return try await callGemini(userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key)
        case .groq:
            return try await callOpenAICompatible(
                endpoint: "https://api.groq.com/openai/v1/chat/completions",
                model: "llama-3.3-70b-versatile",
                userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key,
                supportsJSONMode: true
            )
        case .mistral:
            return try await callOpenAICompatible(
                endpoint: "https://api.mistral.ai/v1/chat/completions",
                model: "mistral-small-latest",
                userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key,
                supportsJSONMode: true
            )
        case .openRouter:
            return try await callOpenAICompatible(
                endpoint: "https://openrouter.ai/api/v1/chat/completions",
                model: "mistralai/mistral-small-3.1-24b-instruct:free",
                userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key,
                supportsJSONMode: false
            )
        case .deepSeek:
            return try await callOpenAICompatible(
                endpoint: "https://api.deepseek.com/chat/completions",
                model: "deepseek-chat",
                userMessage: userMessage, systemPrompt: systemPrompt, apiKey: key,
                supportsJSONMode: true
            )
        }
    }

    // MARK: - Prompt

    private func buildLessonPrompt(lesson: Lesson, count: Int) -> String {
        let vocabList = lesson.keyVocabulary.map { "\($0.spanish) — \($0.russian)" }.joined(separator: "\n")
        let grammarList = lesson.grammarPoints.joined(separator: ", ")
        let typeNames = lesson.cardGenerationHints.types.map { $0.rawValue }.joined(separator: ", ")

        return """
        Ты — преподаватель испанского языка, создающий флеш-карточки для русскоязычного ученика.
        Уровень ученика: \(lesson.level.rawValue). Тема урока: \(lesson.title).

        Описание урока: \(lesson.subtitle)
        Ключевая лексика:
        \(vocabList)
        Грамматические темы: \(grammarList)

        Создай ровно \(count) флеш-карточек. Типы карточек: \(typeNames).

        \(lesson.cardGenerationHints.prompt)

        Верни JSON-массив. Каждый элемент содержит:
        - "front": испанский текст (сторона вопроса)
        - "back": русский текст (сторона ответа)
        - "context": полное испанское предложение-пример с использованием этого слова/фразы
        - "type": один из "\(typeNames)"

        Правила для каждого типа:
        - vocabulary: front = испанское слово/фраза, back = русский перевод
        - conjugation: front = "yo/tú/él... + инфинитив" (напр. "yo [hablar] = ?"), back = спрягаемая форма + русский перевод
        - phrase: front = полезная испанская фраза, back = русский перевод
        - fillBlank: front = испанское предложение с ___ пропуском, back = правильное слово + полное предложение + русский перевод

        Карточки должны быть с нарастающей сложностью. Весь русский текст должен быть естественным и понятным.
        Верни ТОЛЬКО валидный JSON-массив, без markdown, без code fences, без другого текста.
        """
    }

    // MARK: - Claude

    private func callClaude(userMessage: String, systemPrompt: String, apiKey: String) async throws -> [GeneratedCard] {
        let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
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

        return try decodeCards(from: jsonData)
    }

    // MARK: - Gemini

    private func callGemini(userMessage: String, systemPrompt: String, apiKey: String) async throws -> [GeneratedCard] {
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "parts": [["text": userMessage]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 4096,
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

        return try decodeCards(from: jsonData)
    }

    // MARK: - OpenAI-Compatible

    private func callOpenAICompatible(
        endpoint: String,
        model: String,
        userMessage: String,
        systemPrompt: String,
        apiKey: String,
        supportsJSONMode: Bool
    ) async throws -> [GeneratedCard] {
        let url = URL(string: endpoint)!

        var body: [String: Any] = [
            "model": model,
            "temperature": 0.3,
            "max_tokens": 4096,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
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

        return try decodeCards(from: jsonData)
    }

    // MARK: - Text Response Variants

    private func callClaudeText(userMessage: String, systemPrompt: String, apiKey: String) async throws -> String {
        let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [["role": "user", "content": userMessage]]
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
        guard let textBlock = apiResponse.content.first(where: { $0.type == "text" }) else {
            throw LLMError.emptyResponse
        }
        return textBlock.text
    }

    private func callGeminiText(userMessage: String, systemPrompt: String, apiKey: String) async throws -> String {
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["parts": [["text": userMessage]]]],
            "generationConfig": ["temperature": 0.3, "maxOutputTokens": 1024]
        ]
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates?.first?.content?.parts?.first?.text else {
            throw LLMError.emptyResponse
        }
        return text
    }

    private func callOpenAICompatibleText(endpoint: String, model: String, userMessage: String, systemPrompt: String, apiKey: String) async throws -> String {
        let url = URL(string: endpoint)!
        let body: [String: Any] = [
            "model": model,
            "temperature": 0.3,
            "max_tokens": 1024,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response, data: data)
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = openAIResponse.choices?.first?.message?.content else {
            throw LLMError.emptyResponse
        }
        return content
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

    private func decodeCards(from jsonData: Data) throws -> [GeneratedCard] {
        if let cards = try? JSONDecoder().decode([GeneratedCard].self, from: jsonData) {
            return cards
        }
        if let wrapper = try? JSONDecoder().decode(CardsWrapper.self, from: jsonData) {
            return wrapper.cards
        }
        if let wrapper = try? JSONDecoder().decode(FlashcardsWrapper.self, from: jsonData) {
            return wrapper.flashcards
        }
        if let wrapper = try? JSONDecoder().decode(ResultsWrapper.self, from: jsonData) {
            return wrapper.results
        }
        throw LLMError.emptyResponse
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

private struct CardsWrapper: Codable {
    let cards: [GeneratedCard]
}

private struct FlashcardsWrapper: Codable {
    let flashcards: [GeneratedCard]
}

private struct ResultsWrapper: Codable {
    let results: [GeneratedCard]
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
            "API-ключ \(provider.displayName) не задан. Перейдите в Настройки."
        case .invalidResponse:
            "Некорректный ответ от API."
        case .apiError(let code, let message):
            "Ошибка API (\(code)): \(message)"
        case .emptyResponse:
            "Пустой ответ от API."
        }
    }
}
