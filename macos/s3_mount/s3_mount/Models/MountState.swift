import Foundation
import Observation

enum MountStatus: Equatable {
    case unmounted
    case mounting
    case mounted
    case failed(String)
    case unmounting

    var description: String {
        switch self {
        case .unmounted: return "Unmounted"
        case .mounting: return "Mounting..."
        case .mounted: return "Mounted"
        case .failed(let msg): return "Error: \(msg)"
        case .unmounting: return "Unmounting..."
        }
    }

    var isBusy: Bool {
        switch self {
        case .mounting, .unmounting: return true
        default: return false
        }
    }
}

@Observable
final class MountState {
    var profileID: UUID
    var status: MountStatus = .unmounted
    var pid: pid_t?
    var logLines: [String] = []

    init(profileID: UUID) {
        self.profileID = profileID
    }

    var isMounted: Bool {
        if case .mounted = status { return true }
        return false
    }
}
