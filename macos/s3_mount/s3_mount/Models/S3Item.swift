import Foundation
import Observation

struct S3Bucket: Identifiable {
    var id: String { name }
    let name: String
}

struct S3Object: Identifiable {
    var id: String { key }
    let key: String
    let name: String
    let isFolder: Bool
    var size: Int64 = 0
    var lastModified: Date?

    var formattedSize: String {
        guard !isFolder else { return "—" }
        let b = Double(size)
        if b < 1_024 { return "\(size) B" }
        if b < 1_048_576 { return String(format: "%.1f KB", b / 1_024) }
        if b < 1_073_741_824 { return String(format: "%.1f MB", b / 1_048_576) }
        return String(format: "%.2f GB", b / 1_073_741_824)
    }
}

enum TransferDirection { case upload, download }

enum TransferStatus {
    case inProgress
    case completed
    case failed(String)
}

@Observable
final class TransferTask: Identifiable {
    let id = UUID()
    let name: String
    let direction: TransferDirection
    var status: TransferStatus = .inProgress
    var bytesTransferred: Int64 = 0
    var totalBytes: Int64 = 0

    init(name: String, direction: TransferDirection) {
        self.name = name
        self.direction = direction
    }

    var isFinished: Bool {
        switch status {
        case .completed, .failed: return true
        case .inProgress: return false
        }
    }
}
