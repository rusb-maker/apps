import Foundation
import Observation

@Observable
final class ProfileStore {
    private(set) var profiles: [S3Profile] = []
    private let storageURL: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".ssb", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("profiles.json")
        load()
    }

    func add(_ profile: S3Profile) {
        profiles.append(profile)
        save()
    }

    func update(_ profile: S3Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
        save()
    }

    func delete(_ profile: S3Profile) {
        profiles.removeAll { $0.id == profile.id }
        try? KeychainService.delete(for: profile.keychainKey)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([S3Profile].self, from: data) else { return }
        profiles = decoded
    }
}
