import SwiftUI

enum ProfileDetailMode {
    case add
    case edit(S3Profile)
}

struct ProfileDetailView: View {
    let mode: ProfileDetailMode
    @Environment(ProfileStore.self) var profileStore
    @Environment(\.dismiss) var dismiss

    @State private var profile = S3Profile()
    @State private var secretKey = ""
    @State private var saveError: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Name", text: $profile.name)
                    Picker("Storage Type", selection: $profile.storageType) {
                        ForEach(StorageType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("Credentials") {
                    TextField("Access Key ID", text: $profile.accessKeyID)
                    SecureField("Secret Access Key", text: $secretKey)
                }

                Section("Storage") {
                    TextField("Region", text: $profile.region)
                        .help("e.g. us-east-1")
                    TextField("Endpoint (optional)", text: $profile.endpoint)
                        .help("Leave empty for AWS. For Wasabi: https://s3.wasabisys.com")
                }

                if let error = saveError {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
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
                        .disabled(profile.name.isEmpty || profile.accessKeyID.isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 500)
        .onAppear(perform: loadExisting)
        .onChange(of: profile.storageType) { _, newType in
            let wasabiEndpoint = StorageType.wasabi.defaultEndpoint
            if profile.endpoint.isEmpty || profile.endpoint == wasabiEndpoint || newType == .wasabi {
                profile.endpoint = newType.defaultEndpoint
            }
        }
    }

    private func loadExisting() {
        if case .edit(let existing) = mode {
            profile = existing
            secretKey = (try? KeychainService.load(for: existing.keychainKey)) ?? ""
        }
    }

    private func save() {
        do {
            try KeychainService.save(secret: secretKey, for: profile.keychainKey)
            if isEditing {
                profileStore.update(profile)
            } else {
                profileStore.add(profile)
            }
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
