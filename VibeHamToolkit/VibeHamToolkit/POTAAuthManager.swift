import Foundation
import AuthenticationServices
import CryptoKit

@Observable
final class POTAAuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = POTAAuthManager()

    private let domain = "parksontheair.auth.us-east-2.amazoncognito.com"
    private let clientId = "7hluqct0n2nckib7i7sd5753oa"
    private let redirectURI = "vibeham://pota/callback"
    private let scheme = "vibeham"

    private var webAuthSession: ASWebAuthenticationSession?
    private var pendingContinuation: CheckedContinuation<Result<POTATokens, Error>, Never>?

    private(set) var idToken: String?
    private(set) var refreshToken: String?

    var isAuthenticated: Bool {
        idToken != nil
    }

    override private init() {
        self.idToken = KeychainHelper.read(service: "com.vibeham.pota", account: "idToken")
        self.refreshToken = KeychainHelper.read(service: "com.vibeham.pota", account: "refreshToken")
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }

    @MainActor
    func signIn() async -> Result<POTATokens, Error> {
        let verifier = PKCE.generateVerifier()
        let challenge = PKCE.challenge(for: verifier)
        let state = PKCE.generateVerifier(length: 32)

        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/oauth2/authorize"
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let url = components.url else {
            return .failure(URLError(.badURL))
        }

        return await withCheckedContinuation { continuation in
            self.pendingContinuation = continuation
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callbackURL, error in
                guard let self = self else { return }
                if let error = error {
                    self.pendingContinuation?.resume(returning: .failure(error))
                    self.pendingContinuation = nil
                    return
                }
                guard let callbackURL = callbackURL else {
                    self.pendingContinuation?.resume(returning: .failure(URLError(.badServerResponse)))
                    self.pendingContinuation = nil
                    return
                }
                Task {
                    let result = await self.exchangeCode(callbackURL: callbackURL, verifier: verifier, expectedState: state)
                    self.pendingContinuation?.resume(returning: result)
                    self.pendingContinuation = nil
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webAuthSession = session
            session.start()
        }
    }

    private func exchangeCode(callbackURL: URL, verifier: String, expectedState: String) async -> Result<POTATokens, Error> {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value,
              let returnedState = queryItems.first(where: { $0.name == "state" })?.value,
              returnedState == expectedState else {
            return .failure(URLError(.badServerResponse))
        }

        var request = URLRequest(url: URL(string: "https://\(domain)/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=authorization_code&client_id=\(clientId)&code=\(code)&redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? redirectURI)&code_verifier=\(verifier)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return .failure(URLError(.badServerResponse))
            }
            let tokens = try JSONDecoder().decode(POTATokens.self, from: data)
            save(tokens: tokens)
            return .success(tokens)
        } catch {
            return .failure(error)
        }
    }

    func refreshIfNeeded() async -> Bool {
        guard let refreshToken = refreshToken else { return false }
        var request = URLRequest(url: URL(string: "https://\(domain)/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=refresh_token&client_id=\(clientId)&refresh_token=\(refreshToken)"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                signOut()
                return false
            }
            let tokens = try JSONDecoder().decode(POTATokens.self, from: data)
            save(tokens: tokens)
            return true
        } catch {
            signOut()
            return false
        }
    }

    func signOut() {
        KeychainHelper.delete(service: "com.vibeham.pota", account: "idToken")
        KeychainHelper.delete(service: "com.vibeham.pota", account: "refreshToken")
    }

    private func save(tokens: POTATokens) {
        if let idToken = tokens.idToken {
            KeychainHelper.save(idToken, service: "com.vibeham.pota", account: "idToken")
        }
        if let refreshToken = tokens.refreshToken {
            KeychainHelper.save(refreshToken, service: "com.vibeham.pota", account: "refreshToken")
        }
    }
}

struct POTATokens: Codable {
    let accessToken: String?
    let idToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

enum PKCE {
    static func generateVerifier(length: Int = 128) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    static func challenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let digest = Data(SHA256.hash(data: data))
        return base64URLEncode(digest)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
