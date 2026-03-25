# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VocabFlashcards is an iOS app for learning English phrasal verbs and vocabulary through live conversations. Two input methods: (1) record a conversation with real-time speech-to-text, or (2) paste/type text directly. The app sends the transcript to an LLM API to extract useful expressions with Russian translations and CEFR levels. The user reviews and saves flashcards, then studies them via spaced repetition (SM-2).

## Build & Run

```bash
xcodebuild build -scheme VocabFlashcards -project VocabFlashcards.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -scheme VocabFlashcards -project VocabFlashcards.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

No external dependencies. iOS 17.0+ deployment target.

## Architecture (MVVM)

```
VocabFlashcards/
├── App/VocabFlashcardsApp.swift           — @main, SwiftData container setup
├── Models/                           — SwiftData models
├── ViewModels/                       — @Observable view models + NLP logic
├── Views/                            — SwiftUI views organized by feature
├── Services/                         — SM-2 algorithm, notifications, LLM API, dictionary
└── Resources/phrasal_verbs.json      — ~500 common phrasal verbs
```

### Data Layer (SwiftData)

| Model | Purpose |
|-------|---------|
| `Card` | Flashcard with front/back, context sentence, SM-2 parameters (easeFactor, interval, repetitions, nextReviewDate) |
| `CardGroup` | Collection of cards with cascade delete, `isStudyEnabled` toggle |
| `RecordingSession` | Raw transcript + extracted phrases (stored as Codable JSON in `extractedPhrasesData`) |
| `ExtractedPhrase` | Codable struct (not a @Model) — phrase, translation, cefrLevel, isSelected |

### Key ViewModels

| ViewModel | Responsibility |
|-----------|---------------|
| `RecorderViewModel` | AVAudioEngine + SFSpeechRecognizer, real-time transcription, audio level metering |
| `NLPProcessor` | On-device fallback: NaturalLanguage framework for sentence splitting, phrasal verb matching (dictionary-based), POS tagging for regular verbs, context window extraction. Not used in the primary LLM flow. |
| `ReviewViewModel` | Manages extracted phrases selection, saves to SwiftData |
| `StudyViewModel` | Loads due cards, drives flip-card study session, applies SM-2 grades |

### Services

| Service | Purpose |
|---------|---------|
| `LLMService` (in ClaudeAPIService.swift) | Multi-provider LLM client for phrase extraction. Supports 6 providers: Gemini (default, free), Groq, Mistral, OpenRouter, DeepSeek, Claude. Uses OpenAI-compatible API for most providers, custom format for Claude and Gemini. |
| `SM2` | Pure function implementing the SM-2 spaced repetition algorithm (grades 0–5) |
| `NotificationService` | Daily review reminders via UNUserNotificationCenter |
| `PhrasalVerbDictionary` | Loads and queries phrasal_verbs.json |

### LLM Provider System

Defined in `ClaudeAPIService.swift`:

- `LLMProvider` enum — 6 providers with display names, API key placeholders, tier badges (FREE/PAID), settings keys
- `CEFRLevel` enum — B1, B2, C1, C2 filtering for phrase extraction
- `LLMService` — singleton, reads provider & API key from `UserDefaults`, builds CEFR-aware prompt, routes to provider-specific API call
- Response parsing handles JSON arrays and common wrappers (`{phrases: [...]}`, `{results: [...]}`)
- Backward-compat typealiases: `ClaudeAPIService = LLMService`, `ClaudeAPIError = LLMError`

### User Flow

1. **Record** tab → record conversation → real-time transcript via SFSpeechRecognizer → extract phrases via LLM
2. **Text** tab → paste or type English text → extract phrases via LLM
3. **Review** → swipe to keep/skip phrases → save to a CardGroup
4. **Groups** tab → browse groups and cards, edit card front/back/context, toggle group study
5. **Study** tab → flip cards, grade (Again/Hard/Good/Easy) → SM-2 updates next review date
6. **History** tab → past recording sessions with transcripts and extracted phrases
7. **Settings** tab → choose LLM provider, enter API key, set minimum CEFR level

### Tab Structure (MainTabView)

| Tab | View | Icon |
|-----|------|------|
| Record | `RecordingView` | mic.fill |
| Text | `TextInputView` | doc.text |
| Groups | `GroupsListView` | folder.fill |
| Study | `StudySessionView` | brain.head.profile |
| History | `RecordingsListView` | clock.fill |
| Settings | `SettingsView` | gearshape |

## Platform Notes

- Requires microphone + speech recognition permissions (for Record tab)
- SFSpeechRecognizer configured for `en-US` locale
- Network access required for LLM API calls (phrase extraction)
- API keys stored in UserDefaults (per-provider keys)
- Default provider: Google Gemini (free tier, 250 req/day)
