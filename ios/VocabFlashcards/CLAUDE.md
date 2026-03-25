# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VocabFlashcards is an iOS app for learning English phrasal verbs and vocabulary through live conversations. The user records a conversation → the app converts speech to text → automatically extracts phrasal verbs and verbs with short context (5–8 words) → the user reviews and saves flashcards → studies them via spaced repetition (SM-2).

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
├── Services/                         — SM-2 algorithm, notifications, dictionary
└── Resources/phrasal_verbs.json      — ~500 common phrasal verbs
```

### Data Layer (SwiftData)

| Model | Purpose |
|-------|---------|
| `Card` | Flashcard with front/back, context sentence, SM-2 parameters (easeFactor, interval, repetitions, nextReviewDate) |
| `CardGroup` | Collection of cards with cascade delete |
| `RecordingSession` | Raw transcript + extracted phrases (stored as Codable JSON in `extractedPhrasesData`) |
| `ExtractedPhrase` | Codable struct for NLP extraction results (not a @Model) |

### Key ViewModels

| ViewModel | Responsibility |
|-----------|---------------|
| `RecorderViewModel` | AVAudioEngine + SFSpeechRecognizer, real-time transcription, audio level metering |
| `NLPProcessor` | NaturalLanguage framework: sentence splitting, phrasal verb matching (dictionary-based), POS tagging for regular verbs, context window extraction |
| `ReviewViewModel` | Manages extracted phrases selection, saves to SwiftData |
| `StudyViewModel` | Loads due cards, drives flip-card study session, applies SM-2 grades |

### Services

| Service | Purpose |
|---------|---------|
| `SM2` | Pure function implementing the SM-2 spaced repetition algorithm (grades 0–5) |
| `NotificationService` | Daily review reminders via UNUserNotificationCenter |
| `PhrasalVerbDictionary` | Loads and queries phrasal_verbs.json |

### User Flow

1. **Record** tab → record conversation → real-time transcript via SFSpeechRecognizer
2. **Extract Phrases** → NLPProcessor finds phrasal verbs (dictionary match) and regular verbs (POS tagging)
3. **Review** → swipe to keep/skip phrases → save to a CardGroup
4. **Groups** tab → browse groups and cards, edit card front/back/context
5. **Study** tab → flip cards, grade (Again/Hard/Good/Easy) → SM-2 updates next review date

## Platform Notes

- Requires microphone + speech recognition permissions
- SFSpeechRecognizer configured for `en-US` locale
- No network usage; all processing is on-device
