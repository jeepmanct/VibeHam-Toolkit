import Foundation
import CoreLocation

struct TLE {
    let name: String
    let line1: String
    let line2: String
    let noradId: Int
    let epoch: Date
    let meanMotion: Double
    let eccentricity: Double
    let inclination: Double
    let raan: Double
    let argPerigee: Double
    let meanAnomaly: Double
    let bStar: Double
}

struct SatellitePass {
    let start: Date
    let maxElevation: Double
    let peak: Date
    let end: Date
}

actor SatelliteService {
    static let shared = SatelliteService()

    private static let secondsPerDay = 86400.0
    private static let mu = 398600.4418
    private static let earthRadiusKm = 6378.137

    func fetchTLE(for noradId: Int) async throws -> TLE {
        let url = URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=\(noradId)&FORMAT=TLE")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        let lines = text.split(separator: "\n").map(String.init)
        guard lines.count >= 3 else { throw URLError(.cannotParseResponse) }
        return try parseTLE(name: lines[0].trimmingCharacters(in: .whitespaces), line1: lines[1], line2: lines[2])
    }

    func parseTLE(name: String, line1: String, line2: String) throws -> TLE {
        guard line1.hasPrefix("1 "), line2.hasPrefix("2 ") else { throw URLError(.cannotParseResponse) }
        let noradId = Int(line1[line1.index(line1.startIndex, offsetBy: 2)...line1.index(line1.startIndex, offsetBy: 6)].trimmingCharacters(in: .whitespaces)) ?? 0

        let epochYear = Int(line1[line1.index(line1.startIndex, offsetBy: 18)...line1.index(line1.startIndex, offsetBy: 19)]) ?? 0
        let epochDay = Double(line1[line1.index(line1.startIndex, offsetBy: 20)...line1.index(line1.startIndex, offsetBy: 31)]) ?? 0
        let fullYear = epochYear >= 57 ? 1900 + epochYear : 2000 + epochYear
        let epoch = yearDayToDate(year: fullYear, day: epochDay)

        let meanMotion = Double(line2[line2.index(line2.startIndex, offsetBy: 52)...line2.index(line2.startIndex, offsetBy: 62)]) ?? 0
        let eccentricity = Double("0." + line2[line2.index(line2.startIndex, offsetBy: 26)...line2.index(line2.startIndex, offsetBy: 33)].trimmingCharacters(in: .whitespaces)) ?? 0
        let inclination = Double(line2[line2.index(line2.startIndex, offsetBy: 8)...line2.index(line2.startIndex, offsetBy: 16)].trimmingCharacters(in: .whitespaces)) ?? 0
        let raan = Double(line2[line2.index(line2.startIndex, offsetBy: 17)...line2.index(line2.startIndex, offsetBy: 25)].trimmingCharacters(in: .whitespaces)) ?? 0
        let argPerigee = Double(line2[line2.index(line2.startIndex, offsetBy: 34)...line2.index(line2.startIndex, offsetBy: 42)].trimmingCharacters(in: .whitespaces)) ?? 0
        let meanAnomaly = Double(line2[line2.index(line2.startIndex, offsetBy: 43)...line2.index(line2.startIndex, offsetBy: 51)].trimmingCharacters(in: .whitespaces)) ?? 0

        let bStarStr = line1[line1.index(line1.startIndex, offsetBy: 53)...line1.index(line1.startIndex, offsetBy: 60)]
        let bStar = Double(bStarStr.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "+", with: "")) ?? 0

        return TLE(
            name: name,
            line1: line1,
            line2: line2,
            noradId: noradId,
            epoch: epoch,
            meanMotion: meanMotion,
            eccentricity: eccentricity,
            inclination: inclination,
            raan: raan,
            argPerigee: argPerigee,
            meanAnomaly: meanAnomaly,
            bStar: bStar
        )
    }

    func predictPasses(tle: TLE, observer: CLLocationCoordinate2D, minElevation: Double = 10.0, hours: Double = 24.0) -> [SatellitePass] {
        let obs = geodeticToEcef(lat: observer.latitude, lon: observer.longitude, alt: 0)
        let start = Date()
        let end = start.addingTimeInterval(hours * 3600)
        var passes: [SatellitePass] = []
        let step: TimeInterval = 30

        var current = start
        while current < end {
            let pos = propagate(tle: tle, date: current)
            let elev = elevation(observerEcef: obs, satelliteEcef: pos)
            if elev > minElevation {
                let passStart = current
                var peakElev = elev
                var peakTime = current
                while current < end {
                    let p = propagate(tle: tle, date: current)
                    let e = elevation(observerEcef: obs, satelliteEcef: p)
                    if e < minElevation { break }
                    if e > peakElev {
                        peakElev = e
                        peakTime = current
                    }
                    current = current.addingTimeInterval(step)
                }
                passes.append(SatellitePass(start: passStart, maxElevation: peakElev, peak: peakTime, end: current))
            }
            current = current.addingTimeInterval(step)
        }
        return passes
    }

    private func propagate(tle: TLE, date: Date) -> SIMD3<Double> {
        let n = tle.meanMotion * 2 * .pi / SatelliteService.secondsPerDay
        let a = pow(SatelliteService.mu / (n * n), 1.0 / 3.0)
        let M0 = tle.meanAnomaly * .pi / 180
        let M = M0 + n * date.timeIntervalSince(tle.epoch)

        var E = M
        for _ in 0..<10 {
            E = M + tle.eccentricity * sin(E)
        }

        let nu = 2 * atan2(sqrt(1 + tle.eccentricity) * sin(E / 2), sqrt(1 - tle.eccentricity) * cos(E / 2))
        let r = a * (1 - tle.eccentricity * cos(E))

        let i = tle.inclination * .pi / 180
        let raan = tle.raan * .pi / 180
        let argPerigee = tle.argPerigee * .pi / 180

        let xOrbital = r * cos(nu)
        let yOrbital = r * sin(nu)

        let cosRaan = cos(raan), sinRaan = sin(raan)
        let cosArg = cos(argPerigee), sinArg = sin(argPerigee)
        let cosI = cos(i), sinI = sin(i)

        let x = (cosRaan * cosArg - sinRaan * sinArg * cosI) * xOrbital + (-cosRaan * sinArg - sinRaan * cosArg * cosI) * yOrbital
        let y = (sinRaan * cosArg + cosRaan * sinArg * cosI) * xOrbital + (-sinRaan * sinArg + cosRaan * cosArg * cosI) * yOrbital
        let z = (sinI * sinArg) * xOrbital + (sinI * cosArg) * yOrbital

        let theta = gmst(date: date)
        let cosT = cos(theta), sinT = sin(theta)
        let xEcef = cosT * x + sinT * y
        let yEcef = -sinT * x + cosT * y
        return SIMD3<Double>(xEcef, yEcef, z)
    }

    private func elevation(observerEcef: SIMD3<Double>, satelliteEcef: SIMD3<Double>) -> Double {
        let diff = satelliteEcef - observerEcef
        let range = sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
        let dot = diff.x * observerEcef.x + diff.y * observerEcef.y + diff.z * observerEcef.z
        let obsR = sqrt(observerEcef.x * observerEcef.x + observerEcef.y * observerEcef.y + observerEcef.z * observerEcef.z)
        let sinElev = dot / (range * obsR)
        return asin(sinElev) * 180 / .pi
    }

    private func geodeticToEcef(lat: Double, lon: Double, alt: Double) -> SIMD3<Double> {
        let latRad = lat * .pi / 180
        let lonRad = lon * .pi / 180
        let a = 6378.137
        let f = 1 / 298.257223563
        let e2 = 2 * f - f * f
        let sinLat = sin(latRad), cosLat = cos(latRad)
        let sinLon = sin(lonRad), cosLon = cos(lonRad)
        let N = a / sqrt(1 - e2 * sinLat * sinLat)
        let x = (N + alt / 1000) * cosLat * cosLon
        let y = (N + alt / 1000) * cosLat * sinLon
        let z = (N * (1 - e2) + alt / 1000) * sinLat
        return SIMD3<Double>(x, y, z)
    }

    private func gmst(date: Date) -> Double {
        let J2000 = Date(timeIntervalSince1970: 946728000)
        let days = date.timeIntervalSince(J2000) / SatelliteService.secondsPerDay
        return (280.46061837 + 360.98564736629 * days).truncatingRemainder(dividingBy: 360) * .pi / 180
    }

    private func yearDayToDate(year: Int, day: Double) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        let cal = Calendar(identifier: .gregorian)
        guard let jan1 = cal.date(from: components) else { return Date() }
        return jan1.addingTimeInterval((day - 1) * SatelliteService.secondsPerDay)
    }
}
