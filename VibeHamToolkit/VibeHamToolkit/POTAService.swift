import Foundation

enum POTAService {
    enum POTAError: Error {
        case notAuthenticated
    }

    // MARK: - Public profile (unauthenticated, recent 25 only)

    struct POTAProfile: Codable {
        let callsign: String
        let recentActivity: RecentActivity?

        enum CodingKeys: String, CodingKey {
            case callsign
            case recentActivity = "recent_activity"
        }
    }

    struct RecentActivity: Codable {
        let activations: [POTAActivation]?
        let hunterQSOs: [POTAQSO]?

        enum CodingKeys: String, CodingKey {
            case activations
            case hunterQSOs = "hunter_qsos"
        }
    }

    struct POTAActivation: Codable {
        let date: String
        let reference: String
        let park: String?
        let location: String?
        let total: Int?
    }

    // MARK: - Authenticated logbook

    struct POTALogbookResponse: Codable {
        let count: Int?
        let entries: [POTAQSO]?
    }

    struct POTAQSO: Codable {
        let date: String?
        let datetime: String?
        let callsign: String?
        let call: String?
        let band: String?
        let mode: String?
        let reference: String?
        let park: String?
        let location: String?

        var resolvedCall: String? {
            callsign ?? call
        }

        var resolvedDateString: String? {
            datetime ?? date
        }
    }

    // MARK: - Public fetch

    static func fetchRecentHunterQSOs(callsign: String) async throws -> [POTAQSO] {
        let encoded = callsign.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? callsign
        guard let url = URL(string: "https://api.pota.app/profile/\(encoded)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let profile = try JSONDecoder().decode(POTAProfile.self, from: data)
        return profile.recentActivity?.hunterQSOs ?? []
    }

    // MARK: - Authenticated fetch

    @MainActor
    static func fetchAllHunterQSOs() async throws -> [POTAQSO] {
        let auth = POTAAuthManager.shared
        guard let idToken = auth.idToken, !idToken.isEmpty else {
            throw POTAError.notAuthenticated
        }

        var allQSOs: [POTAQSO] = []
        var page = 1
        let pageSize = 100

        while true {
            var components = URLComponents(string: "https://api.pota.app/user/logbook")!
            components.queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(pageSize))
            ]
            guard let url = components.url else { throw URLError(.badURL) }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            if httpResponse.statusCode == 401 {
                if await auth.refreshIfNeeded() {
                    continue
                } else {
                    throw POTAError.notAuthenticated
                }
            }

            guard httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let logbook = try JSONDecoder().decode(POTALogbookResponse.self, from: data)
            let entries = logbook.entries ?? []
            allQSOs.append(contentsOf: entries)

            let total = logbook.count ?? entries.count
            if entries.isEmpty || allQSOs.count >= total {
                break
            }
            page += 1
        }

        return allQSOs
    }

    @MainActor
    static func fetchAllActivations() async throws -> [POTAActivation] {
        let auth = POTAAuthManager.shared
        guard let idToken = auth.idToken, !idToken.isEmpty else {
            throw POTAError.notAuthenticated
        }

        guard let url = URL(string: "https://api.pota.app/user/activations?all=1") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 401 {
            if await auth.refreshIfNeeded() {
                return try await fetchAllActivations()
            } else {
                throw POTAError.notAuthenticated
            }
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([POTAActivation].self, from: data)
    }

    // MARK: - Parsing

    static func parsePOTAQSO(_ qso: POTAQSO, myCallsign: String) -> QSO? {
        guard let dateString = qso.resolvedDateString,
              let call = qso.resolvedCall?.trimmingCharacters(in: .whitespacesAndNewlines),
              !call.isEmpty else { return nil }

        var date: Date?
        let formatters: [ISO8601DateFormatter] = [
            { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }(),
            { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f }(),
            { let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]; return f }()
        ]
        for formatter in formatters {
            if let d = formatter.date(from: dateString) {
                date = d
                break
            }
        }

        // Fallback for plain yyyy-MM-dd or MM/dd/yyyy
        if date == nil {
            let fallbackFormatters = ["yyyy-MM-dd", "MM/dd/yyyy", "yyyy-MM-dd HH:mm:ss", "MM/dd/yyyy HH:mm:ss"]
            let df = DateFormatter()
            df.timeZone = TimeZone(secondsFromGMT: 0)
            for fmt in fallbackFormatters {
                df.dateFormat = fmt
                if let d = df.date(from: dateString) {
                    date = d
                    break
                }
            }
        }

        guard let resolvedDate = date else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let formattedDate = dateFormatter.string(from: resolvedDate)

        var state: String?
        var country: String?
        if let location = qso.location {
            let parts = location.split(separator: "-").map(String.init)
            if parts.count == 2 {
                country = countryName(for: parts[0])
                state = parts[1]
            } else {
                state = location
            }
        }

        return QSO(
            call: call,
            qsoDate: formattedDate,
            timeOn: nil,
            band: qso.band,
            mode: qso.mode,
            freq: nil,
            rstSent: nil,
            rstRcvd: nil,
            gridsquare: nil,
            country: country,
            state: state,
            county: nil,
            cqz: nil,
            iota: nil,
            continent: nil,
            lotwQslRcvd: nil,
            lotwQslRcvdDate: nil,
            rawAdif: nil,
            imageData: nil,
            potaRef: qso.reference,
            sotaRef: nil
        )
    }

    private static func countryName(for code: String) -> String {
        switch code.uppercased() {
        case "US": return "United States"
        case "CA": return "Canada"
        case "MX": return "Mexico"
        case "AU": return "Australia"
        case "JP": return "Japan"
        case "GB", "UK": return "United Kingdom"
        case "DE": return "Germany"
        case "FR": return "France"
        case "IT": return "Italy"
        case "ES": return "Spain"
        default: return code.uppercased()
        }
    }
}
