import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    var size: CGFloat = 60
    var lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(.fill, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(progressColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)

            Text("\(Int(progress * 100))%")
                .font(.system(size: max(12, size * 0.25), weight: .bold, design: .rounded))
                .foregroundStyle(progressColor)
        }
        .frame(width: size, height: size)
    }

    private var progressColor: Color {
        if progress >= 0.8 { return .green }
        if progress >= 0.5 { return .orange }
        return .blue
    }
}
