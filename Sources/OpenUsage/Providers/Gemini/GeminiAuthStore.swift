import Foundation

struct GeminiCredentials: Sendable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let authType: String?
    let expiresAt: Date?
}

struct GeminiAuthStore: Sendable {
    var files: TextFileAccessing = LocalTextFileAccessor()
    var environment: [String: String] = ProcessInfo.processInfo.environment
    static let home = "~/.gemini"

    func settingsAuthType() -> String? {
        guard let text = try? files.readTextIfPresent("\(Self.home)/settings.json") else { return nil }
        guard let data = text.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (json["authType"] as? String) ?? (json["security"] as? [String: Any])?["authType"] as? String
    }

    func loadCredentials() throws -> GeminiCredentials? {
        let mode = settingsAuthType()?.lowercased()
        guard mode == nil || mode == "oauth-personal" || mode == "oauth" || mode == "google" else { return nil }
        guard let text = try files.readTextIfPresent("\(Self.home)/oauth_creds.json"), let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let source = (json["oauth"] as? [String: Any]) ?? json
        guard let access = (source["access_token"] as? String)?.nilIfEmpty else { return nil }
        let refresh = (source["refresh_token"] as? String)?.nilIfEmpty
        let expiryValue = source["expiry_date"] ?? source["expires_at"] ?? source["expiresAt"]
        let expiresAt: Date? = if let n = expiryValue as? NSNumber { Date(timeIntervalSince1970: n.doubleValue > 10_000_000_000 ? n.doubleValue / 1000 : n.doubleValue) } else { nil }
        return GeminiCredentials(accessToken: access, refreshToken: refresh, authType: mode ?? "oauth-personal", expiresAt: expiresAt)
    }

    func hasLocalCredentials() -> Bool {
        (try? loadCredentials())?.flatMap { $0.accessToken.nilIfEmpty } != nil
    }
}
