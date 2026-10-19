import Foundation
import Security

struct ServerUser: Codable, Sendable {
    let id: String
    let email: String?
}

struct ServerSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let user: ServerUser
}

struct ServerBackupMetadata: Decodable, Sendable {
    let item_count: Int
    let updated_at: Date
}

struct ServerError: LocalizedError {
    let statusCode: Int
    let message: String

    var errorDescription: String? { "HTTP \(statusCode): \(message)" }
    var isUnauthorized: Bool { statusCode == 401 }
}

actor PayBoardServerClient {
    private static let keychainService = "kr.co.cdd.PayBoard.server-session"
    private static let keychainAccount = "session"
    // 만료 직전 토큰으로 요청하다 401 나는 걸 피하려고 여유를 두고 갱신함
    private static let refreshLeeway: TimeInterval = 60

    nonisolated let baseURL: URL
    private var session: ServerSession?
    // refresh token 이 회전형이라 동시에 두 번 갱신하면 하나가 무효 토큰을 쓰게 되므로 진행 중인 갱신을 공유함
    private var refreshTask: Task<ServerSession, any Error>?

    init(baseURL: URL) {
        self.baseURL = baseURL
        self.session = Self.loadSession()
    }

    var currentSession: ServerSession? { session }

    nonisolated func kakaoStartURL(redirectTo: URL, codeChallenge: String) -> URL? {
        var components = URLComponents(url: endpoint("v1/auth/kakao/start"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "redirect_to", value: redirectTo.absoluteString),
            URLQueryItem(name: "code_challenge", value: codeChallenge)
        ]
        return components?.url
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> ServerSession {
        try await startSession(path: "v1/auth/apple", body: ["id_token": idToken, "nonce": nonce])
    }

    func exchangeKakaoCode(_ code: String, codeVerifier: String) async throws -> ServerSession {
        try await startSession(path: "v1/auth/kakao/exchange", body: ["code": code, "code_verifier": codeVerifier])
    }

    func signOut() async {
        if let refreshToken = session?.refreshToken {
            _ = try? await send(path: "v1/auth/signout", method: "POST", body: Self.encode(["refresh_token": refreshToken]))
        }
        clearSession()
    }

    func deleteAccount() async throws {
        _ = try await authorizedSend(path: "v1/account/delete", method: "POST", body: Self.encode(["reason": "user_requested"]))
        clearSession()
    }

    func backupMetadata() async throws -> ServerBackupMetadata? {
        do {
            return try await Self.decode(ServerBackupMetadata.self, from: authorizedSend(path: "v1/backup", method: "GET"))
        } catch let error as ServerError where error.statusCode == 404 {
            return nil
        }
    }

    func backupData<T: Decodable & Sendable>(as type: T.Type) async throws -> T {
        try await Self.decode(type, from: authorizedSend(path: "v1/backup/data", method: "GET"))
    }

    func putBackup(_ upload: some Encodable & Sendable) async throws -> ServerBackupMetadata {
        try await Self.decode(ServerBackupMetadata.self, from: authorizedSend(path: "v1/backup", method: "PUT", body: Self.encode(upload)))
    }

    private struct SessionResponse: Decodable {
        let access_token: String
        let expires_in: Int
        let refresh_token: String
        let user: ServerUser
    }

    private func startSession(path: String, body: [String: String]) async throws -> ServerSession {
        let response = try await Self.decode(SessionResponse.self, from: send(path: path, method: "POST", body: Self.encode(body)))
        let newSession = ServerSession(
            accessToken: response.access_token,
            refreshToken: response.refresh_token,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expires_in)),
            user: response.user
        )
        session = newSession
        Self.saveSession(newSession)
        return newSession
    }

    private func validAccessToken() async throws -> String {
        guard let current = session else {
            throw ServerError(statusCode: 401, message: "not signed in")
        }
        if current.expiresAt.timeIntervalSinceNow > Self.refreshLeeway {
            return current.accessToken
        }
        if let refreshTask {
            return try await refreshTask.value.accessToken
        }
        let task = Task { try await startSession(path: "v1/auth/refresh", body: ["refresh_token": current.refreshToken]) }
        refreshTask = task
        defer { refreshTask = nil }
        do {
            return try await task.value.accessToken
        } catch let error as ServerError where error.isUnauthorized {
            clearSession()
            throw error
        }
    }

    private func authorizedSend(path: String, method: String, body: Data? = nil) async throws -> Data {
        let accessToken = try await validAccessToken()
        do {
            return try await send(path: path, method: method, body: body, accessToken: accessToken)
        } catch let error as ServerError where error.isUnauthorized {
            // 탈퇴 등으로 서버가 토큰을 거부하면 남은 세션은 쓸모없음
            clearSession()
            throw error
        }
    }

    private func send(path: String, method: String, body: Data? = nil, accessToken: String? = nil) async throws -> Data {
        var request = URLRequest(url: endpoint(path))
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = payload?["error"] as? String
                ?? String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            throw ServerError(statusCode: httpResponse.statusCode, message: message)
        }
        return data
    }

    private nonisolated func endpoint(_ path: String) -> URL {
        baseURL.appendingPathComponent(path, isDirectory: false)
    }

    private func clearSession() {
        session = nil
        SecItemDelete(Self.keychainQuery() as CFDictionary)
    }

    private static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return try encoder.encode(value)
    }

    // Postgres 는 소수 초가 0이면 생략하고 Go 는 나노초까지 붙이므로 두 형식 모두 받음
    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            let withFraction = ISO8601DateFormatter()
            withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = withFraction.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }
        return try decoder.decode(type, from: data)
    }

    private static func keychainQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
    }

    private static func loadSession() -> ServerSession? {
        var query = keychainQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(ServerSession.self, from: data)
    }

    private static func saveSession(_ session: ServerSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        SecItemDelete(keychainQuery() as CFDictionary)
        var attributes = keychainQuery()
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
