# SpanishCourse

iOS app for learning Spanish, taught in Russian. Structured course with three CEFR levels (A0, A1, A2), text lessons, and AI-generated flashcards with spaced repetition.

## Build & Run

```bash
xcodebuild build -scheme SpanishCourse -project SpanishCourse.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Architecture

**Pattern:** MVVM + SwiftData + SwiftUI (pure, no dependencies)
**Target:** iOS 26

### Data Models
- `Level` — enum (A0/A1/A2), not persisted
- `Lesson` — Codable struct, loaded from bundled JSON (not @Model)
- `Card` — @Model with SM-2 spaced repetition fields, linked to lessons via `lessonId` string
- `CardType` — enum (vocabulary/conjugation/phrase/fillBlank)
- `LessonProgress` — @Model tracking read status and study sessions

### Services
- `LessonCatalog` — Singleton loading lessons from bundled JSON (a0/a1/a2_lessons.json)
- `LLMService` — 6 AI providers (Gemini, Groq, Mistral, OpenRouter, DeepSeek, Claude) for card generation
- `SM2` — Spaced repetition algorithm (copied from VocabFlashcards)

### Navigation
- Tab 1 "Уроки" — LevelListView → LessonListView → LessonDetailView → LessonContentView / CardListView / StudySessionView
- Tab 2 "Учить" — Global StudySessionView with FlipCardView + grade buttons
- Tab 3 "Настройки" — AI provider selection, API keys, study intervals

### Key Patterns
- Cards link to lessons via `lessonId` string (not SwiftData relationship, since Lesson is not @Model)
- Lessons are static bundled JSON content, never modified by user
- AI card generation uses lesson context (vocabulary, grammar, hints) for relevant output
- Soft delete pattern: `isTrashed` + `trashedAt`, auto-cleanup after 7 days
- All UI text is in Russian
