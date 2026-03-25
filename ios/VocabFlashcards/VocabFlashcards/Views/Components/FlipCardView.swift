import SwiftUI

struct FlipCardView: View {
    let front: String
    let back: String
    let context: String
    @Binding var isFlipped: Bool

    var body: some View {
        ZStack {
            // Front
            cardFace {
                VStack(spacing: 16) {
                    Text(front)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    Text("Tap card to flip")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            // Back
            cardFace {
                VStack(spacing: 16) {
                    Text(back)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    if !context.isEmpty && context != back {
                        Divider()
                        Text(context)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .italic()
                    }
                }
            }
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .onTapGesture {
            isFlipped.toggle()
        }
        .animation(.easeInOut(duration: 0.4), value: isFlipped)
    }

    private func cardFace<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(32)
            .frame(maxWidth: .infinity, minHeight: 250)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.quaternary, lineWidth: 1)
            )
    }
}
