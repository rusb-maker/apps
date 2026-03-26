import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                NavigationLink {
                    AIProviderSettingsView()
                } label: {
                    Label("AI Provider", systemImage: "cpu")
                }

                NavigationLink {
                    StudyIntervalsSettingsView()
                } label: {
                    Label("Study Intervals", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
