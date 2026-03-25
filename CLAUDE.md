# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

Monorepo containing three independent Apple-platform apps. Each has its own detailed `CLAUDE.md` — read the relevant one before working on that app.

| App | Path | Platform | Description |
|-----|------|----------|-------------|
| **Colage** | `ios/Colage/` | iOS 18.5+ | Photo/video collage maker |
| **VocabFlashcards** | `ios/VocabFlashcards/` | iOS 17.0+ | Flashcard app with speech-to-text & NLP for learning English phrasal verbs |
| **Simple Storage Browser** | `macos/s3_mount/` | macOS 26.2 | S3/Wasabi bucket mount via rclone + macFUSE |

## Build & Test Commands

All apps use Xcode projects directly — no SPM, CocoaPods, or Carthage.

### VocabFlashcards (iOS)

```bash
xcodebuild build -scheme VocabFlashcards -project ios/VocabFlashcards/VocabFlashcards.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -scheme VocabFlashcards -project ios/VocabFlashcards/VocabFlashcards.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Colage (iOS)

```bash
xcodebuild build -scheme Colage -project ios/Colage/Colage.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -scheme Colage -project ios/Colage/Colage.xcodeproj -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Simple Storage Browser (macOS)

```bash
xcodebuild build -project macos/s3_mount/simple_storage_browser.xcodeproj -scheme simple_storage_browser -destination 'platform=macOS'
xcodebuild test -project macos/s3_mount/simple_storage_browser.xcodeproj -scheme simple_storage_browser -destination 'platform=macOS'
```

## Shared Patterns

- All apps are pure **SwiftUI** with no external package dependencies
- `#if canImport(UIKit)` / `#else` guards used in Colage for cross-compilation
- Per-app architecture docs: `ios/Colage/CLAUDE.md`, `ios/VocabFlashcards/CLAUDE.md`, and `macos/s3_mount/CLAUDE.md`
