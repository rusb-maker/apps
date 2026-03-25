# VocabCatch — iOS Flashcard App with Speech-to-Text & NLP

## Project Prompt / Technical Specification

---

## Elevator Pitch

iOS-приложение для изучения английских фразовых глаголов и лексики через живые диалоги. Пользователь записывает разговор → приложение конвертирует речь в текст → автоматически извлекает phrasal verbs и глаголы с коротким контекстом (5–8 слов) → пользователь ревьюит и сохраняет карточки → учит их через spaced repetition (SM-2).

---

## Tech Stack (100% бесплатный)

| Компонент | Технология | Почему |
|-----------|------------|--------|
| UI | SwiftUI | Нативный, декларативный, бесплатный |
| Хранение данных | SwiftData | Встроенный в iOS 17+, заменяет Core Data |
| Запись аудио | AVFoundation (AVAudioEngine) | Нативный фреймворк Apple |
| Speech-to-Text | Speech Framework (SFSpeechRecognizer) | Бесплатный, работает офлайн для en-US |
| NLP-обработка | NaturalLanguage Framework | Бесплатный, Apple-нативный, POS-tagging + лемматизация |
| Уведомления | UserNotifications | Встроенный фреймворк |
| Архитектура | MVVM | Стандарт для SwiftUI |

**Минимальная цель:** iOS 17.0+ | iPhone only | Swift 5.9+ | Xcode 15+

---

## Data Models (SwiftData)

```swift
// ===== CARD =====
@Model
class Card {
    var id: UUID
    var front: String          // Фраза/глагол (e.g. "give up")
    var back: String           // Перевод или объяснение
    var contextSentence: String // Короткое предложение 5-8 слов
    var verbType: VerbType     // .phrasal / .regular
    var createdAt: Date

    // SM-2 параметры
    var easeFactor: Double     // начальное значение 2.5
    var interval: Int          // дни до следующего повторения
    var repetitions: Int       // сколько раз правильно ответил подряд
    var nextReviewDate: Date

    // Связь
    var group: CardGroup?
}

enum VerbType: String, Codable {
    case phrasal    // give up, look into, come across
    case regular    // run, think, believe
}

// ===== CARD GROUP =====
@Model
class CardGroup {
    var id: UUID
    var name: String
    var createdAt: Date
    var cards: [Card]
}

// ===== RECORDING SESSION =====
@Model
class RecordingSession {
    var id: UUID
    var rawTranscript: String
    var extractedPhrases: [ExtractedPhrase]
    var createdAt: Date
    var duration: TimeInterval
}

// Вспомогательная структура (не @Model, а Codable)
struct ExtractedPhrase: Codable, Identifiable {
    var id: UUID
    var phrase: String             // "give up smoking"
    var verb: String               // "give up"
    var contextSentence: String    // "He decided to give up smoking last year"
    var verbType: VerbType
    var isSelected: Bool           // для экрана ревью
}
```

---

## App Architecture (MVVM)

```
VocabCatchApp/
├── App/
│   └── VocabCatchApp.swift              // @main, SwiftData container setup
├── Models/
│   ├── Card.swift
│   ├── CardGroup.swift
│   └── RecordingSession.swift
├── ViewModels/
│   ├── RecorderViewModel.swift          // AVAudioEngine + SFSpeechRecognizer
│   ├── NLPProcessor.swift               // NaturalLanguage extraction logic
│   ├── ReviewViewModel.swift            // Управление ревью извлечённых фраз
│   ├── StudyViewModel.swift             // SM-2 алгоритм + логика сессии
│   └── GroupsViewModel.swift            // CRUD для групп
├── Views/
│   ├── MainTabView.swift                // TabView: Record / Groups / Study
│   ├── Recording/
│   │   ├── RecordingView.swift          // Кнопка записи, визуализация
│   │   └── TranscriptView.swift         // Показ расшифрованного текста
│   ├── Review/
│   │   ├── ReviewListView.swift         // Список извлечённых фраз (swipe actions)
│   │   └── PhraseEditView.swift         // Редактирование одной фразы
│   ├── Groups/
│   │   ├── GroupsListView.swift         // Список групп
│   │   └── GroupDetailView.swift        // Карточки внутри группы
│   ├── Study/
│   │   ├── StudySessionView.swift       // Флип-карточка + оценка
│   │   └── StudyCompleteView.swift      // Результат сессии
│   └── Components/
│       ├── FlipCardView.swift           // Анимация переворота карточки
│       ├── WaveformView.swift           // Визуализация звуковой волны
│       └── SwipeableRow.swift           // Swipe-to-delete / swipe-to-save
├── Services/
│   ├── SpeechRecognitionService.swift   // Обёртка над SFSpeechRecognizer
│   ├── PhrasalVerbDictionary.swift      // Словарь ~3000 phrasal verbs
│   └── NotificationService.swift        // Локальные уведомления
└── Resources/
    └── phrasal_verbs.json               // База phrasal verbs
```

