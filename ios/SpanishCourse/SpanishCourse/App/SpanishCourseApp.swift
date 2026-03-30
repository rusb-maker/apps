import SwiftUI
import SwiftData

@main
struct SpanishCourseApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Card.self, LessonProgress.self, CardFolder.self, UserStats.self])
        let config = ModelConfiguration(schema: schema)
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
