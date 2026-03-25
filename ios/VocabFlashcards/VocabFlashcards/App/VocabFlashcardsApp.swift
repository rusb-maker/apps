import SwiftUI
import SwiftData

@main
struct VocabFlashcardsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Card.self, CardGroup.self, RecordingSession.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
