import SwiftUI

struct AIProviderSettingsView: View {
    @AppStorage("llm_provider") private var selectedProvider = LLMProvider.gemini.rawValue
    @State private var showingKey = false

    private var provider: LLMProvider {
        LLMProvider(rawValue: selectedProvider) ?? .gemini
    }

    var body: some View {
        List {
            Section("Провайдер") {
                ForEach(LLMProvider.allCases) { p in
                    Button {
                        selectedProvider = p.rawValue
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(p.displayName)
                                        .foregroundStyle(.primary)
                                    Text(p.tierBadge)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(tierColor(p).opacity(0.2))
                                        .foregroundStyle(tierColor(p))
                                        .clipShape(Capsule())
                                }
                                Text(p.apiKeyHelp)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if p.rawValue == selectedProvider {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }

            Section("API-ключ") {
                HStack {
                    if showingKey {
                        TextField(provider.apiKeyPlaceholder, text: apiKeyBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField(provider.apiKeyPlaceholder, text: apiKeyBinding)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Button {
                        showingKey.toggle()
                    } label: {
                        Image(systemName: showingKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    if apiKeyBinding.wrappedValue.isEmpty {
                        Label("Не настроен", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    } else {
                        Label("Настроен", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("AI-провайдер")
        .themed()
    }

    private var apiKeyBinding: Binding<String> {
        Binding(
            get: { UserDefaults.standard.string(forKey: provider.settingsKey) ?? "" },
            set: { UserDefaults.standard.set($0, forKey: provider.settingsKey) }
        )
    }

    private func tierColor(_ provider: LLMProvider) -> Color {
        switch provider.tierColor {
        case "green": .green
        case "orange": .orange
        case "red": .red
        default: .gray
        }
    }
}
