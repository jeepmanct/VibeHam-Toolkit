import Foundation

struct ADIFParser {
    static let adifDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        df.timeZone = TimeZone(identifier: "UTC")
        return df
    }()

    static func parse(content: String) -> [QSO] {
        var records: [QSO] = []
        let body: String
        if let range = content.range(of: "<eoh>", options: .caseInsensitive) {
            body = String(content[range.upperBound...])
        } else {
            body = content
        }

        let chunks = body.components(separatedBy: "<eor>")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let fieldRegex = try! NSRegularExpression(pattern: "<([a-zA-Z_0-9]+):(\\d+)(?::[a-zA-Z])?>", options: [])

        for chunk in chunks {
            var fields: [String: String] = [:]
            let matches = fieldRegex.matches(in: chunk, options: [], range: NSRange(chunk.startIndex..., in: chunk))

            for match in matches {
                guard match.numberOfRanges >= 3,
                      let nameRange = Range(match.range(at: 1), in: chunk),
                      let lenRange = Range(match.range(at: 2), in: chunk),
                      let fullRange = Range(match.range(at: 0), in: chunk) else { continue }
                let name = String(chunk[nameRange]).uppercased()
                guard let length = Int(String(chunk[lenRange])) else { continue }
                let valueStart = fullRange.upperBound
                guard let valueEnd = chunk.index(valueStart, offsetBy: length, limitedBy: chunk.endIndex) else { continue }
                let value = String(chunk[valueStart..<valueEnd])
                fields[name] = value
            }

            guard let call = fields["CALL"], !call.isEmpty,
                  let qsoDate = fields["QSO_DATE"], qsoDate.count == 8 else { continue }

            records.append(QSO(
                call: call,
                qsoDate: qsoDate,
                timeOn: fields["TIME_ON"],
                band: fields["BAND"],
                mode: fields["MODE"],
                freq: fields["FREQ"],
                rstSent: fields["RST_SENT"],
                rstRcvd: fields["RST_RCVD"],
                gridsquare: fields["GRIDSQUARE"],
                country: fields["COUNTRY"],
                state: fields["STATE"],
                county: fields["CNTY"],
                cqz: fields["CQZ"],
                iota: fields["IOTA"],
                continent: fields["CONT"],
                lotwQslRcvd: fields["LOTW_QSL_RCVD"],
                lotwQslRcvdDate: fields["LOTW_QSL_RCVD_DATE"],
                rawAdif: chunk,
                potaRef: fields["POTA_REF"],
                sotaRef: fields["SOTA_REF"]
            ))
        }

        return records
    }
}
