import SwiftUI

struct StatusMenuView: View {
    @Environment(ProfileStore.self) var profileStore
    @Environment(\.openWindow) var openWindow

    var body: some View {
        if profileStore.profiles.isEmpty {
            Text("No connections configured")
                .foregroundStyle(.secondary)
        } else {
            ForEach(profileStore.profiles) { profile in
                Button(profile.name) {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
        }

        Divider()

        Button("Open S3 Browser...") {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }

        Button("Quit S3 Browser") {
            NSApplication.shared.terminate(nil)
        }
    }
}
