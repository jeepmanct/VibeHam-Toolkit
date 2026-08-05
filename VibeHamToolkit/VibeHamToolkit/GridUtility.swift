import Foundation
import CoreLocation

enum GridUtility {
    static func coordinate(from grid: String) -> CLLocationCoordinate2D? {
        let upper = grid.uppercased()
        guard upper.count >= 4 else { return nil }
        let scalars = Array(upper.unicodeScalars)
        let fieldLon = Double((Int(scalars[0].value) - 65) * 20) - 180
        let fieldLat = Double((Int(scalars[1].value) - 65) * 10) - 90
        guard let squareX = Int(String(upper[upper.index(upper.startIndex, offsetBy: 2)])),
              let squareY = Int(String(upper[upper.index(upper.startIndex, offsetBy: 3)])) else { return nil }
        var lon = fieldLon + Double(squareX) * 2.0 + 1.0
        var lat = fieldLat + Double(squareY) * 1.0 + 0.5
        if upper.count >= 6 {
            let subLon = Double((Int(scalars[4].value) - 65)) / 12.0
            let subLat = Double((Int(scalars[5].value) - 65)) / 24.0
            lon += subLon + 1.0 / 24.0
            lat += subLat + 1.0 / 48.0
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    static func grid(from coordinate: CLLocationCoordinate2D, precision: Int = 6) -> String {
        let lon = coordinate.longitude + 180
        let lat = coordinate.latitude + 90
        var result = ""
        result += String(UnicodeScalar(65 + Int(lon / 20))!)
        result += String(UnicodeScalar(65 + Int(lat / 10))!)
        result += "\(Int(lon.truncatingRemainder(dividingBy: 20) / 2))"
        result += "\(Int(lat.truncatingRemainder(dividingBy: 10) / 1))"
        if precision >= 6 {
            result += String(UnicodeScalar(65 + Int((lon.truncatingRemainder(dividingBy: 2) * 12)))!)
            result += String(UnicodeScalar(65 + Int((lat.truncatingRemainder(dividingBy: 1) * 24)))!)
        }
        if precision >= 8 {
            let x = Int((lon.truncatingRemainder(dividingBy: 2) * 12).truncatingRemainder(dividingBy: 1) * 10)
            let y = Int((lat.truncatingRemainder(dividingBy: 1) * 24).truncatingRemainder(dividingBy: 1) * 10)
            result += "\(x)\(y)"
        }
        return result
    }

    static func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let locA = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let locB = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return locA.distance(from: locB) / 1609.344
    }

    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let brng = atan2(y, x) * 180 / .pi
        return (brng + 360).truncatingRemainder(dividingBy: 360)
    }
}
