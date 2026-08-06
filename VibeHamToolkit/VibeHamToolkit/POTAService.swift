import Foundation

enum POTAService {
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

    struct POTAQSO: Codable {
        let date: String
        let callsign: String
        let band: String?
        let mode: String?
        let reference: String
        let park: String?
        let location: String?
    }

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

    static func parsePOTAQSO(_ qso: POTAQSO, myCallsign: String) -> QSO? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var parsedDate = isoFormatter.date(from: qso.date)
        if parsedDate == nil {
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            parsedDate = fallback.date(from: qso.date)
        }
        guard let date = parsedDate else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let dateString = dateFormatter.string(from: date)

        var state: String?
        var country: String?
        if let location = qso.location {
            let parts = location.split(separator: "-").map(String.init)
            if parts.count == 2 {
                country = countryName(for: parts[0])
                state = parts[1]
            }
        }

        return QSO(
            call: qso.callsign,
            qsoDate: dateString,
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
