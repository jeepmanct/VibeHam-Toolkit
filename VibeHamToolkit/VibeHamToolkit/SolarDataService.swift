import Foundation
import SwiftData

struct SolarRecord {
    let date: String
    let sfi: Double?
    let sfiAdjusted: Double?
    let aIndex: Double?
    let kIndex: Double?
    let kIndexMax: Double?
    let sunspotNumber: Double?
}

struct SolarDataService {
    static let shared = SolarDataService()
    private static let url = URL(string: "https://kp.gfz-potsdam.de/app/files/Kp_ap_Ap_SN_F107_since_1932.txt")!

    func fetchAndParse() async throws -> [SolarRecord] {
        let (data, _) = try await URLSession.shared.data(from: SolarDataService.url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return Self.parse(text: text)
    }

    static func parse(text: String) -> [SolarRecord] {
        var records: [SolarRecord] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let f = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard f.count >= 28 else { continue }

            let date = String(format: "%04d%02d%02d", Int(f[0]) ?? 0, Int(f[1]) ?? 0, Int(f[2]) ?? 0)
            let kpValues = f[7..<15].compactMap { Double($0) }.filter { $0 >= 0 }
            let hasAllKp = kpValues.count == 8

            records.append(SolarRecord(
                date: date,
                sfi: num(f[25]),
                sfiAdjusted: num(f[26]),
                aIndex: num(f[23]),
                kIndex: hasAllKp ? kpValues.reduce(0, +) / Double(kpValues.count) : nil,
                kIndexMax: hasAllKp ? kpValues.max() : nil,
                sunspotNumber: num(f[24])
            ))
        }
        return records
    }

    private static func num(_ s: String) -> Double? {
        let n = Double(s)
        guard let value = n, value >= 0 else { return nil }
        return value
    }
}
