# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `simple_storage_browser.xcodeproj` in Xcode and build/run from there (`Cmd+R`). There is no CLI build command set up.

Run tests via Xcode (`Cmd+U`) or:
```
xcodebuild test -project simple_storage_browser.xcodeproj -scheme simple_storage_browser -destination 'platform=macOS'
```

## Architecture

Menu bar app that mounts S3/Wasabi buckets as macFUSE volumes using `rclone` as a subprocess.

**Two scenes:**
- `Window("S3 Mount")` — main config UI (`ContentView`)
- `MenuBarExtra` — quick-access dropdown (`StatusMenuView`)

**State is managed by two `@Observable` singletons injected via `.environment()`:**
- `ProfileStore` — persists connection profiles as JSON in `~/Library/Application Support/com.test-rb.s3-mount/profiles.json`
- `RcloneService` — owns `Process` instances, drives `MountState` per profile

**Mount lifecycle (`RcloneService`):**
1. Build an inline rclone remote string (no config file on disk): `:s3,access_key_id=...,secret_access_key=...,...:bucket`
2. Spawn `rclone mount` with stderr piped; read lines asynchronously via `AsyncBytes`
3. Detect mount success from stderr keywords (`"Serving remote control"`, `"Local file system at"`) OR by polling `statfs()` comparing the mount path's fsid to its parent
4. Timeout after 15 s → `.failed(...)`
5. Unmount: `diskutil unmount` → fallback `/sbin/umount` → `process.terminate()`

**Secret keys** are stored only in Keychain (`KeychainService`), never written to disk. Each profile has a `keychainKey` derived from its UUID.

## Swift Concurrency

- Project-wide `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor`
- `nonisolated static` is used on `findRclone()` and `isPathMountedStatic()` to avoid blocking the main thread
- Log reading runs in `Task.detached(priority: .utility)` using `FileHandle.bytes.lines`
- `process.terminationHandler` dispatches back via `Task { @MainActor in ... }`

## Key Constraints

- App sandbox is **disabled** (`ENABLE_APP_SANDBOX = NO`) — required for spawning subprocesses
- macOS deployment target: **26.2**
- Runtime dependencies: `rclone` (default: `/opt/homebrew/bin/rclone`) and `macFUSE` (`/Library/Filesystems/macfuse.fs`)
- Default mount path: `/Volumes/<profile-name>`; overridable per profile
