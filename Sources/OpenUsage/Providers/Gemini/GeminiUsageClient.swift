import Foundation

struct GeminiUsageResult: Sendable { let plan: String?; let lines: [MetricLine] }

enum GeminiUsageError: LocalizedError, CategorizedError, Equatable {
    case missingLogin, expired, unavailable, unsupportedAuthMode, notOnboarded
    var errorDescription: String? { switch self { case .missingLogin: "Sign in to Gemini CLI with Google to view Code Assist usage."; case .expired: "Gemini Google login has expired. Sign in again in Gemini CLI."; case .unavailable: "Gemini usage is temporarily unavailable."; case .notOnboarded: "Run Gemini CLI once to finish setup before viewing Code Assist usage."; case .unsupportedAuthMode: "Gemini API-key and Vertex AI modes do not expose personal Code Assist limits." } }
    var errorCategory: ErrorCategory { switch self { case .missingLogin: .notLoggedIn; case .expired: .authExpired; case .unsupportedAuthMode, .notOnboarded: .notAvailable; case .unavailable: .network } }
}

struct GeminiUsageClient: Sendable {
    var http: HTTPClient = URLSessionHTTPClient()
    static let bases = ["https://daily-cloudcode-pa.googleapis.com", "https://cloudcode-pa.googleapis.com"]
    func refreshToken(_ refresh: String) async -> TokenRefreshOutcome { await AntigravityUsageClient(http: http).refreshGoogleToken(refresh) }

    func fetch(accessToken: String) async throws -> GeminiUsageResult {
        let payload = try JSONSerialization.data(withJSONObject: ["metadata": ["ideType": "GEMINI_CLI", "platform": "DARWIN"]])
        for base in Self.bases {
            guard let loadURL = URL(string: base + "/v1internal:loadCodeAssist") else { continue }
            let req = HTTPRequest(method: "POST", url: loadURL, headers: ["Authorization": "Bearer \(accessToken)", "Content-Type": "application/json", "Accept": "application/json"], body: payload)
            guard let load = try? await http.send(req) else { continue }
            if load.statusCode == 401 || load.statusCode == 403 { throw GeminiUsageError.expired }
            if load.statusCode == 400 { throw GeminiUsageError.notOnboarded }
            guard (200..<300).contains(load.statusCode) else { continue }
            let plan = AntigravityUsageMapper.parseLoadCodeAssistPlan(load.body)
            let project = AntigravityUsageMapper.parseProject(load.body)
            guard let quotaURL = URL(string: base + "/v1internal:retrieveUserQuota") else { continue }
            var quotaBody: [String: Any] = ["metadata": ["ideType": "GEMINI_CLI", "platform": "DARWIN"]]
            if let project { quotaBody["project"] = project; quotaBody["cloudaicompanionProject"] = project }
            let quotaReq = HTTPRequest(method: "POST", url: quotaURL, headers: req.headers, body: try JSONSerialization.data(withJSONObject: quotaBody))
            guard let quota = try? await http.send(quotaReq) else { continue }
            if quota.statusCode == 401 || quota.statusCode == 403 { throw GeminiUsageError.expired }
            guard (200..<300).contains(quota.statusCode) else { continue }
            return GeminiUsageResult(plan: plan, lines: try GeminiUsageMapper.map(quota.body))
        }
        throw GeminiUsageError.unavailable
    }
}
