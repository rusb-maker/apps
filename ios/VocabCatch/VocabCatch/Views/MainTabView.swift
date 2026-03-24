import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Record", systemImage: "mic.fill") {
                RecordingView()
            }
            Tab("Groups", systemImage: "folder.fill") {
                GroupsListView()
            }
            Tab("Study", systemImage: "brain.head.profile") {
                StudySessionView()
            }
        }
    }
}
