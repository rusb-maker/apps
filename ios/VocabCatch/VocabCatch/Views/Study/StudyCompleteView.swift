import SwiftUI

struct StudyCompleteView: View {
    let correct: Int
    let incorrect: Int
    let total: Int
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Session Complete!")
                .font(.title.bold())

            VStack(spacing: 12) {
                StatRow(label: "Reviewed", value: "\(total)", color: .primary)
                StatRow(label: "Correct", value: "\(correct)", color: .green)
                StatRow(label: "Incorrect", value: "\(incorrect)", color: .red)
                if total > 0 {
                    StatRow(
                        label: "Accuracy",
                        value: "\(Int(Double(correct) / Double(total) * 100))%",
                        color: .blue
                    )
                }
            }
            .padding()
            .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            Button("Study Again", action: onRestart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Spacer()
        }
    }
}

private struct StatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
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
