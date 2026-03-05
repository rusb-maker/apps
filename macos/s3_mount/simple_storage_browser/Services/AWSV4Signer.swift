import Foundation
import CryptoKit

extension Sequence where Element == UInt8 {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}

struct AWSV4Signer {
    let accessKeyID: String
    let secretKey: String
    let region: String

    func signed(request: URLRequest, payload: Data? = nil) -> URLRequest {
        var req = request
        guard let url = req.url, let host = url.host else { return req }

        let now = Date()
        let amzDate = fmt(now, "yyyyMMdd'T'HHmmss'Z'")
        let dateStamp = fmt(now, "yyyyMMdd")

        let body = payload ?? req.httpBody ?? Data()
        let bodyHash = SHA256.hash(data: body).hexString

        req.setValue(host, forHTTPHeaderField: "host")
        req.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        req.setValue(bodyHash, forHTTPHeaderField: "x-amz-content-sha256")
        if let payload { req.httpBody = payload }

        var toSign: [(String, String)] = [
            ("host", host),
            ("x-amz-content-sha256", bodyHash),
            ("x-amz-date", amzDate),
        ]
        if let ct = req.value(forHTTPHeaderField: "Content-Type") {
            toSign.append(("content-type", ct))
        }
        toSign.sort { $0.0 < $1.0 }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let canonPath = comps?.percentEncodedPath.isEmpty == false ? comps!.percentEncodedPath : "/"

        // Build canonical query from raw percent-encoded query to avoid '+' normalization issues.
        let canonQuery: String
        if let rawQuery = comps?.percentEncodedQuery, !rawQuery.isEmpty {
            let encodedPairs = rawQuery
                .split(separator: "&", omittingEmptySubsequences: false)
                .compactMap { part -> String? in
                    let pieces = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                    guard let rawName = pieces.first else { return nil }
                    let rawValue = pieces.count > 1 ? String(pieces[1]) : ""

                    let decodedName = String(rawName).removingPercentEncoding ?? String(rawName)
                    let decodedValue = rawValue.removingPercentEncoding ?? rawValue

                    return "\(awsEncode(decodedName))=\(awsEncode(decodedValue))"
                }
                .sorted()
            canonQuery = encodedPairs.joined(separator: "&")
        } else {
            canonQuery = ""
        }
        let canonHdrs = toSign.map { "\($0.0):\($0.1)" }.joined(separator: "\n") + "\n"
        let signedHdrs = toSign.map { $0.0 }.joined(separator: ";")

        let canonReq = [req.httpMethod ?? "GET", canonPath, canonQuery,
                        canonHdrs, signedHdrs, bodyHash].joined(separator: "\n")

        let scope = "\(dateStamp)/\(region)/s3/aws4_request"
        let sts = ["AWS4-HMAC-SHA256", amzDate, scope,
                   SHA256.hash(data: Data(canonReq.utf8)).hexString].joined(separator: "\n")

        let sig = HMAC<SHA256>.authenticationCode(
            for: Data(sts.utf8), using: sigKey(dateStamp)).hexString

        req.setValue(
            "AWS4-HMAC-SHA256 Credential=\(accessKeyID)/\(scope), SignedHeaders=\(signedHdrs), Signature=\(sig)",
            forHTTPHeaderField: "Authorization"
        )
        return req
    }

    private func awsEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    private func sigKey(_ dateStamp: String) -> SymmetricKey {
        func h(_ s: String, _ k: SymmetricKey) -> SymmetricKey {
            SymmetricKey(data: HMAC<SHA256>.authenticationCode(for: Data(s.utf8), using: k))
        }
        let k0 = SymmetricKey(data: Data(("AWS4" + secretKey).utf8))
        return h("aws4_request", h("s3", h(region, h(dateStamp, k0))))
    }

    private func fmt(_ d: Date, _ f: String) -> String {
        let df = DateFormatter()
        df.dateFormat = f
        df.timeZone = TimeZone(identifier: "UTC")
        return df.string(from: d)
    }
}
