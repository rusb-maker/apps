import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
            TextInputView()
                .tabItem {
                    Label("Text", systemImage: "doc.text")
                }
            GroupsListView()
                .tabItem {
                    Label("Groups", systemImage: "folder.fill")
                }
            StudySessionView()
                .tabItem {
                    Label("Study", systemImage: "brain.head.profile")
                }
            RecordingsListView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
