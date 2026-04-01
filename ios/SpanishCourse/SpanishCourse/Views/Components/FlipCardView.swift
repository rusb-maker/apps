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
                VStack(spacing: 12) {
                    // Full sentence (context) — large, with speak
                    if !context.isEmpty && context != back {
                        HStack {
                            Text(context)
                                .font(.title3.bold())
                                .multilineTextAlignment(.center)
                            SpeakButton(text: context, size: .regular)
                        }
                        Divider()
                    }
                    // Answer + rule + translation
                    Text(back)
                        .font(back.count > 40 ? .subheadline : .title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(context.isEmpty ? .primary : .secondary)
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

    /// Clean text for TTS: remove ___, remove Russian, remove parenthetical rules
    private var speakableText: String {
        var clean = text
        // Remove ___ (blank markers)
        clean = clean.replacingOccurrences(of: "___", with: "")
        // Remove content in parentheses (hints like "(hablar)", "(ESTAR — состояние)")
        while let start = clean.range(of: "("), let end = clean.range(of: ")", range: start.upperBound..<clean.endIndex) {
            clean.removeSubrange(start.lowerBound...end.lowerBound)
        }
        // Remove Russian text (lines with Cyrillic)
        let lines = clean.components(separatedBy: "\n")
        let spanishLines = lines.filter { line in
            !line.contains(where: { $0 >= "\u{0400}" && $0 <= "\u{04FF}" })
        }
        clean = spanishLines.joined(separator: " ")
        // Clean up whitespace
        clean = clean.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
        return clean
    }

    /// Whether there's anything meaningful to speak
    private var canSpeak: Bool {
        !speakableText.isEmpty && speakableText.count > 1
    }

    var body: some View {
        if canSpeak {
            Button {
                SpanishTTS.shared.speak(speakableText)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(size == .regular ? .title3 : .caption)
                    .foregroundStyle(theme.accentColor)
            }
            .buttonStyle(.plain)
        }
    }
}
