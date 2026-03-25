import SwiftUI

struct SettingsView: View {
    @AppStorage("llm_provider") private var selectedProvider = LLMProvider.gemini.rawValue
    @AppStorage("min_cefr_level") private var minCEFRLevel = CEFRLevel.b2.rawValue
    @State private var editingKey = ""
    @State private var showKey = false
    @State private var showProviderInfo = false

    private var provider: LLMProvider {
        LLMProvider(rawValue: selectedProvider) ?? .gemini
    }

    var body: some View {
        NavigationStack {
            Form {
                // Provider picker
                Section {
                    Picker("AI Provider", selection: $selectedProvider) {
                        ForEach(LLMProvider.allCases) { p in
                            HStack {
                                Text(p.displayName)
                                Spacer()
                                Text(p.tierBadge)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                            }
                            .tag(p.rawValue)
                        }
                    }

                    Button {
                        showProviderInfo = true
                    } label: {
                        Label("Compare providers", systemImage: "info.circle")
                    }
                } footer: {
                    Text(provider.apiKeyHelp)
                }

                // API Key
                Section {
                    HStack {
                        if showKey {
                            TextField(provider.apiKeyPlaceholder, text: $editingKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField(provider.apiKeyPlaceholder, text: $editingKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }

                    let currentKey = UserDefaults.standard.string(forKey: provider.settingsKey) ?? ""
                    if editingKey != currentKey {
                        Button("Save") {
                            UserDefaults.standard.set(editingKey, forKey: provider.settingsKey)
                        }
                        .bold()
                    }
                } header: {
                    Text("\(provider.displayName) API Key")
                }

                // Status
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        let key = UserDefaults.standard.string(forKey: provider.settingsKey) ?? ""
                        if key.isEmpty {
                            Label("Not configured", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                        } else {
                            Label("Ready", systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                    }
                }

                // CEFR Level
                Section {
                    Picker("Minimum Level", selection: $minCEFRLevel) {
                        ForEach(CEFRLevel.allCases) { level in
                            Text(level.rawValue).tag(level.rawValue)
                        }
                    }
                } header: {
                    Text("CEFR Level Filter")
                } footer: {
                    Text("Only extract phrases at this level or above. B2 recommended for upper-intermediate learners.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .onAppear {
                editingKey = UserDefaults.standard.string(forKey: provider.settingsKey) ?? ""
            }
            .onChange(of: selectedProvider) {
                editingKey = UserDefaults.standard.string(forKey: provider.settingsKey) ?? ""
                showKey = false
            }
            .sheet(isPresented: $showProviderInfo) {
                ProviderComparisonView()
            }
        }
    }
}

// MARK: - Provider Comparison

struct ProviderComparisonView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(LLMProvider.allCases) { provider in
                    ProviderInfoRow(provider: provider)
                }
            }
            .navigationTitle("AI Providers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ProviderInfoRow: View {
    let provider: LLMProvider

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(provider.displayName)
                    .font(.headline)
                Spacer()
                Text(provider.tierBadge)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.15))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
            }

            Text(providerDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // How to get key
            VStack(alignment: .leading, spacing: 4) {
                Text("How to get API key:")
                    .font(.caption)
                    .fontWeight(.semibold)
                ForEach(setupSteps, id: \.self) { step in
                    HStack(alignment: .top, spacing: 4) {
                        Text("•")
                        Text(step)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }

    private var badgeColor: Color {
        switch provider.tierColor {
        case "green": .green
        case "orange": .orange
        case "red": .red
        default: .blue
        }
    }

    private var providerDescription: String {
        switch provider {
        case .gemini:
            "Best free option. 250 req/day, excellent multilingual support. Recommended for most users."
        case .groq:
            "Fastest inference. 1,000 req/day on Llama 3.3 70B. Great for quick extractions."
        case .mistral:
            "Strong European AI. Free Experiment plan with 1B tokens/month. Good multilingual quality."
        case .openRouter:
            "Gateway to 29 free models. 200 req/day. Good as a fallback option."
        case .deepSeek:
            "Chinese AI lab. 5M free tokens on signup (valid 30 days). Very cheap after that."
        case .claude:
            "Highest quality but paid. Best for complex text analysis. No free tier."
        }
    }

    private var setupSteps: [String] {
        switch provider {
        case .gemini:
            [
                "Go to aistudio.google.com",
                "Sign in with Google account",
                "Click \"Get API Key\" → \"Create API key\"",
                "Copy the key starting with AIza..."
            ]
        case .groq:
            [
                "Go to console.groq.com",
                "Sign up (no credit card needed)",
                "Go to API Keys → \"Create API Key\"",
                "Copy the key starting with gsk_..."
            ]
        case .mistral:
            [
                "Go to console.mistral.ai",
                "Sign up with email + phone verification",
                "Choose \"Experiment\" plan (free)",
                "Go to API Keys → generate a key"
            ]
        case .openRouter:
            [
                "Go to openrouter.ai",
                "Sign up (no credit card needed)",
                "Go to Settings → Keys → \"Create Key\"",
                "Copy the key starting with sk-or-..."
            ]
        case .deepSeek:
            [
                "Go to platform.deepseek.com",
                "Sign up to get 5M free tokens",
                "Go to API Keys → create a key",
                "Copy the key starting with sk-..."
            ]
        case .claude:
            [
                "Go to console.anthropic.com",
                "Sign up and add billing info",
                "Go to API Keys → \"Create Key\"",
                "Copy the key starting with sk-ant-..."
            ]
        }
    }
}
