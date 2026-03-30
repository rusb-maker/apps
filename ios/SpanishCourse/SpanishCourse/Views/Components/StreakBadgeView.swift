import SwiftUI

struct StreakBadgeView: View {
    let streak: Int
    var size: CGFloat = 44

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .font(.system(size: size * 0.5))
                .foregroundStyle(streak > 0 ? flameColor : .gray)
            Text("\(streak)")
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(streak > 0 ? flameColor : .gray)
        }
    }

    private var flameColor: Color {
        if streak >= 30 { return .red }
        if streak >= 7 { return .orange }
        return .yellow
    }
}