---

## Module 1: Audio Recording + Speech-to-Text

### RecorderViewModel

```swift
import AVFoundation
import Speech

@Observable
class RecorderViewModel {
    var isRecording = false
    var transcript = ""
    var audioLevel: Float = 0.0  // для визуализации волны
    var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    // MARK: - Permissions
    func requestPermissions() async -> Bool {
        // 1. Запросить доступ к микрофону
        let micPermission = await AVAudioApplication.requestRecordPermission()

        // 2. Запросить доступ к распознаванию речи
        let speechPermission = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }

        return micPermission && speechPermission
    }

    // MARK: - Start Recording
    func startRecording() throws {
        // Сбросить предыдущую сессию
        recognitionTask?.cancel()
        recognitionTask = nil

        // Настроить аудио сессию
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        // Запустить распознавание
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let result {
                self?.transcript = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self?.stopRecording()
            }
        }

        // Подключить микрофон
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            recognitionRequest.append(buffer)
            // Обновить уровень звука для визуализации
            self?.updateAudioLevel(buffer: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    // MARK: - Stop Recording
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        let rms = sqrt(
            (0..<frameCount).map { data[$0] * data[$0] }.reduce(0, +) / Float(frameCount)
        )
        DispatchQueue.main.async {
            self.audioLevel = rms
        }
    }
}
```

---

## Module 2: NLP Extraction (Ключевой модуль)

### Логика извлечения phrasal verbs и глаголов

