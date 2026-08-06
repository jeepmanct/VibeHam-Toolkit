import Foundation
import SwiftData
import CoreLocation

@Model
final class UserProfile {
    var callsign: String
    var operatorName: String
    var gridSquare: String
    var latitude: Double
    var longitude: Double
    var qrzApiKey: String
    var qrzUsername: String?
    var qrzPassword: String?
    var lastQRZSync: Date?
    var lastPOTASync: Date?
    var useDarkMode: Bool
    var accentColorName: String

    init(
        callsign: String = "",
        operatorName: String = "",
        gridSquare: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        qrzApiKey: String = "",
        qrzUsername: String? = nil,
        qrzPassword: String? = nil,
        lastQRZSync: Date? = nil,
        lastPOTASync: Date? = nil,
        useDarkMode: Bool = false,
        accentColorName: String = "blue"
    ) {
        self.callsign = callsign
        self.operatorName = operatorName
        self.gridSquare = gridSquare
        self.latitude = latitude
        self.longitude = longitude
        self.qrzApiKey = qrzApiKey
        self.qrzUsername = qrzUsername
        self.qrzPassword = qrzPassword
        self.lastQRZSync = lastQRZSync
        self.lastPOTASync = lastPOTASync
        self.useDarkMode = useDarkMode
        self.accentColorName = accentColorName
    }

    static func fetchOrCreate(in context: ModelContext) -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let profile = UserProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }
}

@Model
final class QSO {
    @Attribute(.unique) var id: UUID
    var call: String
    var qsoDate: String
    var timeOn: String?
    var band: String?
    var mode: String?
    var freq: String?
    var rstSent: String?
    var rstRcvd: String?
    var gridsquare: String?
    var country: String?
    var state: String?
    var county: String?
    var cqz: String?
    var iota: String?
    var continent: String?
    var lotwQslRcvd: String?
    var lotwQslRcvdDate: String?
    var rawAdif: String?
    var importedAt: Date
    var imageData: Data?
    var potaRef: String?
    var sotaRef: String?

    init(
        id: UUID = UUID(),
        call: String,
        qsoDate: String,
        timeOn: String? = nil,
        band: String? = nil,
        mode: String? = nil,
        freq: String? = nil,
        rstSent: String? = nil,
        rstRcvd: String? = nil,
        gridsquare: String? = nil,
        country: String? = nil,
        state: String? = nil,
        county: String? = nil,
        cqz: String? = nil,
        iota: String? = nil,
        continent: String? = nil,
        lotwQslRcvd: String? = nil,
        lotwQslRcvdDate: String? = nil,
        rawAdif: String? = nil,
        imageData: Data? = nil,
        potaRef: String? = nil,
        sotaRef: String? = nil
    ) {
        self.id = id
        self.call = call.uppercased().trimmingCharacters(in: .whitespaces)
        self.qsoDate = qsoDate
        self.timeOn = timeOn?.trimmingCharacters(in: .whitespaces)
        self.band = band?.lowercased().trimmingCharacters(in: .whitespaces)
        self.mode = mode?.uppercased().trimmingCharacters(in: .whitespaces)
        self.freq = freq?.trimmingCharacters(in: .whitespaces)
        self.rstSent = rstSent?.trimmingCharacters(in: .whitespaces)
        self.rstRcvd = rstRcvd?.trimmingCharacters(in: .whitespaces)
        self.gridsquare = gridsquare?.uppercased().trimmingCharacters(in: .whitespaces)
        self.country = country?.trimmingCharacters(in: .whitespaces)
        self.state = state?.uppercased().trimmingCharacters(in: .whitespaces)
        self.county = county?.trimmingCharacters(in: .whitespaces)
        self.cqz = cqz?.trimmingCharacters(in: .whitespaces)
        self.iota = iota?.trimmingCharacters(in: .whitespaces)
        self.continent = continent?.uppercased().trimmingCharacters(in: .whitespaces)
        self.lotwQslRcvd = lotwQslRcvd?.trimmingCharacters(in: .whitespaces)
        self.lotwQslRcvdDate = lotwQslRcvdDate?.trimmingCharacters(in: .whitespaces)
        self.rawAdif = rawAdif
        self.importedAt = Date()
        self.imageData = imageData
        self.potaRef = potaRef?.uppercased().trimmingCharacters(in: .whitespaces)
        self.sotaRef = sotaRef?.uppercased().trimmingCharacters(in: .whitespaces)
    }

    var date: Date? {
        ADIFParser.adifDateFormatter.date(from: qsoDate)
    }
}

@Model
final class PhotoEntry {
    @Attribute(.unique) var id: UUID
    var caption: String
    var imageData: Data?
    var createdAt: Date

    init(id: UUID = UUID(), caption: String = "", imageData: Data? = nil) {
        self.id = id
        self.caption = caption
        self.imageData = imageData
        self.createdAt = Date()
    }
}

@Model
final class Satellite {
    @Attribute(.unique) var noradId: Int
    var name: String
    var mode: String
    var uplink: String
    var downlink: String
    var notes: String
    var enabled: Bool
    var tleLine1: String?
    var tleLine2: String?
    var updatedAt: Date?

    init(
        noradId: Int,
        name: String,
        mode: String,
        uplink: String,
        downlink: String,
        notes: String,
        enabled: Bool = true
    ) {
        self.noradId = noradId
        self.name = name
        self.mode = mode
        self.uplink = uplink
        self.downlink = downlink
        self.notes = notes
        self.enabled = enabled
    }
}

@Model
final class SolarDataPoint {
    @Attribute(.unique) var date: String
    var sfi: Double?
    var sfiAdjusted: Double?
    var aIndex: Double?
    var kIndex: Double?
    var kIndexMax: Double?
    var sunspotNumber: Double?
    var updatedAt: Date

    init(
        date: String,
        sfi: Double? = nil,
        sfiAdjusted: Double? = nil,
        aIndex: Double? = nil,
        kIndex: Double? = nil,
        kIndexMax: Double? = nil,
        sunspotNumber: Double? = nil
    ) {
        self.date = date
        self.sfi = sfi
        self.sfiAdjusted = sfiAdjusted
        self.aIndex = aIndex
        self.kIndex = kIndex
        self.kIndexMax = kIndexMax
        self.sunspotNumber = sunspotNumber
        self.updatedAt = Date()
    }

    static func lookup(date: String, in context: ModelContext) -> SolarDataPoint? {
        let descriptor = FetchDescriptor<SolarDataPoint>(predicate: #Predicate { $0.date == date })
        return try? context.fetch(descriptor).first
    }
}
