import Foundation
import Observation
import Darwin

enum MountError: LocalizedError {
    case rcloneNotFound
    case macFUSENotInstalled
    case mountPointCreationFailed(String)
    case missingSecretKey

    var errorDescription: String? {
        switch self {
        case .rcloneNotFound:
            return "rclone not found. Install it with: brew install rclone"
        case .macFUSENotInstalled:
            return "macFUSE is not installed. Download it from macfuse.github.io"
        case .mountPointCreationFailed(let msg):
            return "Failed to create mount point: \(msg)"
        case .missingSecretKey:
            return "Secret key not found. Re-enter it in the connection settings."
        }
    }
}

@Observable
final class RcloneService {
    private var processes: [UUID: Process] = [:]
    private(set) var mountStates: [UUID: MountState] = [:]

    var rclonePath: String = UserDefaults.standard.string(forKey: "rclonePath") ?? "/opt/homebrew/bin/rclone" {
        didSet {
            UserDefaults.standard.set(rclonePath, forKey: "rclonePath")
            refreshAvailability()
        }
    }

    private(set) var isRcloneAvailable: Bool = false
    private(set) var isMacFUSEInstalled: Bool = false

    init() {
        refreshAvailability()
    }

    func refreshAvailability() {
        let path = rclonePath
        Task.detached(priority: .userInitiated) { [weak self] in
            let rcloneFound = RcloneService.findRclone(configuredPath: path) != nil
            let fuseFound = FileManager.default.fileExists(atPath: "/Library/Filesystems/macfuse.fs")
            await MainActor.run { [weak self] in
                self?.isRcloneAvailable = rcloneFound
                self?.isMacFUSEInstalled = fuseFound
            }
        }
    }

    // MARK: - Dependency resolution

    nonisolated static func findRclone(configuredPath: String) -> String? {
        let candidates = [
            configuredPath,
            "/opt/homebrew/bin/rclone",
            "/usr/local/bin/rclone",
            "/usr/bin/rclone"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        p.arguments = ["rclone"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.isEmpty ? nil : output
    }

    func mountState(for profileID: UUID) -> MountState {
        if let state = mountStates[profileID] { return state }
        let state = MountState(profileID: profileID)
        mountStates[profileID] = state
        return state
    }

    // MARK: - Mount

    func mount(profile: S3Profile, secretKey: String) async throws {
        guard isRcloneAvailable, let rclone = RcloneService.findRclone(configuredPath: rclonePath) else {
            throw MountError.rcloneNotFound
        }
        guard isMacFUSEInstalled else {
            throw MountError.macFUSENotInstalled
        }

        let state = mountState(for: profile.id)
        guard !state.isMounted && !state.status.isBusy else { return }

        let mountPath = profile.effectiveMountPath

        do {
            try FileManager.default.createDirectory(
                atPath: mountPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw MountError.mountPointCreationFailed(error.localizedDescription)
        }

        state.status = .mounting
        state.logLines = []

        let remote = buildRemote(profile: profile, secretKey: secretKey)
        let args = [
            "mount", remote, mountPath,
            "--vfs-cache-mode", profile.vfsCacheMode,
            "--volname", profile.name,
            "--log-level", "INFO",
            "--no-checksum"
        ]

        let process = Process()
        process.executableURL = URL(fileURLWithPath: rclone)
        process.arguments = args

        let errPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = errPipe

        let profileID = profile.id

        process.terminationHandler = { [weak self] p in
            Task { @MainActor [weak self] in
                guard let self, let state = self.mountStates[profileID] else { return }
                self.processes.removeValue(forKey: profileID)
                switch state.status {
                case .unmounting:
                    state.status = .unmounted
                case .mounted, .mounting:
                    state.status = p.terminationStatus != 0
                        ? .failed("rclone exited with code \(p.terminationStatus)")
                        : .unmounted
                default:
                    break
                }
                state.pid = nil
            }
        }

        try process.run()
        processes[profileID] = process
        state.pid = process.processIdentifier

        // Read stderr for log lines and mount detection
        Task.detached(priority: .utility) { [weak self] in
            let handle = errPipe.fileHandleForReading
            for try await line in handle.bytes.lines {
                await MainActor.run { [weak self] in
                    guard let self, let state = self.mountStates[profileID] else { return }
                    state.logLines.append(line)
                    if state.logLines.count > 300 { state.logLines.removeFirst() }
                    if case .mounting = state.status {
                        if line.contains("Serving remote control") ||
                           line.contains("Local file system at") ||
                           line.contains("Serving on") {
                            state.status = .mounted
                        }
                    }
                }
            }
        }

        // Poll via statfs as fallback for mount detection
        let capturedMountPath = mountPath
        Task { @MainActor [weak self] in
            guard let self else { return }
            let deadline = Date().addingTimeInterval(15)
            while Date() < deadline {
                try? await Task.sleep(for: .milliseconds(500))
                guard let state = self.mountStates[profileID] else { return }
                if case .mounting = state.status {
                    if RcloneService.isPathMountedStatic(capturedMountPath) {
                        state.status = .mounted
                        return
                    }
                } else {
                    return // Already resolved (mounted or failed)
                }
            }
            guard let state = self.mountStates[profileID],
                  case .mounting = state.status else { return }
            state.status = .failed("Mount timed out. Check credentials and connection settings.")
            self.processes[profileID]?.terminate()
            self.processes.removeValue(forKey: profileID)
        }
    }

    // MARK: - Unmount

    func unmount(profile: S3Profile) async throws {
        let state = mountState(for: profile.id)
        state.status = .unmounting

        let mountPath = profile.effectiveMountPath

        await Task.detached(priority: .userInitiated) {
            let diskutil = Process()
            diskutil.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            diskutil.arguments = ["unmount", mountPath]
            diskutil.standardOutput = Pipe()
            diskutil.standardError = Pipe()
            try? diskutil.run()
            diskutil.waitUntilExit()

            if RcloneService.isPathMountedStatic(mountPath) {
                let umount = Process()
                umount.executableURL = URL(fileURLWithPath: "/sbin/umount")
                umount.arguments = [mountPath]
                umount.standardOutput = Pipe()
                umount.standardError = Pipe()
                try? umount.run()
                umount.waitUntilExit()
            }
        }.value

        if let proc = processes[profile.id], proc.isRunning {
            proc.terminate()
        }
        processes.removeValue(forKey: profile.id)
        state.status = .unmounted
        state.pid = nil
    }

    // MARK: - Cleanup

    func unmountAll() {
        for (_, proc) in processes where proc.isRunning {
            proc.terminate()
        }
        processes.removeAll()
    }

    // MARK: - Private

    private func buildRemote(profile: S3Profile, secretKey: String) -> String {
        var params = [
            "access_key_id=\(profile.accessKeyID)",
            "secret_access_key=\(secretKey)"
        ]
        if !profile.region.isEmpty {
            params.append("region=\(profile.region)")
        }
        if !profile.endpoint.isEmpty {
            params.append("endpoint=\(profile.endpoint)")
        }
        if profile.storageType == .wasabi {
            params.append("provider=Wasabi")
        }
        return ":s3,\(params.joined(separator: ",")):"
    }

    nonisolated static func isPathMountedStatic(_ path: String) -> Bool {
        var mountStats = statfs()
        var parentStats = statfs()
        let parent = (path as NSString).deletingLastPathComponent
        guard statfs(path, &mountStats) == 0, statfs(parent, &parentStats) == 0 else { return false }
        return mountStats.f_fsid.val.0 != parentStats.f_fsid.val.0 ||
               mountStats.f_fsid.val.1 != parentStats.f_fsid.val.1
    }
}