```swift
import NaturalLanguage

class NLPProcessor {

    // Загрузить словарь phrasal verbs из JSON
    private let phrasalVerbs: Set<String> = {
        // phrasal_verbs.json содержит: ["give up", "look into", "come across", ...]
        guard let url = Bundle.main.url(forResource: "phrasal_verbs", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let verbs = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(verbs.map { $0.lowercased() })
    }()

    // MARK: - Main Extraction
    func extractPhrases(from text: String) -> [ExtractedPhrase] {
        let sentences = splitIntoSentences(text)
        var results: [ExtractedPhrase] = []

        for sentence in sentences {
            // 1. Искать phrasal verbs
            let foundPhrasals = findPhrasalVerbs(in: sentence)
            for phrasal in foundPhrasals {
                let context = extractContext(
                    around: phrasal,
                    in: sentence,
                    windowSize: 5...8
                )
                results.append(ExtractedPhrase(
                    id: UUID(),
                    phrase: phrasal,
                    verb: phrasal,
                    contextSentence: context,
                    verbType: .phrasal,
                    isSelected: true
                ))
            }

            // 2. Искать обычные глаголы (если нет phrasal verbs)
            if foundPhrasals.isEmpty {
                let verbs = findRegularVerbs(in: sentence)
                for verb in verbs {
                    let context = extractContext(
                        around: verb,
                        in: sentence,
                        windowSize: 5...8
                    )
                    results.append(ExtractedPhrase(
                        id: UUID(),
                        phrase: verb,
                        verb: verb,
                        contextSentence: context,
                        verbType: .regular,
                        isSelected: true
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

        // Проверять пары и тройки слов
        for i in 0..<words.count {
            // Двухсловные: "give up", "look into"
            if i + 1 < words.count {
                let pair = "\(words[i]) \(words[i+1])"
                let cleanPair = pair.filter { $0.isLetter || $0 == " " }
                if phrasalVerbs.contains(cleanPair) {
                    found.append(cleanPair)
                }
            }
            // Трёхсловные: "look forward to", "come up with"
            if i + 2 < words.count {
                let triple = "\(words[i]) \(words[i+1]) \(words[i+2])"
                let cleanTriple = triple.filter { $0.isLetter || $0 == " " }
                if phrasalVerbs.contains(cleanTriple) {
                    found.append(cleanTriple)
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

        tagger.enumerateTags(
            in: sentence.startIndex..<sentence.endIndex,
            unit: .word,
            scheme: .lexicalClass
        ) { tag, range in
            if tag == .verb {
                let word = String(sentence[range])
                // Игнорировать вспомогательные глаголы
                let auxiliaries: Set<String> = ["is", "am", "are", "was", "were",
                    "be", "been", "being", "have", "has", "had",
                    "do", "does", "did", "will", "would", "shall",
                    "should", "can", "could", "may", "might", "must"]
                if !auxiliaries.contains(word.lowercased()) {
                    verbs.append(word)
                }
            }
            return true
        }

        return verbs
    }

    // MARK: - Extract Context Window (5-8 words)
    private func extractContext(
        around target: String,
        in sentence: String,
        windowSize: ClosedRange<Int>
    ) -> String {
        let words = sentence
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Если предложение уже в пределах окна — вернуть целиком
        if words.count <= windowSize.upperBound {
            return words.joined(separator: " ")
        }

        // Найти позицию target
        let targetWords = target.lowercased()
            .components(separatedBy: " ")
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

        // Взять окно вокруг target
        let targetEnd = startIdx + targetWords.count
        let desiredTotal = windowSize.upperBound
        let contextBefore = max(0, (desiredTotal - targetWords.count) / 2)
        let windowStart = max(0, startIdx - contextBefore)
        let windowEnd = min(words.count, windowStart + desiredTotal)

        return words[windowStart..<windowEnd].joined(separator: " ")
    }
}
```

---

## Module 3: SM-2 Spaced Repetition Algorithm

```swift
struct SM2 {

    struct ReviewResult {
        let newEaseFactor: Double
        let newInterval: Int        // в днях
        let newRepetitions: Int
        let nextReviewDate: Date
    }

    /// grade: 0 = полный провал, 1 = неправильно, 2 = неправильно но помнил,
    ///        3 = правильно с трудом, 4 = правильно, 5 = идеально
    static func review(
        grade: Int,
        currentEaseFactor: Double,
        currentInterval: Int,
        currentRepetitions: Int
    ) -> ReviewResult {

        let grade = max(0, min(5, grade))

        var newEF = currentEaseFactor
        var newInterval: Int
        var newReps: Int

        if grade >= 3 {
            // Правильный ответ
            switch currentRepetitions {
            case 0:  newInterval = 1
            case 1:  newInterval = 6
            default: newInterval = Int(round(Double(currentInterval) * currentEaseFactor))
            }
            newReps = currentRepetitions + 1
        } else {
            // Неправильный ответ — сбросить
            newInterval = 1
            newReps = 0
        }

        // Пересчитать ease factor
        newEF = currentEaseFactor + (0.1 - Double(5 - grade) * (0.08 + Double(5 - grade) * 0.02))
        newEF = max(1.3, newEF) // Минимум 1.3

        let nextDate = Calendar.current.date(
            byAdding: .day,
            value: newInterval,
            to: Date()
        ) ?? Date()

        return ReviewResult(
            newEaseFactor: newEF,
            newInterval: newInterval,
            newRepetitions: newReps,
            nextReviewDate: nextDate
        )
    }
}
```

---

## Module 4: Review Screen (SwiftUI)

