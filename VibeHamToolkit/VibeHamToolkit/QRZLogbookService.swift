import Foundation

enum QRZLogbookService {
    enum FetchOption {
        case all
        case last
    }

    static func fetchADIF(apiKey: String, option: FetchOption = .all) async throws -> String {
        var request = URLRequest(url: URL(string: "https://logbook.qrz.com/api")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = "KEY=\(apiKey)&ACTION=FETCH"
        switch option {
        case .all:
            break
        case .last:
            body += "&OPTION=LAST"
        }
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        let adifMarker = text.range(of: "ADIF=")
        let head = adifMarker.map { String(text[..<$0.lowerBound]) } ?? text
        let headParams = head.components(separatedBy: "&").reduce(into: [String: String]()) { result, pair in
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { result[parts[0]] = parts[1].removingPercentEncoding }
        }

        guard headParams["RESULT"] == "OK" else {
            let reason = headParams["REASON"] ?? text
            throw NSError(domain: "QRZLogbook", code: 1, userInfo: [NSLocalizedDescriptionKey: reason])
        }

        guard let marker = adifMarker else { return "" }
        return String(text[marker.upperBound...])
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
