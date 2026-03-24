import SwiftUI

struct SettingsView: View {
    @AppStorage("anthropic_api_key") private var apiKey = ""
    @State private var editingKey = ""
    @State private var showKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        if showKey {
                            TextField("sk-ant-...", text: $editingKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("sk-ant-...", text: $editingKey)
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

                    if editingKey != apiKey {
                        Button("Save") {
                            apiKey = editingKey
                        }
                        .bold()
                    }
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Used to analyze transcripts with Claude AI. Get your key at console.anthropic.com")
                }

                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        if apiKey.isEmpty {
                            Label("Not configured", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                        } else {
                            Label("Ready", systemImage: "checkmark.circle")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                editingKey = apiKey
            }
        }
    }
}