```swift
struct ReviewListView: View {
    @State var phrases: [ExtractedPhrase]
    @State private var selectedGroup: CardGroup?
    @State private var showGroupPicker = false

    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            List {
                ForEach($phrases) { $phrase in
                    ReviewRow(phrase: $phrase)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                phrase.isSelected = false
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                phrase.isSelected = true
                            } label: {
                                Label("Keep", systemImage: "checkmark")
                            }
                            .tint(.green)
                        }
                }
            }
            .navigationTitle("Review Phrases")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save \(selectedCount)") {
                        saveSelectedCards()
                    }
                    .disabled(selectedCount == 0)
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Choose Group") {
                        showGroupPicker = true
                    }
                }
            }
            .sheet(isPresented: $showGroupPicker) {
                GroupPickerView(selected: $selectedGroup)
            }
        }
    }

    private var selectedCount: Int {
        phrases.filter(\.isSelected).count
    }

    private func saveSelectedCards() {
        let group = selectedGroup ?? createDefaultGroup()
        for phrase in phrases where phrase.isSelected {
            let card = Card(
                id: UUID(),
                front: phrase.verb,
                back: "", // пользователь добавит перевод
                contextSentence: phrase.contextSentence,
                verbType: phrase.verbType,
                createdAt: Date(),
                easeFactor: 2.5,
                interval: 0,
                repetitions: 0,
                nextReviewDate: Date(),
                group: group
            )
            context.insert(card)
        }
        try? context.save()
    }
}
```

---

## phrasal_verbs.json (фрагмент)

Полный файл должен содержать ~3000 самых употребимых phrasal verbs:

```json
[
    "act on", "act out", "act up",
    "back down", "back off", "back out", "back up",
    "blow out", "blow over", "blow up",
    "break down", "break in", "break into", "break off",
    "break out", "break through", "break up",
    "bring about", "bring along", "bring back", "bring down",
    "bring forward", "bring in", "bring off", "bring on",
    "bring out", "bring round", "bring up",
    "call back", "call for", "call off", "call on", "call out",
    "call up", "carry on", "carry out",
    "catch on", "catch up", "catch up with",
    "check in", "check out", "check up on",
    "come about", "come across", "come along", "come apart",
    "come back", "come by", "come down", "come forward",
    "come in", "come off", "come on", "come out",
    "come over", "come round", "come through", "come up",
    "come up against", "come up with",
    "count on", "cross out", "cut back", "cut down",
    "cut in", "cut off", "cut out", "cut up",
    "deal with", "do away with", "do up", "do without",
    "draw up", "drop by", "drop in", "drop off", "drop out",
    "end up",
    "fall apart", "fall back", "fall behind", "fall down",
    "fall for", "fall off", "fall out", "fall through",
    "figure out", "fill in", "fill out", "fill up",
    "find out", "get across", "get ahead", "get along",
    "get around", "get at", "get away", "get back",
    "get behind", "get by", "get down", "get in",
    "get into", "get off", "get on", "get out",
    "get over", "get round", "get through", "get together",
    "get up", "give away", "give back", "give in",
    "give off", "give out", "give up",
    "go about", "go after", "go against", "go ahead",
    "go along with", "go around", "go away", "go back",
    "go by", "go down", "go for", "go in for",
    "go into", "go off", "go on", "go out",
    "go over", "go round", "go through", "go up",
    "go with", "go without",
    "grow up",
    "hand back", "hand in", "hand out", "hand over",
    "hang on", "hang out", "hang up",
    "hold back", "hold on", "hold out", "hold up",
    "keep on", "keep up", "keep up with",
    "knock down", "knock out",
    "lay off", "leave out", "let down", "let in",
    "let off", "let out",
    "look after", "look ahead", "look around", "look at",
    "look back", "look down on", "look for",
    "look forward to", "look in", "look into",
    "look on", "look out", "look over", "look round",
    "look through", "look up", "look up to",
    "make for", "make out", "make up", "make up for",
    "mix up", "move in", "move on", "move out",
    "open up", "opt out",
    "pass away", "pass on", "pass out",
    "pay back", "pay off",
    "pick out", "pick up", "point out",
    "pull down", "pull in", "pull off", "pull out",
    "pull through", "pull up",
    "put across", "put aside", "put away", "put back",
    "put down", "put forward", "put in", "put off",
    "put on", "put out", "put through", "put together",
    "put up", "put up with",
    "run away", "run into", "run out", "run over",
    "set off", "set out", "set up",
    "show off", "show up", "shut down", "shut up",
    "sort out", "speak up", "stand by", "stand for",
    "stand out", "stand up", "stand up for",
    "take after", "take apart", "take away", "take back",
    "take down", "take in", "take off", "take on",
    "take out", "take over", "take up",
    "tell off", "think over", "throw away",
    "try on", "try out", "turn around", "turn away",
    "turn down", "turn into", "turn off", "turn on",
    "turn out", "turn over", "turn up",
    "use up",
    "wake up", "watch out", "wear off", "wear out",
    "work out", "write down"
]
```

