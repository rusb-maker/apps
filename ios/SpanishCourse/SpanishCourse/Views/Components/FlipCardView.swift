import SwiftUI

struct FlipCardView: View {
    let front: String
    let back: String
    let context: String
    @Binding var isFlipped: Bool
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            // Front
            cardFace {
                VStack(spacing: 16) {
                    Text(front)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    SpeakButton(text: front)

                    Text("Нажмите, чтобы перевернуть")
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
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    if !context.isEmpty && context != back {
                        Divider()
                        HStack {
                            Text(context)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .italic()
                            SpeakButton(text: context, size: .small)
                        }
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
        .animation(.easeInOut(duration: 0.6), value: isFlipped)
    }

    private func cardFace<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(32)
            .frame(maxWidth: .infinity, minHeight: 250)
            .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(theme.accentColor.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Reusable speak button

struct SpeakButton: View {
    let text: String
    var size: SpeakButtonSize = .regular
    @Environment(\.appTheme) private var theme

    enum SpeakButtonSize {
        case regular, small
    }

    var body: some View {
        Button {
            SpanishTTS.shared.speak(text)
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(size == .regular ? .title3 : .caption)
                .foregroundStyle(theme.accentColor)
        }
        .buttonStyle(.plain)
    }
}
