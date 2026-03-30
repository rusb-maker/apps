import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case sepia
    case ocean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Системная"
        case .light: "Светлая"
        case .dark: "Тёмная"
        case .sepia: "Сепия"
        case .ocean: "Океан"
        }
    }

    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        case .sepia: "book.fill"
        case .ocean: "water.waves"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .sepia: .light
        case .dark, .ocean: .dark
        }
    }

    // MARK: - Custom Colors

    var accentColor: Color {
        switch self {
        case .system, .light, .dark: .blue
        case .sepia: Color(red: 0.6, green: 0.35, blue: 0.15)
        case .ocean: Color(red: 0.2, green: 0.6, blue: 0.85)
        }
    }

    var cardBackground: Color {
        switch self {
        case .system, .light, .dark: Color(.systemBackground)
        case .sepia: Color(red: 0.96, green: 0.93, blue: 0.87)
        case .ocean: Color(red: 0.1, green: 0.15, blue: 0.25)
        }
    }

    var pageBackground: Color {
        switch self {
        case .system, .light, .dark: Color(.systemGroupedBackground)
        case .sepia: Color(red: 0.94, green: 0.90, blue: 0.82)
        case .ocean: Color(red: 0.08, green: 0.12, blue: 0.2)
        }
    }

    var primaryText: Color {
        switch self {
        case .system, .light, .dark: .primary
        case .sepia: Color(red: 0.3, green: 0.2, blue: 0.1)
        case .ocean: Color(red: 0.85, green: 0.9, blue: 0.95)
        }
    }

    var secondaryText: Color {
        switch self {
        case .system, .light, .dark: .secondary
        case .sepia: Color(red: 0.5, green: 0.4, blue: 0.3)
        case .ocean: Color(red: 0.5, green: 0.65, blue: 0.8)
        }
    }

    var previewColors: [Color] {
        switch self {
        case .system: [.white, .black]
        case .light: [.white, Color(.systemGray6)]
        case .dark: [Color(.darkGray), .black]
        case .sepia: [Color(red: 0.96, green: 0.93, blue: 0.87), Color(red: 0.6, green: 0.35, blue: 0.15)]
        case .ocean: [Color(red: 0.1, green: 0.15, blue: 0.25), Color(red: 0.2, green: 0.6, blue: 0.85)]
        }
    }

    /// Whether this theme needs custom background (not just light/dark)
    var isCustom: Bool {
        switch self {
        case .sepia, .ocean: true
        default: false
        }
    }
}

// MARK: - View Modifier

struct ThemeModifier: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        if theme.isCustom {
            content
                .scrollContentBackground(.hidden)
                .background(theme.pageBackground)
                .foregroundStyle(theme.primaryText)
        } else {
            content
        }
    }
}

extension View {
    func themed() -> some View {
        modifier(ThemeModifier())
    }
}

// MARK: - Environment Key

struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .system
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
