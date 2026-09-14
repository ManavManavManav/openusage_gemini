import Foundation

struct GeminiCredentials: Sendable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let authType: String?
}

struct GeminiAuthStore: Sendable {
    var files: TextFileAccessing = LocalTextFileAccessor()
    var environment: [String: String] = ProcessInfo.processInfo.environment
    static let home = "~/.gemini"

    func loadCredentials() throws -> GeminiCredentials? {
        let path = "\(Self.home)/oauth_creds.json"
        guard let text = try files.readTextIfPresent(path), let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let access = (json["access_token"] as? String)?.nilIfEmpty
        let refresh = (json["refresh_token"] as? String)?.nilIfEmpty
        let authType = settingsAuthType()
        guard let access else { return nil }
        return GeminiCredentials(accessToken: access, refreshToken: refresh, authType: authType)
    }

    func settingsAuthType() -> String? {
        guard let text = try? files.readTextIfPresent("\(Self.home)/settings.json"), let text,
              let data = text.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (json["authType"] as? String) ?? (json["security"] as? [String: Any])?["authType"] as? String
    }

    func hasLocalCredentials() -> Bool {
        if (try? loadCredentials()) != nil { return true }
        return ["GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_APPLICATION_CREDENTIALS", "GOOGLE_CLOUD_PROJECT"].contains { environment[$0]?.nilIfEmpty != nil }
    }
}
