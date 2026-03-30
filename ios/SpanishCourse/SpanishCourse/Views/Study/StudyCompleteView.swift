import SwiftUI

struct StudyCompleteView: View {
    let correctCount: Int
    let incorrectCount: Int
    let totalCards: Int
    var hasMoreBatches: Bool = false
    var onStudyAgain: (() -> Void)?
    var onNextBatch: (() -> Void)?

    private var accuracy: Double {
        guard totalCards > 0 else { return 0 }
        return Double(correctCount) / Double(totalCards)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: accuracy >= 0.8 ? "star.fill" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(accuracy >= 0.8 ? .yellow : .green)

            Text("Сессия завершена!")
                .font(.title.bold())

            VStack(spacing: 16) {
                statRow(label: "Всего карточек", value: "\(totalCards)", color: .primary)
                statRow(label: "Правильно", value: "\(correctCount)", color: .green)
                statRow(label: "Неправильно", value: "\(incorrectCount)", color: .red)
                statRow(label: "Точность", value: "\(Int(accuracy * 100))%", color: accuracy >= 0.8 ? .green : .orange)
            }
            .padding()
            .background(.fill.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))

            Spacer()

            VStack(spacing: 12) {
                if hasMoreBatches, let onNextBatch {
                    Button {
                        onNextBatch()
                    } label: {
                        Label("Следующая пачка", systemImage: "arrow.right.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let onStudyAgain {
                    Button {
                        onStudyAgain()
                    } label: {
                        Text("Начать заново")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.fill)
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .padding()
    }

    private func statRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}
