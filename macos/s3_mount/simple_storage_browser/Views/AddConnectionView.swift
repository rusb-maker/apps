import SwiftUI

struct AddConnectionView: View {
    enum Mode { case add; case edit(S3Profile) }

    let mode: Mode
    @Environment(ProfileStore.self) var profileStore
    @Environment(\.dismiss) var dismiss

    @State private var profile = S3Profile()
    @State private var secretKey = ""
    @State private var saveError: String?

    private var isEditing: Bool { if case .edit = mode { true } else { false } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Name", text: $profile.name)
                        .help("Display name for this connection")
                    Picker("Type", selection: $profile.storageType) {
                        ForEach(StorageType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                }

                Section("Credentials") {
                    TextField("Access Key ID", text: $profile.accessKeyID)
                    SecureField("Secret Access Key", text: $secretKey)
                }

                Section("Endpoint") {
                    TextField("Region", text: $profile.region)
                        .help("e.g. us-east-1")
                    TextField("Custom Endpoint (optional)", text: $profile.endpoint)
                        .help("Leave empty for AWS. Wasabi: https://s3.wasabisys.com")
                }

                if let err = saveError {
                    Section { Text(err).foregroundStyle(.red) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Connection" : "New Connection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .buttonStyle(.glass)
                        .disabled(profile.name.isEmpty || profile.accessKeyID.isEmpty || secretKey.isEmpty)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 400)
        .onAppear {
            if case .edit(let p) = mode {
                profile = p
                secretKey = (try? KeychainService.load(for: p.keychainKey)) ?? ""
            }
        }
        .onChange(of: profile.storageType) { _, newType in
            if profile.endpoint.isEmpty || profile.endpoint == StorageType.wasabi.defaultEndpoint {
                profile.endpoint = newType.defaultEndpoint
            }
        }
    }

    private func save() {
        do {
            try KeychainService.save(secret: secretKey, for: profile.keychainKey)
            if isEditing { profileStore.update(profile) } else { profileStore.add(profile) }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
