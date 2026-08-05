import Foundation

enum ADIFExporter {
    static func export(qsos: [QSO], myGrid: String? = nil) -> String {
        var lines: [String] = []
        lines.append("<adif_ver:5>3.1.4")
        lines.append("<programid:11>VibeHamToolKit")
        lines.append("<eor>")
        for qso in qsos.sorted(by: { $0.qsoDate > $1.qsoDate }) {
            var fields: [(String, String?)] = [
                ("CALL", qso.call),
                ("QSO_DATE", qso.qsoDate),
                ("TIME_ON", qso.timeOn),
                ("BAND", qso.band),
                ("MODE", qso.mode),
                ("FREQ", qso.freq),
                ("RST_SENT", qso.rstSent),
                ("RST_RCVD", qso.rstRcvd),
                ("GRIDSQUARE", qso.gridsquare),
                ("COUNTRY", qso.country),
                ("STATE", qso.state),
                ("CNTY", qso.county),
                ("CQZ", qso.cqz),
                ("IOTA", qso.iota),
                ("CONT", qso.continent),
                ("LOTW_QSL_RCVD", qso.lotwQslRcvd),
                ("LOTW_QSL_RCVD_DATE", qso.lotwQslRcvdDate),
                ("POTA_REF", qso.potaRef),
                ("SOTA_REF", qso.sotaRef),
            ]
            if let myGrid = myGrid, !myGrid.isEmpty {
                fields.append(("MY_GRIDSQUARE", myGrid))
            }
            for (name, value) in fields {
                guard let value = value, !value.isEmpty else { continue }
                let len = value.utf8.count
                lines.append("<\(name):\(len)>\(value)")
            }
            lines.append("<eor>")
        }
        return lines.joined(separator: "\n")
    }
}
