import Foundation
import Observation

@Observable
final class S3Service {
    private(set) var transfers: [TransferTask] = []
    private var bucketRegionCache: [String: String] = [:]

    // MARK: - List Buckets

    func listBuckets(profile: S3Profile, secretKey: String) async throws -> [S3Bucket] {
        let url = profile.baseURL
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let signed = AWSV4Signer(accessKeyID: profile.accessKeyID,
                                  secretKey: secretKey, region: profile.region)
            .signed(request: req)
        let (data, resp) = try await URLSession.shared.data(for: signed)
        try checkResponse(resp, data: data)
        return parseBuckets(data)
    }

    // MARK: - List Objects

    func listObjects(profile: S3Profile, secretKey: String,
                     bucket: String, prefix: String, 
                     continuationToken: String? = nil) async throws -> (objects: [S3Object], nextToken: String?) {
        let region = resolvedRegion(for: profile, bucket: bucket)
        var comps = URLComponents(url: bucketURL(profile: profile, bucket: bucket, region: region),
                                  resolvingAgainstBaseURL: false)!
        var queryPairs: [(String, String)] = [
            ("delimiter", "/"),
            ("list-type", "2"),
            ("max-keys", "100")
        ]
        if !prefix.isEmpty {
            queryPairs.append(("prefix", prefix))
        }
        if let token = continuationToken {
            queryPairs.append(("continuation-token", token))
        }
        comps.percentEncodedQuery = queryPairs
            .map { "\(awsQueryEncode($0.0))=\(awsQueryEncode($0.1))" }
            .joined(separator: "&")
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        let signed = AWSV4Signer(accessKeyID: profile.accessKeyID,
                                  secretKey: secretKey, region: region)
            .signed(request: req)
        let (data, resp) = try await URLSession.shared.data(for: signed)
        if let http = resp as? HTTPURLResponse,
           !(200...299).contains(http.statusCode),
           profile.endpoint.isEmpty,
           let hintedRegion = http.value(forHTTPHeaderField: "x-amz-bucket-region"),
           !hintedRegion.isEmpty,
           hintedRegion != region {
            setRegion(hintedRegion, for: profile, bucket: bucket)
            return try await listObjects(
                profile: profile,
                secretKey: secretKey,
                bucket: bucket,
                prefix: prefix,
                continuationToken: continuationToken
            )
        }
        try checkResponse(resp, data: data)
        let objects = parseObjects(data, requestedPrefix: prefix)
        let nextToken = parseNextContinuationToken(data)
        return (objects, nextToken)
    }

    // MARK: - Download