---

## User Flow (полный сценарий)

```
1. ЗАПУСК → MainTabView (3 вкладки: Record / Groups / Study)

2. RECORD TAB
   └─ Нажать 🎤 → начать запись диалога
   └─ Визуализация волны в реальном времени
   └─ Транскрипт появляется на экране по мере говорения
   └─ Нажать ⏹ → остановить запись
   └─ Нажать "Extract Phrases" → NLPProcessor обрабатывает текст
   └─ Переход → ReviewListView

3. REVIEW
   └─ Список извлечённых фраз (phrasal verbs подсвечены)
   └─ Swipe left → удалить фразу
   └─ Swipe right → отметить как сохраняемую
   └─ Tap → редактировать текст карточки
   └─ Выбрать группу (или создать новую)
   └─ "Save" → карточки сохраняются в SwiftData

4. GROUPS TAB
   └─ Список групп с количеством карточек
   └─ Tap на группу → список карточек
   └─ Tap на карточку → flip-анимация (front/back)
   └─ Можно редактировать, удалять

5. STUDY TAB
   └─ "Start Session" → карточки с nextReviewDate <= today
   └─ Показать front → пользователь думает → tap "Show Answer"
   └─ Показать back + контекст
   └─ Оценка: Again (0) / Hard (3) / Good (4) / Easy (5)
   └─ SM-2 пересчитывает interval, easeFactor, nextReviewDate
   └─ Конец сессии → статистика (изучено / правильно / неправильно)

6. NOTIFICATIONS
   └─ Ежедневное напоминание: "У вас N карточек на повторение"
```

---

## Milestone Plan

### MVP 1 (Недели 1–3): Skeleton
- [ ] Создать Xcode-проект с SwiftUI + SwiftData
- [ ] Реализовать модели данных (Card, CardGroup, RecordingSession)
- [ ] MainTabView с тремя вкладками
- [ ] GroupsListView + GroupDetailView (CRUD)
- [ ] FlipCardView с анимацией

### MVP 2 (Недели 4–6): Recording Pipeline
- [ ] Запрос разрешений (микрофон + Speech)
- [ ] RecordingView с кнопкой записи
- [ ] WaveformView для визуализации звука
- [ ] Интеграция SFSpeechRecognizer (real-time transcript)
- [ ] TranscriptView с отображением текста

### MVP 3 (Недели 7–9): NLP + Review
- [ ] Загрузить phrasal_verbs.json (~3000 фраз)
- [ ] NLPProcessor: поиск phrasal verbs в тексте
- [ ] NLPProcessor: POS-tagging для обычных глаголов
- [ ] NLPProcessor: извлечение контекста 5-8 слов
- [ ] ReviewListView со swipe-действиями
- [ ] Сохранение в выбранную группу

### MVP 4 (Недели 10–12): Spaced Repetition
- [ ] SM-2 алгоритм (review function)
- [ ] StudySessionView (flip + grade)
- [ ] Фильтрация карточек по nextReviewDate
- [ ] StudyCompleteView со статистикой
- [ ] Локальные push-уведомления

### Polish (Недели 13–14):
- [ ] Онбординг (первый запуск)
- [ ] Streak tracking
- [ ] Поиск по карточкам
- [ ] Dark mode
- [ ] Animations & haptic feedback
