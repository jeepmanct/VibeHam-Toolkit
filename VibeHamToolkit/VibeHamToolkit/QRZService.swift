import Foundation

struct QRZInfo {
    let call: String
    let aliases: String
    let dxcc: String
    let fname: String
    let name: String
    let addr1: String
    let addr2: String
    let state: String
    let zip: String
    let country: String
    let grid: String
    let cqzone: String
    let ituzone: String
    let born: String
    let user: String
    let lotw: String
    let bio: String
    let image: String
    let email: String
    let url: String
    let classCode: String
    let codes: String
}

actor QRZService {
    static let shared = QRZService()

    func lookup(callsign: String, apiKey: String) async throws -> QRZInfo {
        let encoded = callsign.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? callsign
        let url = URL(string: "https://xmldata.qrz.com/xml/current/?s=\(apiKey);callsign=\(encoded)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = QRZXMLParser(data: data)
        guard let info = parser.parse() else {
            throw URLError(.cannotParseResponse)
        }
        return info
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        return allowed
    }()
}

private final class QRZXMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var currentElement = ""
    private var currentText = ""
    private var info: [String: String] = [:]
    private var sessionKey: String?
    private var errorMessage: String?

    init(data: Data) {
        parser = XMLParser(data: data)
        super.init()
        parser.delegate = self
    }

    func parse() -> QRZInfo? {
        parser.parse()
        if let error = errorMessage { print("QRZ error: \(error)"); return nil }
        guard !info.isEmpty else { return nil }
        return QRZInfo(
            call: info["call"] ?? "",
            aliases: info["aliases"] ?? "",
            dxcc: info["dxcc"] ?? "",
            fname: info["fname"] ?? "",
            name: info["name"] ?? "",
            addr1: info["addr1"] ?? "",
            addr2: info["addr2"] ?? "",
            state: info["state"] ?? "",
            zip: info["zip"] ?? "",
            country: info["country"] ?? "",
            grid: info["grid"] ?? "",
            cqzone: info["cqzone"] ?? "",
            ituzone: info["ituzone"] ?? "",
            born: info["born"] ?? "",
            user: info["user"] ?? "",
            lotw: info["lotw"] ?? "",
            bio: info["bio"] ?? "",
            image: info["image"] ?? "",
            email: info["email"] ?? "",
            url: info["url"] ?? "",
            classCode: info["class"] ?? "",
            codes: info["codes"] ?? ""
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "Key":
            sessionKey = trimmed
        case "Error":
            errorMessage = trimmed
        case "call", "aliases", "dxcc", "fname", "name", "addr1", "addr2", "state", "zip", "country",
             "grid", "cqzone", "ituzone", "born", "user", "lotw", "bio", "image", "email", "url", "class", "codes":
            info[elementName] = trimmed
        default:
            break
        }
    }
}
