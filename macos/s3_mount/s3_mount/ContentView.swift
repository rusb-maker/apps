import SwiftUI

struct ContentView: View {
    @Environment(ProfileStore.self) var profileStore
    @Environment(S3Service.self) var s3Service

    @State private var selectedProfileID: UUID?
    @State private var showingAdd = false
    @State private var editingProfile: S3Profile?

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebarView
        } detail: {
            if let id = selectedProfileID,
               let profile = profileStore.profiles.first(where: { $0.id == id }) {
                FileBrowserView(profile: profile)
                    .environment(s3Service)
                    .id(profile.id)
            } else {
                emptyDetail
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAdd) {
            AddConnectionView(mode: .add)
                .environment(profileStore)
        }
        .sheet(item: $editingProfile) { p in
            AddConnectionView(mode: .edit(p))
                .environment(profileStore)
        }
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        List(selection: $selectedProfileID) {
            profilesList
        }
        .listStyle(.sidebar)
        .navigationTitle("Connections")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .overlay {
            if profileStore.profiles.isEmpty {
                emptyProfilesView
            }
        }
    }
    
    private var profilesList: some View {
        ForEach(profileStore.profiles) { profile in
            profileRow(profile)
                .tag(profile.id)
                .contextMenu {
                    Button("Edit…") { editingProfile = profile }
                    Divider()
                    Button("Delete", role: .destructive) {
                        if selectedProfileID == profile.id { selectedProfileID = nil }
                        profileStore.delete(profile)
                    }
                }
        }
    }
    
    private func profileRow(_ profile: S3Profile) -> some View {
        HStack(spacing: 10) {
            let icon = profile.storageType == .wasabi ? "bolt.fill" : "cloud.fill"
            let color: Color = profile.storageType == .wasabi ? .orange : .blue
            
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name).fontWeight(.medium)
                Text(profile.storageType.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    
    private var emptyProfilesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No connections").foregroundStyle(.secondary)
            Button("Add Connection") { showingAdd = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    // MARK: - Empty detail

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Select a connection")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Choose a connection from the sidebar to browse files.")
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