    func download(profile: S3Profile, secretKey: String,
                  bucket: String, key: String) async throws -> URL {
        let region = resolvedRegion(for: profile, bucket: bucket)
        let fileURL = bucketURL(profile: profile, bucket: bucket, region: region)
            .appendingPathComponent(key)

        var req = URLRequest(url: fileURL)
        req.httpMethod = "GET"
        let signed = AWSV4Signer(accessKeyID: profile.accessKeyID,
                                  secretKey: secretKey, region: region)
            .signed(request: req)

        let task = TransferTask(name: (key as NSString).lastPathComponent, direction: .download)
        transfers.append(task)

        do {
            let (tmpURL, resp) = try await URLSession.shared.download(for: signed)
            try checkResponse(resp, data: nil)

            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + (key as NSString).lastPathComponent)
            try FileManager.default.moveItem(at: tmpURL, to: dest)
            task.status = .completed
            return dest
        } catch {
            task.status = .failed(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Upload

    func upload(profile: S3Profile, secretKey: String,
                bucket: String, prefix: String, from fileURL: URL) async throws {
        let key = prefix + fileURL.lastPathComponent
        let region = resolvedRegion(for: profile, bucket: bucket)
        let uploadURL = bucketURL(profile: profile, bucket: bucket, region: region)
            .appendingPathComponent(key)

        let data = try await Task.detached { try Data(contentsOf: fileURL) }.value

        var req = URLRequest(url: uploadURL)
        req.httpMethod = "PUT"
        req.setValue(mimeType(for: fileURL), forHTTPHeaderField: "Content-Type")
        let signed = AWSV4Signer(accessKeyID: profile.accessKeyID,
                                  secretKey: secretKey, region: region)
            .signed(request: req, payload: data)

        let task = TransferTask(name: fileURL.lastPathComponent, direction: .upload)
        task.totalBytes = Int64(data.count)
        transfers.append(task)

        do {
            let (_, resp) = try await URLSession.shared.data(for: signed)
            try checkResponse(resp, data: nil)
            task.bytesTransferred = Int64(data.count)
            task.status = .completed
        } catch {
            task.status = .failed(error.localizedDescription)
            throw error
        }
    }

    // MARK: - Delete

    func delete(profile: S3Profile, secretKey: String,
                bucket: String, key: String) async throws {
        let region = resolvedRegion(for: profile, bucket: bucket)
        let url = bucketURL(profile: profile, bucket: bucket, region: region)
            .appendingPathComponent(key)
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        let signed = AWSV4Signer(accessKeyID: profile.accessKeyID,
                                  secretKey: secretKey, region: region)
            .signed(request: req)
        let (data, resp) = try await URLSession.shared.data(for: signed)
        try checkResponse(resp, data: data, allowEmpty: true)
    }

    func clearFinishedTransfers() {
        transfers.removeAll { $0.isFinished }
    }

    // MARK: - Private helpers

    private func cacheKey(profile: S3Profile, bucket: String) -> String {
        "\(profile.id.uuidString)::\(bucket)"
    }

    private func resolvedRegion(for profile: S3Profile, bucket: String) -> String {
        bucketRegionCache[cacheKey(profile: profile, bucket: bucket)] ?? profile.region
    }

    private func setRegion(_ region: String, for profile: S3Profile, bucket: String) {
        bucketRegionCache[cacheKey(profile: profile, bucket: bucket)] = region
    }

    private func bucketURL(profile: S3Profile, bucket: String, region: String) -> URL {
        if !profile.endpoint.isEmpty {
            return profile.baseURL.appendingPathComponent(bucket)
        }
        return URL(string: "https://s3.\(region).amazonaws.com")!
            .appendingPathComponent(bucket)
    }

    private func awsQueryEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    private func checkResponse(_ resp: URLResponse, data: Data?, allowEmpty: Bool = false) throws {
        guard let http = resp as? HTTPURLResponse else { throw S3Error.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let msg = xmlValue(body, tag: "Message") ?? "HTTP \(http.statusCode)"
            throw S3Error.serverError(msg)
        }
    }

    private func parseBuckets(_ data: Data) -> [S3Bucket] {
        let xml = String(data: data, encoding: .utf8) ?? ""
        return xmlValues(xml, tag: "Name").map { S3Bucket(name: $0) }
    }

    private func parseObjects(_ data: Data, requestedPrefix: String) -> [S3Object] {
        let xml = String(data: data, encoding: .utf8) ?? ""
        var items: [S3Object] = []
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for block in xmlValues(xml, tag: "CommonPrefixes") {
            guard let p = xmlValue(block, tag: "Prefix"), p != requestedPrefix else { continue }
            let name = String(p.dropLast()).components(separatedBy: "/").last ?? p
            items.append(S3Object(key: p, name: name, isFolder: true))
        }

        for block in xmlValues(xml, tag: "Contents") {
            guard let key = xmlValue(block, tag: "Key"),
                  !key.hasSuffix("/"), key != requestedPrefix else { continue }
            let size = Int64(xmlValue(block, tag: "Size") ?? "0") ?? 0
            let dateStr = xmlValue(block, tag: "LastModified") ?? ""
            var modified = iso.date(from: dateStr)
            if modified == nil {
                let isoBasic = ISO8601DateFormatter()
                modified = isoBasic.date(from: dateStr)
            }
            let name = key.components(separatedBy: "/").last ?? key
            items.append(S3Object(key: key, name: name, isFolder: false,
                                  size: size, lastModified: modified))
        }
        return items
    }
    
    private func parseNextContinuationToken(_ data: Data) -> String? {
        let xml = String(data: data, encoding: .utf8) ?? ""
        return xmlValue(xml, tag: "NextContinuationToken")
    }

    private func xmlValues(_ xml: String, tag: String) -> [String] {
        var result: [String] = []
        var range = xml.startIndex..<xml.endIndex
        let open = "<\(tag)>", close = "</\(tag)>"
        while let lo = xml.range(of: open, range: range),
              let lc = xml.range(of: close, range: lo.upperBound..<xml.endIndex) {
            result.append(String(xml[lo.upperBound..<lc.lowerBound]))
            range = lc.upperBound..<xml.endIndex
        }
        return result
    }

    private func xmlValue(_ xml: String, tag: String) -> String? {
        xmlValues(xml, tag: tag).first
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "pdf": return "application/pdf"
        case "txt", "md", "csv": return "text/plain"
        case "json": return "application/json"
        case "mp4": return "video/mp4"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }
}

enum S3Error: LocalizedError {
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .serverError(let m): return m
        }
    }
}
