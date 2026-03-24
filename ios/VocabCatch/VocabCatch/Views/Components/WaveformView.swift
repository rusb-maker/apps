import SwiftUI

struct WaveformView: View {
    let level: Float
    let isRecording: Bool

    @State private var bars: [CGFloat] = Array(repeating: 0.1, count: 30)

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<bars.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(isRecording ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 4, height: max(4, bars[index] * 80))
            }
        }
        .onChange(of: level) { _, newLevel in
            guard isRecording else { return }
            withAnimation(.easeOut(duration: 0.1)) {
                bars.removeFirst()
                let normalized = CGFloat(min(1.0, newLevel * 5))
                bars.append(max(0.05, normalized))
            }
        }
        .onChange(of: isRecording) { _, recording in
            if !recording {
                withAnimation(.easeOut(duration: 0.3)) {
                    bars = Array(repeating: 0.1, count: 30)
                }
            }
        }
    }
}
