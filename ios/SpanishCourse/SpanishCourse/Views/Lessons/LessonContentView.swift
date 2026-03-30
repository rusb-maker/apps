import SwiftUI

struct LessonContentView: View {
    let lesson: Lesson
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(lesson.level.rawValue)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(lesson.level.color.opacity(0.2))
                                .foregroundStyle(lesson.level.color)
                                .clipShape(Capsule())
                            Text("Урок \(lesson.order)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(lesson.title)
                            .font(.title.bold())
                        Text(lesson.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Lesson content
                    Text(verbatim: lesson.content)
                        .font(.body)
                        .lineSpacing(6)

                    Divider()

                    // Vocabulary table with speak
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Словарь урока")
                            .font(.title3.bold())

                        ForEach(lesson.keyVocabulary) { vocab in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(vocab.spanish)
                                        .font(.body.bold())
                                        .onLongPressGesture {
                                            SpanishTTS.shared.speak(vocab.spanish)
                                        }
                                    SpeakButton(text: vocab.spanish, size: .small)
                                    Text("—")
                                        .foregroundStyle(.tertiary)
                                    Text(vocab.russian)
                                        .foregroundStyle(.secondary)
                                }
                                if let example = vocab.example, !example.isEmpty {
                                    HStack {
                                        Text(example)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .italic()
                                            .onLongPressGesture {
                                                SpanishTTS.shared.speak(example)
                                            }
                                        SpeakButton(text: example, size: .small)
                                    }
                                }
                            }
                        }
                    }

                    // Grammar points
                    if !lesson.grammarPoints.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Грамматика")
                                .font(.title3.bold())
                            ForEach(lesson.grammarPoints, id: \.self) { point in
                                Label(point, systemImage: "lightbulb.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Урок")
            .navigationBarTitleDisplayMode(.inline)
            .background(theme.isCustom ? theme.pageBackground : Color.clear)
            .foregroundStyle(theme.isCustom ? theme.primaryText : .primary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
        }
    }
}
