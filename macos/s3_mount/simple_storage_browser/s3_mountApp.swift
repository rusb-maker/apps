import SwiftUI

@main
struct S3MountApp: App {
    @State private var profileStore = ProfileStore()
    @State private var s3Service = S3Service()

    var body: some Scene {
        Window("S3 Browser", id: "main") {
            ContentView()
                .environment(profileStore)
                .environment(s3Service)
        }
        .defaultSize(width: 960, height: 620)
    }
}
