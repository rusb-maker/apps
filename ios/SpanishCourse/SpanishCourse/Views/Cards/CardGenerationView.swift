import SwiftUI
import SwiftData

struct CardGenerationView: View {
    let lesson: Lesson
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CardGenerationViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Параметры") {
                    Stepper("Количество карточек: \(viewModel.cardCount)", value: $viewModel.cardCount, in: 1...20)
                }

                Section("Дополнительные инструкции") {
                    TextField("Например: больше спряжений, фразы для ресторана...", text: $viewModel.additionalPrompt, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    if viewModel.isGenerating {
                        HStack {
                            ProgressView()
                            Text("Генерация карточек...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task {
                                await viewModel.generateCards(for: lesson, context: modelContext)
                                if viewModel.errorMessage == nil {
                                    dismiss()
                                }
                            }
                        } label: {
                            Label("Сгенерировать", systemImage: "sparkles")
                        }
                    }
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if viewModel.generatedCount > 0 {
                    Section {
                        Label("Создано \(viewModel.generatedCount) карточек", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Генерация карточек")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .disabled(viewModel.isGenerating)
        }
    }
}
