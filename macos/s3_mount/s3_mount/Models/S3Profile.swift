import Foundation

enum StorageType: String, Codable, CaseIterable, Identifiable {
    case s3 = "Amazon S3"
    case wasabi = "Wasabi"

    var id: String { rawValue }

    var defaultEndpoint: String {
        switch self {
        case .s3: return ""
        case .wasabi: return "https://s3.wasabisys.com"
        }
    }
}

struct S3Profile: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var storageType: StorageType = .s3
    var accessKeyID: String = ""
    var region: String = "us-east-1"
    var endpoint: String = ""

    var keychainKey: String { "s3mount-secret-\(id.uuidString)" }

    var baseURL: URL {
        if !endpoint.isEmpty, let url = URL(string: endpoint) { return url }
        return URL(string: "https://s3.\(region).amazonaws.com")!
    }
    
    func bucketURL(bucket: String) -> URL {
        // Use path-style for all providers - more compatible
        return baseURL.appendingPathComponent(bucket)
    }

    var vfsCacheMode: String {
        "writes"
    }

    var effectiveMountPath: String {
        let root = ("~/S3Mounts" as NSString).expandingTildeInPath
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folderName = trimmedName.isEmpty ? id.uuidString : trimmedName
        let sanitized = folderName.replacingOccurrences(of: "/", with: "-")
        return (root as NSString).appendingPathComponent(sanitized)
    }
}
