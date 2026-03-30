import SwiftUI

enum TimeUnit: String, CaseIterable {
    case minutes = "мин"
    case hours = "ч"
    case days = "дн"

    func toMinutes(_ value: Int) -> Int {
        switch self {
        case .minutes: value
        case .hours: value * 60
        case .days: value * 1440
        }
    }

    func fromMinutes(_ minutes: Int) -> Int {
        switch self {
        case .minutes: minutes
        case .hours: minutes / 60
        case .days: minutes / 1440
        }
    }

    var maxValue: Int {
        switch self {
        case .minutes: 120
        case .hours: 48
        case .days: 90
        }
    }
}

struct SettingsView: View {
    @Environment(\.appTheme) private var theme
    @AppStorage("app_theme") private var themeName: String = AppTheme.system.rawValue
    @AppStorage("max_cards_per_generation") private var maxCards = 10

    @AppStorage("study_again_minutes") private var againMinutes = 0
    @AppStorage("study_hard_minutes") private var hardMinutes = 2
    @AppStorage("study_good_minutes") private var goodMinutes = 1440
    @AppStorage("study_easy_minutes") private var easyMinutes = 2880

    @State private var againUnit: TimeUnit = .minutes
    @State private var hardUnit: TimeUnit = .minutes
    @State private var goodUnit: TimeUnit = .days
    @State private var easyUnit: TimeUnit = .days

    @State private var againValue = 0
    @State private var hardValue = 2
    @State private var goodValue = 1
    @State private var easyValue = 2

    var body: some View {
        List {
            // MARK: - Theme
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases) { t in
                            ThemePreviewButton(
                                theme: t,
                                isSelected: t.rawValue == themeName,
                                action: { themeName = t.rawValue }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Оформление")
            }

            // MARK: - Voice
            Section {
                let tts = SpanishTTS.shared
                LabeledContent("Голос", value: tts.selectedVoice?.name ?? "—")
                LabeledContent("Качество") {
                    Text(tts.voiceQualityName)
                        .foregroundStyle(tts.hasPremiumVoice ? .green : .orange)
                }

                if !tts.hasPremiumVoice {
                    Label("Скачайте улучшенный голос в Настройках iOS → Универсальный доступ → Устный контент → Голоса → Испанский", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Тест") {
                        SpanishTTS.shared.speak("Hola, me llamo Mónica. ¿Cómo estás hoy?")
                    }
                    Spacer()
                    Button("Обновить") {
                        SpanishTTS.shared.refreshVoice()
                    }
                }
            } header: {
                Text("Озвучка")
            }

            // MARK: - Intervals
            Section {
                intervalRow(label: "Снова", value: $againValue, unit: $againUnit, save: saveAgain)
                intervalRow(label: "Трудно", value: $hardValue, unit: $hardUnit, save: saveHard)
                intervalRow(label: "Хорошо", value: $goodValue, unit: $goodUnit, save: saveGood)
                intervalRow(label: "Легко", value: $easyValue, unit: $easyUnit, save: saveEasy)
            } header: {
                Text("Интервалы повторения")
            } footer: {
                Text("Начальные интервалы SM-2. Выберите единицу и значение для каждой кнопки.")
            }

            // MARK: - AI
            Section {
                NavigationLink("AI-провайдер") {
                    AIProviderSettingsView()
                }
                Stepper("Карточек за генерацию: \(maxCards)", value: $maxCards, in: 1...20)
            } header: {
                Text("AI-генерация")
            }

            // MARK: - About
            Section {
                LabeledContent("Версия", value: "1.0")
                LabeledContent("Уроков", value: "236")
                LabeledContent("Уровни", value: "A0 — B2")
            } header: {
                Text("О приложении")
            }
        }
        .navigationTitle("Настройки")
        .themed()
        .onAppear { loadValues() }
    }

    // MARK: - Interval Row

    private func intervalRow(label: String, value: Binding<Int>, unit: Binding<TimeUnit>, save: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value.wrappedValue) \(unit.wrappedValue.rawValue)")
                    .font(.body.bold())
                    .foregroundStyle(theme.accentColor)
            }
            HStack {
                Picker("", selection: unit) {
                    ForEach(TimeUnit.allCases, id: \.self) { u in
                        Text(u.rawValue).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .onChange(of: unit.wrappedValue) { _, newUnit in
                    let currentMinutes = storedMinutes(for: label)
                    value.wrappedValue = max(minValue(label), newUnit.fromMinutes(currentMinutes))
                    save()
                }

                Spacer()

                Stepper("", value: value, in: minValue(label)...unit.wrappedValue.maxValue)
                    .onChange(of: value.wrappedValue) { _, _ in save() }
            }
        }
        .padding(.vertical, 2)
    }

    private func minValue(_ label: String) -> Int {
        label == "Снова" ? 0 : 1
    }

    private func storedMinutes(for label: String) -> Int {
        switch label {
        case "Снова": againMinutes
        case "Трудно": hardMinutes
        case "Хорошо": goodMinutes
        case "Легко": easyMinutes
        default: 0
        }
    }

    private func loadValues() {
        (againUnit, againValue) = bestUnit(againMinutes, allowZero: true)
        (hardUnit, hardValue) = bestUnit(hardMinutes, allowZero: false)
        (goodUnit, goodValue) = bestUnit(goodMinutes, allowZero: false)
        (easyUnit, easyValue) = bestUnit(easyMinutes, allowZero: false)
    }

    private func bestUnit(_ minutes: Int, allowZero: Bool) -> (TimeUnit, Int) {
        if minutes == 0 && allowZero { return (.minutes, 0) }
        if minutes >= 1440 && minutes % 1440 == 0 { return (.days, minutes / 1440) }
        if minutes >= 60 { return (.hours, minutes / 60) }
        return (.minutes, minutes)
    }

    private func saveAgain() { againMinutes = againUnit.toMinutes(againValue) }
    private func saveHard() { hardMinutes = hardUnit.toMinutes(hardValue) }
    private func saveGood() { goodMinutes = goodUnit.toMinutes(goodValue) }
    private func saveEasy() { easyMinutes = easyUnit.toMinutes(easyValue) }
}

// MARK: - Theme Preview Button

struct ThemePreviewButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.previewColors[0])
                        .frame(width: 56, height: 40)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.previewColors[1])
                        .frame(width: 30, height: 20)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? theme.accentColor : .gray.opacity(0.3), lineWidth: isSelected ? 2.5 : 1)
                )

                Image(systemName: theme.icon)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? theme.accentColor : .secondary)

                Text(theme.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
