# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Colage is an iOS photo/video collage maker built with SwiftUI. The entire app logic lives in two files: `Colage/ColageApp.swift` (entry point) and `Colage/ContentView.swift` (all UI and business logic).

## Build & Run

Open `Colage.xcodeproj` in Xcode and run on an iOS simulator or device. There is no package manager (no SPM, CocoaPods, or Carthage). Build, test, and lint via Xcode only.

- **Run tests**: `Cmd+U` in Xcode, or `xcodebuild test -scheme Colage -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Build**: `xcodebuild build -scheme Colage -destination 'platform=iOS Simulator,name=iPhone 16'`

## Architecture

Everything is in `ContentView.swift` (~1550 lines), organized with `// MARK:` sections. The macOS stub at the bottom (`#else` branch after `#if canImport(UIKit)`) is intentional — just a placeholder message.

### Key Types (all nested inside or alongside `ContentView`)

| Type | Purpose |
|------|---------|
| `Template` | Enum of 10 collage layouts (2–6 panes) |
| `BorderStyle` | `.none` or `.separators` |
| `PickedMedia` | `.image(UIImage)` or `.video(URL)` |
| `CollageCanvas` | SwiftUI view that composes panes per template |
| `CollagePane` | Individual media slot with pinch-zoom/pan, long-press to replace |
| `TemplatePickerView` | Sheet for choosing layout |
| `StylePickerView` | Sheet for choosing border style |
| `PreviewSheet` | Full-screen preview of rendered collage |
| `ShareSheet` | UIViewControllerRepresentable wrapping `UIActivityViewController` |
| `SystemPhotoPicker` | UIViewControllerRepresentable wrapping `PHPickerViewController` |

### Collage Rendering

**Static export** (`renderCollage()`): Uses SwiftUI `ImageRenderer` at 2048px width, height derived from `canvasAspect` (tracked via `GeometryReader` in `canvasSection`).

**Video export** (`exportVideoMP4()`): Runs on a background `Task`. For each frame: extracts frames from each pane's `AVAsset`, composites them into a `CollageCanvas` view, renders via `ImageRenderer`, converts to `CVPixelBuffer` via `pixelBuffer(from:size:)`, and appends to `AVAssetWriter`. Supports cancellation via `cancelExport` flag.

### State Management

All state is `@State` on `ContentView` — no view models or ObservableObjects. Slots for up to 6 panes each have their own `image1…image6`, `video1…video6`, `videoURL1…videoURL6`. The active pane index (`activePaneIndex`) routes system photo picker selections to the correct slot.

### Border/Style Customization

The border settings slide-up panel (bottom sheet, draggable) controls:
- **Separator**: `separatorColor`, `separatorThickness`, `paneCornerRadius`
- **Outer border**: `outerBorderColor`, `outerBorderWidth`, `outerCornerRadius`

These are passed into `CollageCanvas` and applied as SwiftUI modifiers.

## Platform Notes

- iOS-only (`#if canImport(UIKit)`). The macOS `#else` stub allows compilation without UIKit.
- Entitlements: App Sandbox enabled, user-selected read-only file access.
- No network usage; all media is local (Photos library or files).
