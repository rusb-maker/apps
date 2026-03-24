import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
            GroupsListView()
                .tabItem {
                    Label("Groups", systemImage: "folder.fill")
                }
            StudySessionView()
                .tabItem {
                    Label("Study", systemImage: "brain.head.profile")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
