import SwiftUI
import SwiftData

@main
struct VocabFlashcardsApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [Card.self, CardGroup.self, RecordingSession.self])
    }
}
